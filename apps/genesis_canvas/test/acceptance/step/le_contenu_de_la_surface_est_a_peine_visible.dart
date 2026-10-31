import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: le contenu de la surface {'kpi'} est à peine visible
///
/// Opacité rendue du moteur de rendu de la surface < 0,3 : le fondu des
/// composants commence (B1). L'animation n'est pas importée : seule l'opacité
/// peinte est mesurée.
Future<void> leContenuDeLaSurfaceEstAPeineVisible(
  WidgetTester tester,
  String surface,
) async {
  final opacity = DesignHarness.renderedOpacity(
    DesignHarness.contentOf(surface),
    what: 'le contenu de la surface $surface',
  );
  expect(
    opacity,
    lessThan(0.3),
    reason: 'opacité du contenu de $surface à l\'arrivée des composants',
  );
}
