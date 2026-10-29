import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet les trois temps de la surface
Future<void> leServeurEmetLesTroisTempsDeLaSurface(WidgetTester tester) async {
  await SessionHarness.emitFixture(
    tester,
    (e) => SessionHarness.isType(e, 'a2ui'),
  );
}
