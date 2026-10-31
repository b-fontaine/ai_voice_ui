import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: la ligne {1} de la liste des crashs est à peine visible
///
/// Opacité rendue de la ligne de rang donné (fondu des valeurs, B1).
Future<void> laLigneDeLaListeDesCrashsEstAPeineVisible(
  WidgetTester tester,
  num rank,
) async {
  final opacity = DesignHarness.renderedOpacity(
    find.byKey(AcceptanceKeys.crashRow(rank.toInt())),
    what: 'la ligne $rank de la liste des crashs',
  );
  expect(
    opacity,
    lessThan(0.3),
    reason: 'opacité de la ligne $rank de la liste des crashs',
  );
}
