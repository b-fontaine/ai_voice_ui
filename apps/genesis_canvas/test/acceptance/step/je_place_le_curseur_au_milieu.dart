import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/replay_bar_harness.dart';

/// Usage: je place le curseur au milieu
///
/// Un appui au centre du curseur : un seul seek, au relâchement.
Future<void> jePlaceLeCurseurAuMilieu(WidgetTester tester) async {
  final slider = find.byKey(ReplayKeys.slider);
  expect(slider, findsOneWidget, reason: 'widget replay-slider introuvable');
  final center = tester.getCenter(slider);
  ReplayBarHarness.expectHit(tester, ReplayKeys.slider, center);
  await tester.tapAt(center);
  await Acte4Harness.settle(tester);
}
