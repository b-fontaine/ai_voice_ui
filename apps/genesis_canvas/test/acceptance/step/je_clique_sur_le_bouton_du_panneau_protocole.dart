import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: je clique sur le bouton du panneau protocole
Future<void> jeCliqueSurLeBoutonDuPanneauProtocole(WidgetTester tester) async {
  await SessionHarness.tap(tester, AcceptanceKeys.protocolToggle);
}
