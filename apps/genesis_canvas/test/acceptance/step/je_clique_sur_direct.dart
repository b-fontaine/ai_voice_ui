import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/session_harness.dart';

/// Usage: je clique sur Direct
///
/// Relève les remises à vide déjà reçues : la requête de démarrage de l'app
/// n'est pas celle de « Direct ».
Future<void> jeCliqueSurDirect(WidgetTester tester) async {
  SessionHarness.resetsBeforeClick = SessionHarness.backend.canvasResets;
  await Acte4Harness.press(tester, ReplayKeys.direct);
}
