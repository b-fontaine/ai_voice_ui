import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet un plan vide
///
/// Aucun agent retenu : `selected` vide, les trois agents en `idle` (RG-08).
Future<void> leServeurEmetUnPlanVide(WidgetTester tester) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async =>
        SessionHarness.backend.emitGenesisPlan(session, selected: <String>[]),
  );
}
