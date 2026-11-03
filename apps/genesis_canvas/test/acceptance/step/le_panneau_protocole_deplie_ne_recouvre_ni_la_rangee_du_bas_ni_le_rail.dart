import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/replay_bar_harness.dart';

/// Usage: le panneau protocole déplié ne recouvre ni la rangée du bas ni le rail
Future<void> lePanneauProtocoleDeplieNeRecouvreNiLaRangeeDuBasNiLeRail(
  WidgetTester tester,
) async {
  final panel = ReplayBarHarness.panelRect(tester);
  final bottomRow = find.byKey(const Key('bottom-row'));
  expect(bottomRow, findsOneWidget, reason: 'bottom-row introuvable');
  final bottomRowRect = tester.getRect(bottomRow);
  expect(
    panel.bottom,
    lessThanOrEqualTo(bottomRowRect.top + 0.5),
    reason: 'le panneau ($panel) recouvre la rangée du bas ($bottomRowRect)',
  );
  final rail = tester.getRect(find.byKey(AcceptanceKeys.agentsRail));
  expect(
    panel.overlaps(rail),
    isFalse,
    reason: 'le panneau ($panel) recouvre le rail ($rail)',
  );
}
