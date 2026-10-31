import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'interruption de cause correction à {2500} ms
///
/// Message `voice.interrupted {at_ms, cause: correction}` (pdr-0076, P2).
Future<void> leServeurEmetLinterruptionDeCauseCorrectionAMs(
  WidgetTester tester,
  num atMs,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emit(
      session,
      'voice.interrupted',
      <String, Object?>{'at_ms': atMs.toInt(), 'cause': 'correction'},
      tMs: atMs.toInt(),
    ),
  );
}
