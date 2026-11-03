import 'package:flutter/foundation.dart' show immutable;

/// Surface que la page désigne comme **en cours de génération** : la dernière
/// surface créée, avec l'agent qui l'écrit (019 T32a, pdr-0088 F11).
///
/// C'est le contenu du port `CanvasBoard.generation`. La page le déduit de
/// l'enveloppe validée (`ValidatedEnvelope.agent`) : le contrat A2UI ne change
/// pas. [agent] est `null` sans agent connu (scénarios, rejeu) : l'étiquette du
/// cadre dit alors « génère » seul.
///
/// Le port ne dit pas **quand** le cadre s'arrête : le canevas le déduit de la
/// phase de la surface (`skeleton` et `components` : en cours ; `data` : fin).
@immutable
class GenerationTarget {
  const GenerationTarget({required this.surfaceId, this.agent});

  /// Identifiant de la surface cadrée.
  final String surfaceId;

  /// Nom de l'agent affiché dans l'étiquette, ou `null`.
  final String? agent;

  @override
  bool operator ==(Object other) =>
      other is GenerationTarget &&
      other.surfaceId == surfaceId &&
      other.agent == agent;

  @override
  int get hashCode => Object.hash(surfaceId, agent);

  @override
  String toString() => 'GenerationTarget($surfaceId, agent: $agent)';
}
