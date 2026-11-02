import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/scene_style_harness.dart';

/// Usage: le contenu de la surface {'crashes'} n'est plus décalé
Future<void> leContenuDeLaSurfaceNestPlusDecale(
  WidgetTester tester,
  String surface,
) async {
  final double dy = SceneStyleHarness.renderedTranslationY(
    DesignHarness.contentOf(surface),
    what: 'le contenu de la surface $surface',
  );
  expect(
    dy,
    closeTo(0, 0.01),
    reason: 'décalage vertical résiduel du contenu de $surface',
  );
}
