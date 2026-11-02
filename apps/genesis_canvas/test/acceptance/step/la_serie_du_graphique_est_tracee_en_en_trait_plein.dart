import 'package:flutter_test/flutter_test.dart';

import '../support/chart_harness.dart';

/// Usage: la série {'Android 3.4'} du graphique est tracée en {'signal'} en trait plein
Future<void> laSerieDuGraphiqueEstTraceeEnEnTraitPlein(
  WidgetTester tester,
  String name,
  String color,
) async {
  final ChartSeries series = ChartHarness.seriesNamed(tester, name);
  ChartHarness.expectColor(series.color, color, 'série « $name »');
  expect(series.dashed, isFalse, reason: 'la série « $name » doit être pleine');
}
