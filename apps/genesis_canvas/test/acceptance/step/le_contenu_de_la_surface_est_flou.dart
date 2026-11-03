import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/fidelity_harness.dart';

/// Usage: le contenu de la surface {'crashes'} est flou
Future<void> leContenuDeLaSurfaceEstFlou(
  WidgetTester tester,
  String surface,
) async {
  final double sigma = Fidelity.blurOf(DesignHarness.contentOf(surface));
  expect(
    sigma,
    greaterThan(3),
    reason:
        "flou (σ) du contenu de $surface à l'arrivée : $sigma, attendu 4 (gc-rise, pdr-0088 F5)",
  );
}
