import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: l'étagère affiche {6} noms de composants entiers
///
/// Le nom de chaque composant du contrat figure en entier dans l'étagère
/// (texte exact) ; « entier » à l'écran se vérifie par l'absence de troncature
/// (`aucun libellé de l'étagère n'est tronqué`).
Future<void> letagereAfficheNomsDeComposantsEntiers(
  WidgetTester tester,
  num count,
) async {
  final shelf = find.byKey(AcceptanceKeys.catalogShelf);
  expect(shelf, findsOneWidget, reason: "l'étagère est absente");
  final found = <String>[
    for (final name in GenesisContract.components)
      if (find
          .descendant(of: shelf, matching: find.text(name))
          .evaluate()
          .isNotEmpty)
        name,
  ];
  expect(
    found,
    hasLength(count),
    reason: 'noms de composants trouvés dans l\'étagère : $found',
  );
}
