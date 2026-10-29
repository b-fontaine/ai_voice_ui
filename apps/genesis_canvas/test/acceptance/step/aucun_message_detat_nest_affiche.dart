import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: aucun message d'état n'est affiché
Future<void> aucunMessageDetatNestAffiche(WidgetTester tester) async {
  expect(
    SessionHarness.statusMessage(tester),
    isNull,
    reason: 'status-message doit être absent',
  );
}
