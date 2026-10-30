import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: je clique sur l'indicateur d'acte
Future<void> jeCliqueSurLindicateurDacte(WidgetTester tester) async {
  await SessionHarness.tap(tester, AcceptanceKeys.actIndicator);
}
