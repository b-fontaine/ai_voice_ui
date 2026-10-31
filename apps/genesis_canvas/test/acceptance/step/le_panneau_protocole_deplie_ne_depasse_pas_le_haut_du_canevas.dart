import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: le panneau protocole déplié ne dépasse pas le haut du canevas
///
/// Déplié, le panneau recouvre le canevas à droite sans monter au-dessus de
/// lui (il ne recouvre ni le rail ni la barre du haut) et reste dans la fenêtre.
Future<void> lePanneauProtocoleDeplieNeDepassePasLeHautDuCanevas(
  WidgetTester tester,
) async {
  final panel = DesignHarness.rectOf(tester, AcceptanceKeys.protocolPanel);
  final board = DesignHarness.rectOf(tester, AcceptanceKeys.canvasBoard);
  expect(
    panel.top,
    greaterThanOrEqualTo(board.top - 0.5),
    reason: 'le panneau déplié ($panel) dépasse le haut du canevas ($board)',
  );
  final window = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(panel.bottom, lessThanOrEqualTo(window.height + 0.5));
  expect(panel.right, lessThanOrEqualTo(window.width + 0.5));
}
