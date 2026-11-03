import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/replay_bar_harness.dart';

/// Usage: je pose le doigt au milieu du curseur
Future<void> jePoseLeDoigtAuMilieuDuCurseur(WidgetTester tester) async {
  final slider = find.byKey(ReplayKeys.slider);
  expect(slider, findsOneWidget, reason: 'widget replay-slider introuvable');
  final center = tester.getCenter(slider);
  ReplayBarHarness.expectHit(tester, ReplayKeys.slider, center);
  Acte4Harness.gesture = await tester.startGesture(center);
  await tester.pump();
}
