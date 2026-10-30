import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'interruption à {2500} ms
///
/// Message `voice.interrupted {at_ms}` de l'app-channel (pdr-0073, D1).
Future<void> leServeurEmetLinterruptionAMs(
  WidgetTester tester,
  num atMs,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emit(
      session,
      'voice.interrupted',
      <String, Object?>{'at_ms': atMs.toInt()},
      tMs: atMs.toInt(),
    ),
  );
}
