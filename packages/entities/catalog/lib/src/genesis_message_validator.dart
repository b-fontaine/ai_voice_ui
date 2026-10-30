import 'dart:convert';

import 'genesis_contract.dart';
import 'validated_envelope.dart';

/// Validateur A2UI côté client (pdr-0053, défense en profondeur).
///
/// Portage fidèle de `backend/orchestrator/internal/app/a2ui` (`validator.go`
/// et `registry.go`), mêmes codes d'erreur. À ÉTAT PAR SESSION : il suit les
/// surfaces actives (A2 du plan 007). Une seule instance par session.
///
/// Non portées (règles purement serveur) : `foreign_surface` (propriété
/// d'agent), `message_cap` (plafond par tâche), `incomplete_surface` (fin de
/// tâche).
///
/// Règles d'état : un `createSurface` en double est refusé (`surface_exists`)
/// sans toucher à la surface existante (ni compensation, ni blocage) ; les
/// mises à jour suivantes s'appliquent en place. Tout autre refus visant une
/// surface active la retire et la bloque (compensation, pdr-0056).
///
/// Ajouts propres au client, absents du Go : la compensation locale et le
/// verdict `ignored` (A2d du plan 007).
class GenesisMessageValidator {
  GenesisMessageValidator({
    this._catalogId = GenesisContract.defaultCatalogId,
    this.maxSurfaces = 6,
    this.maxMessageBytes = 64 * 1024,
    this.maxDepth = 16,
    this.maxComponentsPerUpdate = 100,
    this.maxComponentsPerSurface = 200,
  });

  final String _catalogId;
  final int maxSurfaces;
  final int maxMessageBytes;
  final int maxDepth;
  final int maxComponentsPerUpdate;
  final int maxComponentsPerSurface;

  /// Longueur maximale (en runes) du JSON Pointer d'une liaison.
  static const int maxBindingPathRunes = 128;

  static final RegExp _surfaceIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static const List<String> _operations = <String>[
    'createSurface',
    'updateComponents',
    'updateDataModel',
    'deleteSurface',
  ];
  // Identifiants de composants connus par surface active (plafond 200).
  final Map<String, Set<String>> _active = <String, Set<String>>{};
  final Set<String> _blocked = <String>{};

  /// Surfaces actives.
  Set<String> get activeSurfaces => Set<String>.unmodifiable(_active.keys);

  /// Surfaces retirées par compensation, bloquées jusqu'à un nouveau
  /// `createSurface` valide.
  Set<String> get blockedSurfaces => Set<String>.unmodifiable(_blocked);

  /// Oublie toute surface (remise à vide).
  void reset() {
    _active.clear();
    _blocked.clear();
  }

  /// Valide [raw] et met à jour l'état. Ne modifie jamais [raw].
  ValidatedEnvelope check(
    Map<String, Object?> raw, {
    String? agent,
    String? task,
  }) {
    final (code, verdictOverride, surfaceId) = _evaluate(raw);
    ValidationVerdict verdict;
    var compensations = const <String>[];
    if (code != null) {
      verdict = ValidationRejected(code);
      // Compensation locale : le refus d'un message d'une surface existante
      // la retire et la bloque (cohérent pdr-0056 : on ne garde pas une
      // surface dans un état que le serveur n'a pas validé). Exception :
      // `surface_exists` (createSurface en double) refuse le doublon mais laisse
      // la surface existante, valide, intacte, comme le validateur Go.
      if (code != ValidationCodes.surfaceExists &&
          surfaceId != null &&
          _active.containsKey(surfaceId)) {
        _active.remove(surfaceId);
        _blocked.add(surfaceId);
        compensations = <String>[surfaceId];
      }
    } else {
      verdict = verdictOverride ?? const ValidationAccepted();
    }
    return ValidatedEnvelope(
      raw: raw,
      agent: agent,
      task: task,
      verdict: verdict,
      compensations: compensations,
    );
  }

