import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'état {'terminé'} de l'agent {'Qualité'}
///
/// [label] est le libellé du rail ; il se traduit en état du contrat
/// `agent.activity` (`canceled` s'émet par « l'annulation de l'agent Qualité »).
Future<void> leServeurEmetLetatDeLagent(
  WidgetTester tester,
  String label,
  String agent,
) async {
  const states = <String, String>{
    'terminé': 'completed',
    'échec': 'failed',
    'hors périmètre': 'rejected',
  };
  final state = states[label];
  if (state == null) fail('état de rail inconnu : « $label »');
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActivity(
      session,
      state,
      agents: <String>[agent],
    ),
  );
}
