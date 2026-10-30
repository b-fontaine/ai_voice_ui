import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'agent Qualité au travail
Future<void> leServeurEmetLagentQualiteAuTravail(WidgetTester tester) async {
  await SessionHarness.emitFixture(
    tester,
    (e) =>
        // Le plan précède toujours l'activité (A8b).
        SessionHarness.isType(e, 'plan') ||
        SessionHarness.isActivity(e, 'working') ||
        e['type'] == 'usage' ||
        (e['type'] == 'transcript' &&
            (e['data']! as Map<String, Object?>)['role'] == 'ai'),
  );
}
