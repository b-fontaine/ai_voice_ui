import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le composant {'ReviewSentiment'} de l'étagère est {'utilisé'}
Future<void> leComposantDeLetagereEst(
  WidgetTester tester,
  String component,
  String state,
) async {
  final item = find.descendant(
    of: find.byKey(AcceptanceKeys.catalogShelf),
    matching: find.byKey(AcceptanceKeys.shelfItem(component)),
  );
  await SessionHarness.waitFor(
    tester,
    item,
    "l'étagère doit contenir le composant $component (shelf-$component)",
  );
  // L'état est porté par l'icône (013, D-04) : carré plein pour « utilisé »,
  // carré vide pour « inutilisé » (019, `gc-chip`). Le libellé de sémantique
  // est vérifié par
  // `le composant {...} de l'étagère porte une icône d'état et est annoncé`.
  final icon = state == 'utilisé' ? Icons.square : Icons.square_outlined;
  await SessionHarness.waitFor(
    tester,
    find.descendant(of: item, matching: find.byIcon(icon)),
    "le composant $component doit être « $state » dans l'étagère",
  );
}
