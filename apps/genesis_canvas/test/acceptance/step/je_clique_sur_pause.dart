import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je clique sur Pause
Future<void> jeCliqueSurPause(WidgetTester tester) async {
  expect(
    Acte4Harness.playLabel(tester),
    contains('Pause'),
    reason: 'pendant la lecture, replay-play doit se nommer « Pause »',
  );
  await Acte4Harness.press(tester, ReplayKeys.play);
}
