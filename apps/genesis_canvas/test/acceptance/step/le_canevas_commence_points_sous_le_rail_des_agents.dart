import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: le canevas commence {8} points sous le rail des agents
///
/// `canvas-board.top == agents-rail.bottom + 8` : aucune bande vide entre les
/// deux (A1).
Future<void> leCanevasCommencePointsSousLeRailDesAgents(
  WidgetTester tester,
  num gap,
) async {
  final rail = DesignHarness.rectOf(tester, AcceptanceKeys.agentsRail);
  final board = DesignHarness.rectOf(tester, AcceptanceKeys.canvasBoard);
  expect(
    board.top - rail.bottom,
    closeTo(gap, 0.5),
    reason:
        'le canevas (haut ${board.top}) doit commencer $gap points sous le '
        'rail (bas ${rail.bottom})',
  );
}
