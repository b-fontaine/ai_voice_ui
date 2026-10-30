import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: l'app est fermée et le faux backend arrêté
Future<void> lappEstFermeeEtLeFauxBackendArrete(WidgetTester tester) async {
  await SessionHarness.shutDown(tester);
}
