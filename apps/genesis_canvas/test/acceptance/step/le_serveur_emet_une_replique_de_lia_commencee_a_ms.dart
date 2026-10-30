import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet une réplique de l'IA {'Le tableau est prêt'} commencée à {2000} ms
///
/// Un delta de transcription de l'IA (`start_ms` sur l'horloge média).
Future<void> leServeurEmetUneRepliqueDeLiaCommenceeAMs(
  WidgetTester tester,
  String text,
  num startMs,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async =>
        SessionHarness.backend.emit(session, 'transcript', <String, Object?>{
          'role': 'ai',
          'text': text,
          'start_ms': startMs.toInt(),
          'end_ms': startMs.toInt() + 500,
        }, tMs: startMs.toInt() + 500),
  );
}
