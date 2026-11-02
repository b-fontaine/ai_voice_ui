import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'keys.dart';
import 'scene_palette.dart';

/// Une série telle que le graphique de tendance la trace.
class ChartSeries {
  const ChartSeries(this.name, this.color, this.dashed);

  final String name;
  final Color color;
  final bool dashed;
}

/// Observation du graphique de tendance (U-06).
///
/// Le peintre du graphique n'est pas exporté par la slice `canvas` : il est
/// lu par son nom de type et par ses champs publics (`series`, `thresholdColor`)
/// sans importer son implémentation. Le seuil est en outre vérifié sur ce qui
/// est réellement peint : le peintre rejoue ses appels sur un
/// `TestRecordingCanvas`.
abstract final class ChartHarness {
  static dynamic painter(WidgetTester tester) {
    final Finder paint = find.descendant(
      of: find.byKey(AcceptanceKeys.surface('trend')),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == 'TrendChartPainter',
      ),
    );
    expect(paint, findsOneWidget, reason: 'le tracé du graphique est absent');
    return (tester.widget<CustomPaint>(paint)).painter;
  }

  static List<ChartSeries> series(WidgetTester tester) {
    final dynamic p = painter(tester);
    return <ChartSeries>[
      for (final dynamic s in p.series as List<dynamic>)
        ChartSeries(s.name as String, s.color as Color, s.dashed as bool),
    ];
  }

  static ChartSeries seriesNamed(WidgetTester tester, String name) {
    final List<ChartSeries> all = series(tester);
    final Iterable<ChartSeries> found = all.where(
      (ChartSeries s) => s.name == name,
    );
    expect(
      found,
      hasLength(1),
      reason:
          'série « $name » absente du graphique '
          '(séries : ${all.map((ChartSeries s) => s.name).toList()})',
    );
    return found.single;
  }

  static Color threshold(WidgetTester tester) =>
      painter(tester).thresholdColor as Color;

  /// Nombre d'appels de dessin (`drawLine`, `drawPath`, `drawRect`…) faits
  /// avec la couleur [color] quand le peintre peint dans un cadre de 800 x 400.
  static int drawCallsWithColor(WidgetTester tester, Color color) {
    final CustomPainter p = painter(tester) as CustomPainter;
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    p.paint(canvas, const Size(800, 400));
    var count = 0;
    for (final RecordedInvocation recorded in canvas.invocations) {
      for (final Object? arg in recorded.invocation.positionalArguments) {
        if (arg is Paint && ScenePalette.sameColor(arg.color, color)) count++;
      }
    }
    return count;
  }

  static void expectColor(Color actual, String token, String what) {
    final Color expected = ScenePalette.named(token);
    expect(
      ScenePalette.sameColor(actual, expected),
      isTrue,
      reason:
          '$what : couleur ${ScenePalette.describe(actual)}, attendue '
          '$token ${ScenePalette.describe(expected)}',
    );
  }
}
