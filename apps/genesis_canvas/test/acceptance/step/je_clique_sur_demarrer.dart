import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: je clique sur Démarrer
Future<void> jeCliqueSurDemarrer(WidgetTester tester) async {
  await SessionHarness.tap(tester, SessionHarness.startKey);
}
