import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: aucune valeur n'est encore affichée
///
/// Les composants sont posés (la cellule de chaque surface existe) mais les
/// données n'ont pas encore été émises : aucune valeur du jeu figé.
Future<void> aucuneValeurNestEncoreAffichee(WidgetTester tester) async {
  for (final id in AcceptanceKeys.act1Surfaces) {
    expect(
      find.byKey(AcceptanceKeys.surface(id)),
      findsOneWidget,
      reason: 'la surface $id doit exister avant ses données',
    );
  }
  expect(find.textContaining('99,57'), findsNothing);
  expect(find.textContaining('Taux de crash du jour'), findsNothing);
  expect(find.textContaining('Checklist go/no-go'), findsNothing);
}
