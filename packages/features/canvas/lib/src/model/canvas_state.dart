import 'package:flutter/foundation.dart';

/// Avancement du rendu d'une surface (les 3 temps de FR-04).
///
/// L'ordre de déclaration est l'ordre d'avancement : une phase ne recule pas.
enum SurfacePhase {
  /// Surface créée, pas encore de composants.
  skeleton,

  /// Composants définis (`updateComponents`).
  components,

  /// Données reçues (`updateDataModel`).
  data,
}

/// Avancement de la source de messages A2UI (rejeu, plus tard flux vivant).
enum CanvasSourceStatus {
  /// Aucune source souscrite.
  none,

  /// Source souscrite, flux en cours.
  playing,

  /// Flux terminé sans erreur.
  completed,

  /// Flux en erreur (voir `CanvasState.sourceError`).
  failed,
}

/// État du canevas : des identifiants de surface ordonnés et leur phase.
///
/// Aucun état genui n'est conservé ici : le rendu lit le `SurfaceController`.
@immutable
final class CanvasState {
  const CanvasState._(
    this._phases, [
    this.sourceStatus = CanvasSourceStatus.none,
    this.sourceError,
    this.decisionStatus,
  ]);

  /// Canevas sans surface ni source.
  const CanvasState.empty()
    : _phases = const <String, SurfacePhase>{},
      sourceStatus = CanvasSourceStatus.none,
      sourceError = null,
      decisionStatus = null;

  /// Avancement de la source de messages.
  final CanvasSourceStatus sourceStatus;

  /// Message d'erreur de la source si [sourceStatus] vaut `failed`.
  final String? sourceError;

  /// Statut de décision de la checklist (`/checklist/decisionStatus` du data
  /// model), ou `null` tant qu'il n'est pas connu.
  final String? decisionStatus;

  /// Même surfaces, nouveau statut de source.
  CanvasState withSource(CanvasSourceStatus status, {String? error}) =>
      CanvasState._(_phases, status, error, decisionStatus);

  /// Même état, avec le statut de décision [status] (`null` : inconnu).
  CanvasState withDecisionStatus(String? status) => status == decisionStatus
      ? this
      : CanvasState._(_phases, sourceStatus, sourceError, status);

  // Map à ordre d'insertion préservé (LinkedHashMap par défaut en Dart).
  final Map<String, SurfacePhase> _phases;

  /// Identifiants des surfaces, dans l'ordre de création.
  List<String> get surfaceIds => List<String>.unmodifiable(_phases.keys);

  /// Phase de la surface [surfaceId], ou `null` si elle est absente.
  SurfacePhase? phaseOf(String surfaceId) => _phases[surfaceId];

  /// Ajoute [surfaceId] en phase squelette ; sans effet si elle existe déjà.
  CanvasState withSurface(String surfaceId) {
    if (_phases.containsKey(surfaceId)) return this;
    return CanvasState._(
      <String, SurfacePhase>{..._phases, surfaceId: SurfacePhase.skeleton},
      sourceStatus,
      sourceError,
      decisionStatus,
    );
  }

  /// Fait avancer la phase de [surfaceId] ; sans effet si elle est absente ou plus avancée.
  CanvasState withPhase(String surfaceId, SurfacePhase phase) {
    final SurfacePhase? current = _phases[surfaceId];
    if (current == null || phase.index <= current.index) return this;
    return CanvasState._(
      <String, SurfacePhase>{..._phases, surfaceId: phase},
      sourceStatus,
      sourceError,
      decisionStatus,
    );
  }

  /// Retire [surfaceId] ; sans effet si elle est absente.
  CanvasState withoutSurface(String surfaceId) {
    if (!_phases.containsKey(surfaceId)) return this;
    return CanvasState._(
      <String, SurfacePhase>{..._phases}..remove(surfaceId),
      sourceStatus,
      sourceError,
      decisionStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CanvasState &&
      sourceStatus == other.sourceStatus &&
      sourceError == other.sourceError &&
      decisionStatus == other.decisionStatus &&
      listEquals(surfaceIds, other.surfaceIds) &&
      surfaceIds.every((String id) => _phases[id] == other._phases[id]);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    sourceStatus,
    sourceError,
    decisionStatus,
    for (final MapEntry<String, SurfacePhase> e in _phases.entries) ...<Object>[
      e.key,
      e.value,
    ],
  ]);

  @override
  String toString() => 'CanvasState($_phases, source: $sourceStatus)';
}
