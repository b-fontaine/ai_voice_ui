import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: le contenu de la surface {'crashes'} n'est pas encore pleinement visible
///
/// Complément de « est pleinement visible » : l'opacité rendue est
/// strictement inférieure à 0,99 (même critère).
Future<void> leContenuDeLaSurfaceNestPasEncorePleinementVisible(
  WidgetTester tester,
  String surface,
) async {
  final opacity = DesignHarness.renderedOpacity(
    DesignHarness.contentOf(surface),
    what: 'le contenu de la surface $surface',
  );
  expect(
    opacity,
    lessThan(0.99),
    reason: 'le contenu de $surface est déjà pleinement visible',
  );
}
