import 'generated/scene_tokens.g.dart';

/// Espacements du design system (pdr-0084 U1), en pixels logiques.
///
/// Façade publique de `SceneTokens` (interne au paquet). Les écarts entre
/// zones de la page et la marge d'écran de 013 (8 px) ne passent pas par ces
/// constantes : elles règlent le dedans des cellules.
abstract final class SceneSpace {
  /// Écart icône-texte, point de statut.
  static const double space1 = SceneTokens.space1;

  /// Écart entre chips.
  static const double space2 = SceneTokens.space2;

  /// Gouttière entre panneaux, padding des lignes de checklist.
  static const double space3 = SceneTokens.space3;

  /// Padding interne des contrôles.
  static const double space4 = SceneTokens.space4;

  /// Padding des panneaux du design system.
  static const double space6 = SceneTokens.space6;

  /// Marge extérieure de l'écran du design system.
  static const double space8 = SceneTokens.space8;
}
