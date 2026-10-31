import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la délégation de la correction à {4000} ms
///
/// Délégation vocale d'offset [offsetMs] ; 4000 = coupure à 2500 ms + 1500 ms,
/// c'est-à-dire pile la borne de l'exemption `stopSpan` du « Stop ».
Future<void> leServeurEmetLaDelegationDeLaCorrectionAMs(
  WidgetTester tester,
  num offsetMs,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async =>
        SessionHarness.backend.emit(session, 'delegation', <String, Object?>{
          'id': 'deleg_correction',
          'offset_ms': offsetMs.toInt(),
        }, tMs: offsetMs.toInt()),
  );
}
