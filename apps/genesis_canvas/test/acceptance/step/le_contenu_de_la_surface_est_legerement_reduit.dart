import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/fidelity_harness.dart';

/// Usage: le contenu de la surface {'crashes'} est légèrement réduit
Future<void> leContenuDeLaSurfaceEstLegerementReduit(
  WidgetTester tester,
  String surface,
) async {
  final double scale = Fidelity.scaleOf(DesignHarness.contentOf(surface));
  expect(
    scale,
    allOf(greaterThan(0.97), lessThan(0.995)),
    reason:
        "échelle du contenu de $surface à l'arrivée : $scale, attendu 0,985",
  );
}
