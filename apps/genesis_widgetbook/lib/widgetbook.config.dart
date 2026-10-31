import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'components.g.dart';
import 'scene_app_builder.dart';

/// Cellules réelles de la grille du canevas (624×302 et 936×302 px logiques),
/// pour juger chaque brique à la taille où elle s'affiche. Le viewport ajoute
/// la marge de 8 px par côté de `sceneAppBuilder` (cellule + 2 × 8).
const cell624 = ViewportData(
  name: 'Cellule 624×302',
  width: 640,
  height: 318,
  pixelRatio: 1,
  platform: TargetPlatform.linux,
);
const cell936 = ViewportData(
  name: 'Cellule 936×302',
  width: 952,
  height: 318,
  pixelRatio: 1,
  platform: TargetPlatform.linux,
);

/// Configuration du catalogue : thème de scène seul (RG-09), sans bascule
/// clair/sombre. Chaque story est capturée dans les deux cellules ; déclarer
/// des définitions supprime le scénario implicite « Default » (spike,
/// contournement 5).
final config = Config(
  components: components,
  appBuilder: sceneAppBuilder,
  addons: [
    ViewportAddon(const [cell624, cell936]),
  ],
  scenarioConfig: ScenarioConfig(
    definitions: [
      ScenarioDefinition(name: cell624.name, modes: [ViewportMode(cell624)]),
      ScenarioDefinition(name: cell936.name, modes: [ViewportMode(cell936)]),
    ],
  ),
);
