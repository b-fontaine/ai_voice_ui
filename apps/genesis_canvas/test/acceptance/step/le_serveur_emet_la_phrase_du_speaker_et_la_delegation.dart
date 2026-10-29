import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la phrase du speaker et la délégation
Future<void> leServeurEmetLaPhraseDuSpeakerEtLaDelegation(
  WidgetTester tester,
) async {
  await SessionHarness.emitFixture(
    tester,
    (e) =>
        e['type'] == 'delegation' ||
        (e['type'] == 'transcript' &&
            (e['data']! as Map<String, Object?>)['role'] == 'user'),
  );
}
