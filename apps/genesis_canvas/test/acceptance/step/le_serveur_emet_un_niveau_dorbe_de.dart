import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet un niveau d'orbe de {'0.1'}
Future<void> leServeurEmetUnNiveauDorbeDe(
  WidgetTester tester,
  String level,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emit(
      session,
      'orb.level',
      <String, Object?>{'level': double.parse(level)},
    ),
  );
}
