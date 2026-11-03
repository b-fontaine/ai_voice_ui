import 'package:shared_design_system/shared_design_system.dart';

/// Nombre de critères bloquants, d'après leur code `level` (jamais d'après
/// leur libellé de statut, qui est une donnée du backend).
int blockingCount(Iterable<SceneStatus> levels) =>
    levels.where((SceneStatus level) => level == SceneStatus.blocking).length;

/// Compteur de l'en-tête de la checklist : « 2 bloquants / 3 ».
///
/// Le mot s'accorde en français : 0 et 1 au singulier, 2 et plus au pluriel.
String blockingSummary(Iterable<SceneStatus> levels) {
  final int blocking = blockingCount(levels);
  final String noun = blocking >= 2 ? 'bloquants' : 'bloquant';
  return '$blocking $noun / ${levels.length}';
}
