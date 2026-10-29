import 'dart:convert';

/// Taille maximale, en caractères, d'une enveloppe du canal app.
const int maxEnvelopeLength = 262144;

/// Types de messages connus du canal app (contrat `app-channel-contract`).
abstract final class AppChannelTypes {
  static const String orbLevel = 'orb.level';
  static const String transcript = 'transcript';
  static const String sessionState = 'session.state';
  static const String usage = 'usage';
  static const String delegation = 'delegation';
  static const String agentActivity = 'agent.activity';
  static const String a2ui = 'a2ui';
}

/// Enveloppe invalide. Le motif est une phrase fermée : il ne reprend jamais
/// le contenu reçu, même partiellement.
class AppChannelFormatException implements Exception {
  const AppChannelFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'AppChannelFormatException: $reason';
}

/// Enveloppe `{v, type, session, t_ms, data}` du canal WSS `/app`, avec les
/// champs facultatifs `agent` et `task` de premier niveau.
///
/// Un `type` inconnu est conservé : c'est la conversion en événement qui
/// décide de l'ignorer.
class AppChannelEnvelope {
  const AppChannelEnvelope({
    required this.version,
    required this.type,
    required this.session,
    required this.tMs,
    required this.data,
    this.agent,
    this.task,
  });

  /// Décode et valide une enveloppe ; lève [AppChannelFormatException].
  factory AppChannelEnvelope.parse(String json) {
    if (json.length > maxEnvelopeLength) {
      throw const AppChannelFormatException('enveloppe trop grande');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const AppChannelFormatException('JSON invalide');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AppChannelFormatException('JSON invalide');
    }
    if (decoded['v'] != 1) {
      throw const AppChannelFormatException('version non prise en charge');
    }
    final type = decoded['type'];
    if (type is! String || type.isEmpty) throw _invalid('type');
    final session = decoded['session'];
    if (session is! String) throw _invalid('session');
    final tMs = decoded['t_ms'];
    if (tMs is! int || tMs < 0) throw _invalid('t_ms');
    final data = decoded['data'];
    if (data is! Map<String, Object?>) throw _invalid('data');
    final agent = decoded['agent'];
    if (agent != null && agent is! String) throw _invalid('agent');
    final task = decoded['task'];
    if (task != null && task is! String) throw _invalid('task');
    return AppChannelEnvelope(
      version: 1,
      type: type,
      session: session,
      tMs: tMs,
      data: data,
      agent: agent as String?,
      task: task as String?,
    );
  }

  static AppChannelFormatException _invalid(String field) =>
      AppChannelFormatException('champ manquant ou invalide : $field');

  final int version;
  final String type;
  final String session;
  final int tMs;
  final Map<String, Object?> data;
  final String? agent;
  final String? task;

  @override
  bool operator ==(Object other) =>
      other is AppChannelEnvelope &&
      other.version == version &&
      other.type == type &&
      other.session == session &&
      other.tMs == tMs &&
      other.agent == agent &&
      other.task == task &&
      _deepEquals(other.data, data);

  @override
  int get hashCode =>
      Object.hash(version, type, session, tMs, agent, task, _deepHash(data));
}

/// Égalité profonde de valeurs JSON (listes, objets, scalaires).
bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Hachage profond cohérent avec [_deepEquals] (indépendant de l'ordre des clés).
int _deepHash(Object? value) {
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map((e) => Object.hash(e.key, _deepHash(e.value))),
    );
  }
  if (value is List) return Object.hashAll(value.map(_deepHash));
  return value.hashCode;
}
