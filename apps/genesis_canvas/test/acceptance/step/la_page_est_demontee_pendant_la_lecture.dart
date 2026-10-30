import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: la page est démontée pendant la lecture
///
/// Démontage de l'app et fermeture de la session (comme l'étape `After:`).
Future<void> laPageEstDemonteePendantLaLecture(WidgetTester tester) async {
  await SessionHarness.shutDown(tester);
}
