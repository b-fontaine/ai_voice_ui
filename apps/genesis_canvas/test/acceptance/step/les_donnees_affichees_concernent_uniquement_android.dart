import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';
import 'la_surface_affiche.dart';

/// Usage: les données affichées concernent uniquement Android
///
/// Les surfaces annoncent Android, puis aucun texte du canevas ne cite iOS. Le
/// panneau du protocole et le rail sont hors du canevas : ils ne comptent pas.
Future<void> lesDonneesAfficheesConcernentUniquementAndroid(
  WidgetTester tester,
) async {
  await laSurfaceAffiche(tester, 'kpi', 'Sessions sans crash · Android');
  await laSurfaceAffiche(tester, 'reviews', 'Avis · Android');
  await laSurfaceAffiche(tester, 'checklist', 'Sessions sans crash Android');
  await SessionHarness.waitFor(
    tester,
    find.byKey(AcceptanceKeys.canvasBoard),
    'canevas absent',
  );
  expect(
    find.descendant(
      of: find.byKey(AcceptanceKeys.canvasBoard),
      matching: find.textContaining('iOS', findRichText: true),
    ),
    findsNothing,
    reason: 'le canevas cite encore iOS',
  );
}
