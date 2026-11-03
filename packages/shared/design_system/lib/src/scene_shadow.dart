import 'package:flutter/painting.dart';

import 'generated/scene_tokens.g.dart';

/// Ombres du design system (pdr-0084 U9), en `BoxShadow` constants.
///
/// Façade publique de `SceneTokens` (interne au paquet). Le flou CSS `B` du
/// design system est converti à la génération (sigma = B / 2, voir
/// `tool/build_tokens.mjs`).
abstract final class SceneShadow {
  /// Élévation des panneaux sur le fond. L'ombre `inset` du design system (le
  /// filet de 1 px du haut) n'est pas exprimable : c'est `SceneTheme.panelHighlight`,
  /// peint par le panneau.
  static const List<BoxShadow> panel = SceneTokens.shadowPanel;

  /// Panneau en cours de génération, chip actif.
  static const List<BoxShadow> glowSignal = SceneTokens.shadowGlowSignal;

  /// Verdict Bloquant.
  static const List<BoxShadow> glowNogo = SceneTokens.shadowGlowNogo;

  /// Orbe vocal quand l'IA parle.
  static const List<BoxShadow> glowPlasma = SceneTokens.shadowGlowPlasma;

  /// Halo du point de l'orchestrateur (rail des agents) : plasma à 60 %, rayon
  /// de flou de 10.
  static const List<BoxShadow> glowPlasmaDot = SceneTokens.shadowGlowPlasmaDot;

  /// Lueur `nogo` du chiffre héros bloquant (`text-shadow`) : `nogo` à un
  /// tiers, rayon de flou de 32. S'applique aussi à `Shadow` (un `BoxShadow`
  /// en est un).
  static const List<BoxShadow> textGlowNogo = SceneTokens.shadowTextGlowNogo;

  /// Opacité de la lueur d'une série de graphique : la couleur est celle de la
  /// série, donc ce n'est pas une ombre complète.
  static const double seriesGlowAlpha = SceneTokens.shadowSeriesGlowAlpha;

  /// Écart type du flou de la lueur d'une série de graphique.
  static const double seriesGlowSigma = SceneTokens.shadowSeriesGlowSigma;
}
