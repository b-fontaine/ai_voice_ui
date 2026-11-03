import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

part 'ds_gauge.stories.g.dart';

const meta = Meta(DsGauge.new);

/// Couleurs de statut du thème de scène (`nogo`, `warn`, `go`).
const SceneTheme _theme = SceneTheme.dark();

/// Acte 2 : 99,43 % sous le seuil, repère de la version 3.3 (domaine 99 à
/// 100 : remplissage 43 %, marque 50 %, repère 71 %).
final $Blocking = _Story(
  args: _Args(
    fill: Arg.fixed(0.43),
    fillColor: Arg.fixed(_theme.blockingForeground),
    mark: Arg.fixed(0.5),
    markLabel: Arg.fixed('seuil ≥ 99,50 %'),
    reference: Arg.fixed(0.71),
    referenceLabel: Arg.fixed('3.3'),
  ),
);

/// Acte 1 : 99,57 % « À risque », marque de seuil, sans repère (pas de
/// comparaison).
final $Risk = _Story(
  args: _Args(
    fill: Arg.fixed(0.57),
    fillColor: Arg.fixed(_theme.riskForeground),
    mark: Arg.fixed(0.5),
    markLabel: Arg.fixed('seuil ≥ 99,50 %'),
    reference: Arg.fixed(null),
    referenceLabel: Arg.fixed(null),
  ),
);

/// Statut « ok » : remplissage `go`.
final $Ok = _Story(
  args: _Args(
    fill: Arg.fixed(0.8),
    fillColor: Arg.fixed(_theme.okForeground),
    mark: Arg.fixed(0.5),
    markLabel: Arg.fixed('seuil ≥ 99,50 %'),
    reference: Arg.fixed(null),
    referenceLabel: Arg.fixed(null),
  ),
);

/// Sans seuil ni comparaison lisibles : la piste et son remplissage seuls,
/// rien n'est inventé.
final $Bare = _Story(
  args: _Args(
    fill: Arg.fixed(0.43),
    fillColor: Arg.fixed(_theme.blockingForeground),
    mark: Arg.fixed(null),
    markLabel: Arg.fixed(null),
    reference: Arg.fixed(null),
    referenceLabel: Arg.fixed(null),
  ),
);

/// La jauge occupe la largeur de son parent : on lui donne celle d'une cellule
/// de la grille 3 x 2 (624 px moins les marges).
final defaults = _Defaults(
  setup: (context, child, args) => dsStorySetup(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 560, child: child),
    ),
  ),
);
