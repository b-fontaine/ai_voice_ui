import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: le contenu de la surface {'crashes'} est pleinement visible
Future<void> leContenuDeLaSurfaceEstPleinementVisible(
  WidgetTester tester,
  String surface,
) async {
  final opacity = DesignHarness.renderedOpacity(
    DesignHarness.contentOf(surface),
    what: 'le contenu de la surface $surface',
  );
  expect(
    opacity,
    greaterThanOrEqualTo(0.99),
    reason: 'opacité du contenu de $surface',
  );
}
