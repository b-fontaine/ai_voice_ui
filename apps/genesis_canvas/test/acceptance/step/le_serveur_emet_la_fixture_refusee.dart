import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la fixture refusée {'component_not_allowed'}
Future<void> leServeurEmetLaFixtureRefusee(
  WidgetTester tester,
  String name,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisInvalid(session, name),
  );
}
