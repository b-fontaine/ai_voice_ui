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
  // Texte exact : « utilisé » n'est pas « inutilisé ».
  await SessionHarness.waitFor(
    tester,
    find.descendant(of: item, matching: find.text(state)),
    "le composant $component doit être « $state » dans l'étagère",
  );
}
