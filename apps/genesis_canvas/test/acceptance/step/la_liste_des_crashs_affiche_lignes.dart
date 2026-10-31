import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: la liste des crashs affiche {5} lignes
///
/// Une ligne `crash-row-<rang>` par crash, de 1 à n, sous la cellule
/// `surface-crashes`.
Future<void> laListeDesCrashsAfficheLignes(
  WidgetTester tester,
  num count,
) async {
  await SessionHarness.waitFor(
    tester,
    find.byKey(AcceptanceKeys.crashRow(count.toInt())),
    'la ligne de rang $count (crash-row-$count) doit être affichée',
  );
  final rows = find.descendant(
    of: find.byKey(AcceptanceKeys.surface('crashes')),
    matching: find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith('crash-row-');
    }),
  );
  expect(rows, findsNWidgets(count.toInt()));
  for (var rank = 1; rank <= count; rank++) {
    expect(find.byKey(AcceptanceKeys.crashRow(rank)), findsOneWidget);
  }
}
