import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'annulation de l'agent Qualité
///
/// `agent.activity` à l'état `canceled` (réservé au contrat, émis depuis 011).
Future<void> leServeurEmetLannulationDeLagentQualite(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emit(
      session,
      'agent.activity',
      <String, Object?>{
        'agent': 'Qualité',
        'task': 'task_1',
        'state': 'canceled',
        'label': 'Qualité',
      },
      tMs: 2500,
      agent: 'Qualité',
      task: 'task_1',
    ),
  );
}
