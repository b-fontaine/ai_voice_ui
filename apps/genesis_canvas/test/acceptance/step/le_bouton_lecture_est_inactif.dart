import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le bouton Lecture est inactif
Future<void> leBoutonLectureEstInactif(WidgetTester tester) async {
  await tester.pump();
  expect(Acte4Harness.playLabel(tester), contains('Lecture'));
  expect(
    Acte4Harness.isEnabled(tester, ReplayKeys.play),
    isFalse,
    reason: 'Lecture devrait être inactive (onPressed: null)',
  );
}
