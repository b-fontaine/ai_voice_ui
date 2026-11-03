import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/fidelity_harness.dart';

/// Usage: le contenu de la surface {'crashes'} n'est pas encore net
Future<void> leContenuDeLaSurfaceNestPasEncoreNet(
  WidgetTester tester,
  String surface,
) async {
  final double sigma = Fidelity.blurOf(DesignHarness.contentOf(surface));
  expect(
    sigma,
    greaterThan(0.05),
    reason:
        'le flou de $surface doit durer toute la transition de 480 ms : σ $sigma à mi-parcours',
  );
}
