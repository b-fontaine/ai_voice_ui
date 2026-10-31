import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'interruption de cause overlap à {2500} ms
///
/// Message `voice.interrupted {at_ms, cause: overlap}` (spec 015, B5). La cause
/// est écrite en clair dans l'enveloppe : l'app qui ne la connaît pas la traite
/// comme `stop`, ce qui fait échouer les scénarios pour la bonne raison.
Future<void> leServeurEmetLinterruptionDeCauseOverlapAMs(
  WidgetTester tester,
  num atMs,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emit(
      session,
      'voice.interrupted',
      <String, Object?>{'at_ms': atMs.toInt(), 'cause': 'overlap'},
      tMs: atMs.toInt(),
    ),
  );
}
