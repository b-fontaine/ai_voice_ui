import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je pose le doigt au milieu du curseur
Future<void> jePoseLeDoigtAuMilieuDuCurseur(WidgetTester tester) async {
  final slider = find.byKey(ReplayKeys.slider);
  expect(slider, findsOneWidget, reason: 'widget replay-slider introuvable');
  Acte4Harness.gesture = await tester.startGesture(tester.getCenter(slider));
  await tester.pump();
}
