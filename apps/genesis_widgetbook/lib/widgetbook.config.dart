import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'components.g.dart';
import 'scene_app_builder.dart';

/// Cellules réelles de la grille du canevas (px logiques), pour juger chaque
/// brique à la taille où elle s'affiche.
const cell620 = ViewportData(
  name: 'Cellule 620×302',
  width: 620,
  height: 302,
  pixelRatio: 1,
  platform: TargetPlatform.linux,
);
const cell940 = ViewportData(
  name: 'Cellule 940×302',
  width: 940,
  height: 302,
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
    ViewportAddon(const [cell620, cell940]),
  ],
  scenarioConfig: ScenarioConfig(
    definitions: [
      ScenarioDefinition(name: cell620.name, modes: [ViewportMode(cell620)]),
      ScenarioDefinition(name: cell940.name, modes: [ViewportMode(cell940)]),
    ],
  ),
);
