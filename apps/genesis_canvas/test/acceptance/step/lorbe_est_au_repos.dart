import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: l'orbe est au repos
Future<void> lorbeEstAuRepos(WidgetTester tester) async {
  expect(find.byKey(const Key('voice-orb')), findsOneWidget);
  expect(
    SessionHarness.orbLevel(tester),
    0,
    reason: 'orbe au repos : niveau lissé nul',
  );
}
