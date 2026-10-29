import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

/// Usage: la valeur liée au modèle de données est affichée
///
/// Valeur du jeu figé (product/functional/dataset.md) : sessions sans crash
/// global 7 j, version 3.4 = 99,57 %.
Future<void> laValeurLieeAuModeleDeDonneesEstAffichee(
  WidgetTester tester,
) async {
  expect(
    find.descendant(
      of: find.byType(Surface),
      matching: find.textContaining('99,57'),
    ),
    findsOneWidget,
  );
}
