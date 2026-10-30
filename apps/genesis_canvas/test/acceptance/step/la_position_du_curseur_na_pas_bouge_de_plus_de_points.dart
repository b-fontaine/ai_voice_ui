import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: la position du curseur n'a pas bougé de plus de {5} points
Future<void> laPositionDuCurseurNaPasBougeDePlusDePoints(
  WidgetTester tester,
  num points,
) async {
  expect(
    Acte4Harness.position(tester),
    closeTo(Acte4Harness.notedPosition!, points),
    reason: 'le changement de vitesse ne doit ni sauter ni rembobiner',
  );
}
