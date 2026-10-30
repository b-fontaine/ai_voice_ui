/// Codes de refus fermés du validateur (mêmes noms que le validateur Go,
/// `backend/orchestrator/internal/app/a2ui`). Aucun texte du fournisseur n'y
/// figure.
abstract final class ValidationCodes {
  static const String badVersion = 'bad_version';
  static const String badOperation = 'bad_operation';
  static const String tooLarge = 'too_large';
  static const String tooDeep = 'too_deep';
  static const String badSurfaceId = 'bad_surface_id';
  static const String badCatalog = 'bad_catalog';
  static const String badComponentCount = 'bad_component_count';
  static const String duplicateComponentId = 'duplicate_component_id';
  static const String badComponent = 'bad_component';
  static const String componentNotAllowed = 'component_not_allowed';
  static const String badChildren = 'bad_children';
  static const String badPointer = 'bad_pointer';
  static const String badProperty = 'bad_property';
  static const String surfaceExists = 'surface_exists';
  static const String surfaceLimit = 'surface_limit';
  static const String unknownSurface = 'unknown_surface';
  static const String componentCap = 'component_cap';
}

/// Verdict du validateur sur un message A2UI.
sealed class ValidationVerdict {
  const ValidationVerdict();
}

/// Message conforme : il peut être relayé au moteur.
final class ValidationAccepted extends ValidationVerdict {
  const ValidationAccepted();

  @override
  bool operator ==(Object other) => other is ValidationAccepted;

  @override
  int get hashCode => (ValidationAccepted).hashCode;

  @override
  String toString() => 'accepted';
}

/// Message refusé, avec un code de [ValidationCodes].
final class ValidationRejected extends ValidationVerdict {
  const ValidationRejected(this.code);

  final String code;

  @override
  bool operator ==(Object other) =>
      other is ValidationRejected && other.code == code;

  @override
  int get hashCode => Object.hash(ValidationRejected, code);

  @override
  String toString() => 'rejected($code)';
}

/// Message sans effet à ne pas afficher (ex. `deleteSurface` d'une surface
/// absente) ; il est seulement compté.
final class ValidationIgnored extends ValidationVerdict {
  const ValidationIgnored();

  @override
  bool operator ==(Object other) => other is ValidationIgnored;

  @override
  int get hashCode => (ValidationIgnored).hashCode;

  @override
  String toString() => 'ignored';
}

/// Message A2UI brut accompagné de son verdict. Immuable (copie profonde de
/// [raw], non modifiable), égalité par valeur.
final class ValidatedEnvelope {
  ValidatedEnvelope({
    required Map<String, Object?> raw,
    required this.verdict,
    this.agent,
    this.task,
    List<String> compensations = const <String>[],
  }) : raw = _freeze(raw) as Map<String, Object?>,
       compensations = List<String>.unmodifiable(compensations);

  /// Message tel que reçu.
  final Map<String, Object?> raw;
  final String? agent;
  final String? task;
  final ValidationVerdict verdict;

  /// Surfaces que l'appelant doit retirer localement (`deleteSurface` local)
  /// à la suite d'un refus (compensation locale, A2 plan 007).
  final List<String> compensations;

  @override
  bool operator ==(Object other) =>
      other is ValidatedEnvelope &&
      other.agent == agent &&
      other.task == task &&
      other.verdict == verdict &&
      _deepEquals(other.raw, raw) &&
      _deepEquals(other.compensations, compensations);

  @override
  int get hashCode => Object.hash(
    agent,
    task,
    verdict,
    _deepHash(raw),
    Object.hashAll(compensations),
  );

  @override
  String toString() => 'ValidatedEnvelope($verdict, agent: $agent)';
}

Object? _freeze(Object? v) => switch (v) {
  Map() => Map<String, Object?>.unmodifiable(<String, Object?>{
    for (final e in v.entries) e.key as String: _freeze(e.value),
  }),
  List() => List<Object?>.unmodifiable(v.map(_freeze)),
  _ => v,
};

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
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

int _deepHash(Object? v) => switch (v) {
  Map() => Object.hashAllUnordered(
    v.entries.map((e) => Object.hash(e.key, _deepHash(e.value))),
  ),
  List() => Object.hashAll(v.map(_deepHash)),
  _ => v.hashCode,
};