  /// Renvoie (code de refus, verdict forcé, surfaceId visé) ; applique l'état
  /// seulement si le message est accepté.
  (String?, ValidationVerdict?, String?) _evaluate(Map<String, Object?> msg) {
    final guessed = _guessSurfaceId(msg);
    if (_depth(msg, maxDepth + 1) > maxDepth) {
      return (ValidationCodes.tooDeep, null, guessed);
    }
    final int size;
    try {
      size = utf8.encode(jsonEncode(msg)).length;
    } on Object {
      return (ValidationCodes.badOperation, null, guessed);
    }
    if (size > maxMessageBytes) {
      return (ValidationCodes.tooLarge, null, guessed);
    }
    if (msg['version'] != 'v0.9') {
      return (ValidationCodes.badVersion, null, guessed);
    }
    String? kind;
    for (final k in msg.keys) {
      if (k == 'version') continue;
      if (!_operations.contains(k) || kind != null) {
        return (ValidationCodes.badOperation, null, guessed);
      }
      kind = k;
    }
    if (kind == null) return (ValidationCodes.badOperation, null, guessed);
    final body = msg[kind];
    if (body is! Map) return (ValidationCodes.badOperation, null, guessed);
    final sid = body['surfaceId'];
    if (sid is! String || !_surfaceIdPattern.hasMatch(sid)) {
      return (ValidationCodes.badSurfaceId, null, guessed);
    }

    List<String> ids = const <String>[];
    switch (kind) {
      case 'createSurface':
        if (body['catalogId'] != _catalogId) {
          return (ValidationCodes.badCatalog, null, sid);
        }
        if (body.containsKey('sendDataModel') &&
            body['sendDataModel'] is! bool) {
          return (ValidationCodes.badOperation, null, sid);
        }
      case 'updateComponents':
        final r = _validateComponents(body);
        if (r.$1 != null) return (r.$1, null, sid);
        ids = r.$2;
      case 'updateDataModel':
        if (body.containsKey('path')) {
          final p = body['path'];
          if (p is! String || !_validPointer(p)) {
            return (ValidationCodes.badPointer, null, sid);
          }
        }
    }

    // Règles à état (registry.go, hors règles serveur).
    if (kind == 'createSurface') {
      if (_active.containsKey(sid)) {
        return (ValidationCodes.surfaceExists, null, sid);
      }
      if (_active.length >= maxSurfaces) {
        return (ValidationCodes.surfaceLimit, null, sid);
      }
      _active[sid] = <String>{};
      _blocked.remove(sid);
      return (null, null, sid);
    }
    final known = _active[sid];
    if (kind == 'deleteSurface') {
      // Absent du Go (la suppression d'une surface inconnue y est refusée) :
      // côté client une suppression en trop est sans effet, donc « ignorée ».
      if (known == null) return (null, const ValidationIgnored(), sid);
      _active.remove(sid);
      return (null, null, sid);
    }
    if (known == null) return (ValidationCodes.unknownSurface, null, sid);
    if (kind == 'updateComponents') {
      final total = known.length + ids.where((i) => !known.contains(i)).length;
      if (total > maxComponentsPerSurface) {
        return (ValidationCodes.componentCap, null, sid);
      }
      known.addAll(ids);
    }
    return (null, null, sid);
  }

  /// surfaceId visé, même si le message est mal formé (pour la compensation).
  String? _guessSurfaceId(Map<String, Object?> msg) {
    for (final k in _operations) {
      final b = msg[k];
      if (b is Map && b['surfaceId'] is String) {
        return b['surfaceId'] as String;
      }
    }
    return null;
  }

