import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/chart_harness.dart';
import '../support/scene_palette.dart';
import '../support/scene_style_harness.dart';

/// Usage: aucune série du graphique n'est tracée avec une couleur de statut ni avec {'plasma'}
///
/// Les couleurs interdites sont celles du design system (go, warn, nogo,
/// plasma) et celles que le thème de l'app donne aux statuts.
Future<void> aucuneSerieDuGraphiqueNestTraceeAvecUneCouleurDeStatutNiAvec(
  WidgetTester tester,
  String forbidden,
) async {
  final SceneTheme theme = SceneStyleHarness.theme(tester);
  final List<Color> statusColors = <Color>[
    ...ScenePalette.statusColors,
    theme.okForeground,
    theme.riskForeground,
    theme.blockingForeground,
    ScenePalette.named(forbidden),
  ];
  final List<ChartSeries> series = ChartHarness.series(tester);
  expect(series, isNotEmpty, reason: 'le graphique ne trace aucune série');
  final List<String> wrong = <String>[
    for (final ChartSeries s in series)
      if (statusColors.any((Color c) => ScenePalette.sameColor(c, s.color)))
        '« ${s.name} » : ${ScenePalette.describe(s.color)}',
  ];
  expect(
    wrong,
    isEmpty,
    reason:
        'séries tracées en couleur de statut ou $forbidden :\n'
        '${wrong.join('\n')}',
  );
}
