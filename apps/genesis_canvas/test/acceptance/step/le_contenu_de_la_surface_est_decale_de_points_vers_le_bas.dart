import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/scene_style_harness.dart';

/// Usage: le contenu de la surface {'crashes'} est décalé de {10} points vers le bas
///
/// Translation rendue du moteur de rendu de la surface (somme des
/// translations de ses ancêtres), au premier instant de l'apparition.
Future<void> leContenuDeLaSurfaceEstDecaleDePointsVersLeBas(
  WidgetTester tester,
  String surface,
  num points,
) async {
  final double dy = SceneStyleHarness.renderedTranslationY(
    DesignHarness.contentOf(surface),
    what: 'le contenu de la surface $surface',
  );
  expect(
    dy,
    closeTo(points.toDouble(), 0.5),
    reason: 'décalage vertical du contenu de $surface à son arrivée',
  );
}
