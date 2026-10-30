import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le faux backend suspend l'action après l'avoir acceptée
///
/// Le faux backend répond 202 mais n'enchaîne pas seul la séquence de l'acte 3
/// : le scénario émet le début puis le résultat de l'action.
Future<void> leFauxBackendSuspendLactionApresLavoirAcceptee(
  WidgetTester tester,
) async {
  SessionHarness.backend.actionAutoRun = false;
}
