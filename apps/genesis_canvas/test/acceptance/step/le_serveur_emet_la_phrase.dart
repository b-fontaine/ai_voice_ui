import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la phrase {'Montre-moi les avis'}
Future<void> leServeurEmetLaPhrase(WidgetTester tester, String text) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async =>
        SessionHarness.backend.emit(session, 'transcript', <String, Object?>{
          'role': 'user',
          'text': text,
          'start_ms': 300,
          'end_ms': 1200,
        }, tMs: 1200),
  );
}
