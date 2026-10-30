import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le rejeu avance de {5} secondes
///
/// Temps simulé, pas du lecteur par pas (jamais `pumpAndSettle`).
Future<void> leRejeuAvanceDeSecondes(WidgetTester tester, num seconds) async {
  await Acte4Harness.elapse(tester, Acte4Harness.seconds(seconds));
}
