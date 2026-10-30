import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet le début de l'action
///
/// `plan` où Livraison est seul retenu, puis `agent.activity working`.
Future<void> leServeurEmetLeDebutDeLaction(WidgetTester tester) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActionStart(session),
  );
}
