import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: la ligne de comparaison de la surface {'kpi'} affiche {'3.3 : 99,71 % · −0,28 pt'}
///
/// La ligne est un seul `Text` de clé `comparison-<surface>`.
Future<void> laLigneDeComparaisonDeLaSurfaceAffiche(
  WidgetTester tester,
  String surface,
  String text,
) async {
  final line = find.descendant(
    of: find.byKey(AcceptanceKeys.surface(surface)),
    matching: find.byKey(AcceptanceKeys.comparison(surface)),
  );
  await SessionHarness.waitFor(
    tester,
    line,
    'ligne de comparaison absente de la surface $surface '
    '(clé comparison-$surface)',
  );
  await SessionHarness.waitFor(
    tester,
    find.descendant(of: line, matching: find.text(text), matchRoot: true),
    'la ligne de comparaison de $surface doit afficher « $text »',
  );
}
