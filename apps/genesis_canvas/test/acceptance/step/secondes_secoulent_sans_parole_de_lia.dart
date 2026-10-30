import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: {3} secondes s'écoulent sans parole de l'IA
///
/// Frontière « temps » : l'horloge de l'app et celle du banc avancent
/// ensemble ; aucun niveau d'orbe n'est émis entre-temps.
Future<void> secondesSecoulentSansParoleDeLia(
  WidgetTester tester,
  num seconds,
) async {
  Acte4Harness.clock.advance(Acte4Harness.seconds(seconds));
  await Acte4Harness.elapse(tester, Acte4Harness.seconds(seconds));
}
