import 'package:flutter_test/flutter_test.dart';

import '../support/status_harness.dart';

/// Usage: le statut {'risk'} est affiché avec son mot, la couleur {'warn'} sur un fond {'warn-ghost'} et sans glyphe
Future<void> leStatutEstAfficheAvecSonMotLaCouleurSurUnFondEtSansGlyphe(
  WidgetTester tester,
  String status,
  String color,
  String background,
) async {
  StatusHarness.expectChips(
    tester,
    code: status,
    foreground: color,
    background: background,
    glyph: null,
  );
}
