import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le bouton de lecture affiche {'Lecture'}
///
/// Libellé sémantique de `replay-play` : « Lecture » ou « Pause ».
Future<void> leBoutonDeLectureAffiche(WidgetTester tester, String label) async {
  await tester.pump();
  expect(Acte4Harness.playLabel(tester), contains(label));
}
