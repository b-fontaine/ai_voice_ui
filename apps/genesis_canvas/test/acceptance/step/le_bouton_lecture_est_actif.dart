import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le bouton Lecture est actif
Future<void> leBoutonLectureEstActif(WidgetTester tester) async {
  await tester.pump();
  expect(Acte4Harness.playLabel(tester), contains('Lecture'));
  expect(
    Acte4Harness.isEnabled(tester, ReplayKeys.play),
    isTrue,
    reason: 'Lecture devrait être active',
  );
}
