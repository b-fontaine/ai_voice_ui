import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: le composant {'ActionBar'} de l'étagère porte une icône d'état et est annoncé {'inutilisé'}
///
/// L'état est porté par une icône (A4) et par la sémantique (« utilisé » ou
/// « inutilisé » en toutes lettres) : la couleur n'est qu'un renfort.
Future<void> leComposantDeLetagerePorteUneIconeDetatEtEstAnnonce(
  WidgetTester tester,
  String component,
  String state,
) async {
  final pill = find.descendant(
    of: find.byKey(AcceptanceKeys.catalogShelf),
    matching: find.byKey(AcceptanceKeys.shelfItem(component)),
  );
  expect(pill, findsOneWidget, reason: 'puce $component absente');
  final icons = find.descendant(of: pill, matching: find.byType(Icon));
  expect(
    icons,
    findsOneWidget,
    reason: 'la puce $component doit porter une icône d\'état',
  );
  DesignHarness.shelfIcons[state] = tester.widget<Icon>(icons).icon!;

  final label = tester.getSemantics(pill).label;
  final announced = state == 'utilisé'
      ? label.replaceAll('inutilisé', '').contains('utilisé')
      : label.contains('inutilisé');
  expect(
    announced,
    isTrue,
    reason: 'la sémantique de $component doit annoncer « $state » : « $label »',
  );
}
