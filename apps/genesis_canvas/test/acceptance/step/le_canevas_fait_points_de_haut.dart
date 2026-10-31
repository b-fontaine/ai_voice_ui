import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: le canevas fait {676} points de haut
///
/// 1920 x 1080 : 1080 - marges et intervalles (40) - barre (128) - rail (96) -
/// rangée du bas (140) = 676, soit deux rangées de 302 et le bandeau de 72.
Future<void> leCanevasFaitPointsDeHaut(WidgetTester tester, num height) async {
  final board = DesignHarness.rectOf(tester, AcceptanceKeys.canvasBoard);
  expect(
    board.height,
    closeTo(height, 0.5),
    reason: 'hauteur du canevas : ${board.height} points au lieu de $height',
  );
}
