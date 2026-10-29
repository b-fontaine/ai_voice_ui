import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la fin de l'activité de l'agent Qualité
Future<void> leServeurEmetLaFinDeLactiviteDeLagentQualite(
  WidgetTester tester,
) async {
  await SessionHarness.emitFixture(
    tester,
    (e) => SessionHarness.isActivity(e, 'completed'),
  );
}
