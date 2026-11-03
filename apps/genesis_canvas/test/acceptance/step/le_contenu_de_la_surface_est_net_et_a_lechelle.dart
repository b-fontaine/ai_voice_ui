import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/fidelity_harness.dart';

/// Usage: le contenu de la surface {'actions'} est net et à l'échelle
Future<void> leContenuDeLaSurfaceEstNetEtALechelle(
  WidgetTester tester,
  String surface,
) async {
  final Finder content = DesignHarness.contentOf(surface);
  expect(
    Fidelity.blurOf(content),
    lessThan(0.01),
    reason: 'le contenu de $surface est encore flou',
  );
  Fidelity.expectNear(
    Fidelity.scaleOf(content),
    1,
    0.001,
    what: "échelle du contenu de $surface",
  );
}
