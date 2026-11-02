import 'package:flutter_test/flutter_test.dart';

import '../support/chart_harness.dart';
import '../support/scene_palette.dart';

/// Usage: le seuil du graphique est tracé en {'nogo'} en tirets
///
/// Couleur lue sur le peintre ; tirets vérifiés sur ce qui est peint : un
/// trait continu ferait un seul appel de dessin dans cette couleur.
Future<void> leSeuilDuGraphiqueEstTraceEnEnTirets(
  WidgetTester tester,
  String color,
) async {
  ChartHarness.expectColor(ChartHarness.threshold(tester), color, 'seuil');
  final int calls = ChartHarness.drawCallsWithColor(
    tester,
    ScenePalette.named(color),
  );
  expect(
    calls,
    greaterThanOrEqualTo(3),
    reason: 'seuil peint en $calls appel(s) de dessin : pas de tirets',
  );
}
