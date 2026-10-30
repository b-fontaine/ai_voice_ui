import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: je clique sur Arrêter
Future<void> jeCliqueSurArreter(WidgetTester tester) async {
  await SessionHarness.tap(tester, SessionHarness.stopKey);
}
