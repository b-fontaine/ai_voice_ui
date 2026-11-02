import 'package:flutter_test/flutter_test.dart';

import '../support/status_harness.dart';

/// Usage: le statut {'ok'} est affiché avec son mot, la couleur {'go'} sur un fond {'go-ghost'} et le glyphe {'✓'}
Future<void> leStatutEstAfficheAvecSonMotLaCouleurSurUnFondEtLeGlyphe(
  WidgetTester tester,
  String status,
  String color,
  String background,
  String glyph,
) async {
  StatusHarness.expectChips(
    tester,
    code: status,
    foreground: color,
    background: background,
    glyph: glyph,
  );
}