  (String?, List<String>) _validateComponents(Map<dynamic, dynamic> body) {
    final list = body['components'];
    final count = list is List ? list.length : 0;
    if (list is! List || count < 1 || count > maxComponentsPerUpdate) {
      return (ValidationCodes.badComponentCount, const <String>[]);
    }
    final seen = <String>{};
    for (final item in list) {
      if (item is! Map) return (ValidationCodes.badComponent, const []);
      final id = item['id'];
      if (id is! String || id.isEmpty) {
        return (ValidationCodes.badComponent, const []);
      }
      if (!seen.add(id)) {
        return (ValidationCodes.duplicateComponentId, const []);
      }
      final name = item['component'];
      if (name is! String || !GenesisContract.components.contains(name)) {
        return (ValidationCodes.componentNotAllowed, const []);
      }
      for (final k in item.keys) {
        if (!GenesisContract.allowedProperties.contains(k)) {
          return (ValidationCodes.badProperty, const []);
        }
      }
      if (item.containsKey('data') && !_validBinding(item['data'])) {
        return (ValidationCodes.badProperty, const []);
      }
      if (!_validChildRefs(item)) {
        return (ValidationCodes.badChildren, const <String>[]);
      }
    }
    return (null, seen.toList());
  }

  // Les propriétés admises ne contiennent ni child ni children : ce contrôle
  // n'est atteignable que si la liste blanche s'élargit, mais il est porté
  // pour la parité (childRefs du Go).
  bool _validChildRefs(Map<dynamic, dynamic> c) {
    if (c.containsKey('child')) {
      final s = c['child'];
      if (s is! String || s.isEmpty) return false;
    }
    if (!c.containsKey('children')) return true;
    final ch = c['children'];
    if (ch is List) {
      return ch.every((e) => e is String && e.isNotEmpty);
    }
    if (ch is Map) {
      final cid = ch['componentId'];
      return cid is String && cid.isNotEmpty && ch['path'] is String;
    }
    return false;
  }

  /// Exactement `{"path": "<JSON Pointer>"}` : une seule clé, pointeur non
  /// vide commençant par « / », borné, sans caractère de contrôle.
  bool _validBinding(Object? val) {
    if (val is! Map || val.length != 1) return false;
    final path = val['path'];
    if (path is! String ||
        !path.startsWith('/') ||
        path.runes.length > maxBindingPathRunes ||
        !_validPointer(path)) {
      return false;
    }
    return !path.runes.any(_isControlOrFormat);
  }

  /// JSON Pointer (RFC 6901) ; la chaîne vide est valide.
  bool _validPointer(String p) {
    if (p.isEmpty) return true;
    if (!p.startsWith('/')) return false;
    for (var i = 0; i < p.length; i++) {
      if (p.codeUnitAt(i) == 0x7E) {
        if (i + 1 >= p.length) return false;
        final n = p.codeUnitAt(i + 1);
        if (n != 0x30 && n != 0x31) return false;
      }
    }
    return true;
  }

  /// Équivalent de `unicode.IsControl` (Cc) ou `unicode.Is(unicode.Cf)` de Go.
  /// Dart n'a pas de catégories Unicode : les plages Cf courantes sont listées
  /// (approximation documentée ; le serveur reste la référence).
  static bool _isControlOrFormat(int r) =>
      r < 0x20 ||
      (r >= 0x7F && r <= 0x9F) ||
      r == 0xAD ||
      (r >= 0x600 && r <= 0x605) ||
      r == 0x61C ||
      r == 0x6DD ||
      r == 0x70F ||
      r == 0x8E2 ||
      r == 0x180E ||
      (r >= 0x200B && r <= 0x200F) ||
      (r >= 0x202A && r <= 0x202E) ||
      (r >= 0x2060 && r <= 0x2064) ||
      (r >= 0x2066 && r <= 0x206F) ||
      r == 0xFEFF ||
      (r >= 0xFFF9 && r <= 0xFFFB) ||
      (r >= 0x1D173 && r <= 0x1D17A) ||
      r == 0xE0001 ||
      (r >= 0xE0020 && r <= 0xE007F);

  /// Profondeur JSON de [x], arrêtée dès que [limit] est atteint (comme le Go).
  static int _depth(Object? x, int limit) {
    if (limit <= 0) return 0;
    var max = 0;
    if (x is Map) {
      max = 1;
      for (final e in x.values) {
        final d = 1 + _depth(e, limit - 1);
        if (d > max) max = d;
      }
    } else if (x is List) {
      max = 1;
      for (final e in x) {
        final d = 1 + _depth(e, limit - 1);
        if (d > max) max = d;
      }
    }
    return max;
  }
}
