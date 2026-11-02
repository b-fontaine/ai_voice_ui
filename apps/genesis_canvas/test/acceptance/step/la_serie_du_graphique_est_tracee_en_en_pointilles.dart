import 'package:flutter_test/flutter_test.dart';

import '../support/chart_harness.dart';

/// Usage: la série {'Android 3.3'} du graphique est tracée en {'signal'} en pointillés
Future<void> laSerieDuGraphiqueEstTraceeEnEnPointilles(
  WidgetTester tester,
  String name,
  String color,
) async {
  final ChartSeries series = ChartHarness.seriesNamed(tester, name);
  ChartHarness.expectColor(series.color, color, 'série « $name »');
  expect(
    series.dashed,
    isTrue,
    reason: 'la série « $name » doit être en pointillés',
  );
}
