import 'package:flutter/painting.dart';

import 'generated/scene_tokens.g.dart';

/// Rayons de coin du design system (pdr-0084 U1, U9), en pixels logiques.
///
/// Façade publique de `SceneTokens` (interne au paquet).
abstract final class SceneRadius {
  /// Chips du catalogue, cases de légende.
  static const double sm = SceneTokens.radiusSm;

  /// Boutons, lignes de checklist.
  static const double md = SceneTokens.radiusMd;

  /// Panneaux.
  static const double lg = SceneTokens.radiusLg;

  /// Badges de statut, segments d'acte.
  static const double pill = SceneTokens.radiusPill;

  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderPill = BorderRadius.all(
    Radius.circular(pill),
  );
}
