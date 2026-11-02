import 'package:flutter/painting.dart';

/// Graisse de la scène : `fontWeight` et axe `wght` portent **la même
/// valeur** (U11). Les polices sont variables : `FontVariation('wght', n)`
/// règle l'axe, `fontWeight` sert à la sélection de la graisse et au
/// repli (DejaVu Sans, qui est statique).
final class SceneWeight {
  const SceneWeight._(this.fontWeight, this.variations);

  final FontWeight fontWeight;
  final List<FontVariation> variations;
}

/// Paire cohérente pour une valeur de l'axe `wght` (1 à 1000).
SceneWeight sceneWeight(int wght) {
  if (wght < 1 || wght > 1000) {
    throw ArgumentError.value(
      wght,
      'wght',
      'doit être compris entre 1 et 1000',
    );
  }
  return SceneWeight._(FontWeight(wght), <FontVariation>[
    FontVariation('wght', wght.toDouble()),
  ]);
}

extension SceneWeightStyle on TextStyle {
  /// Ce style avec la graisse [wght] : `fontWeight` et `fontVariations`
  /// ensemble. Une variation de `wght` existante est remplacée, les autres
  /// axes sont conservés.
  TextStyle withSceneWeight(int wght) {
    final SceneWeight weight = sceneWeight(wght);
    return copyWith(
      fontWeight: weight.fontWeight,
      fontVariations: <FontVariation>[
        for (final FontVariation v in fontVariations ?? const <FontVariation>[])
          if (v.axis != 'wght') v,
        ...weight.variations,
      ],
    );
  }
}
