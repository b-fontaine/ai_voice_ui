import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le niveau lissé de l'orbe retombe à zéro
Future<void> leNiveauLisseDeLorbeRetombeAZero(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => SessionHarness.orbLevel(tester) == 0,
    timeout: SessionHarness.wait,
    reason: "le niveau lissé de l'orbe doit retomber à 0 après orb.level 0",
  );
}
