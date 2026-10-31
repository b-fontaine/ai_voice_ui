import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: aucune ligne de la liste des crashs n'est affichée
Future<void> aucuneLigneDeLaListeDesCrashsNestAffichee(
  WidgetTester tester,
) async {
  expect(
    find.byKey(AcceptanceKeys.surface('crashes')),
    findsOneWidget,
    reason: 'la cellule surface-crashes doit exister',
  );
  expect(
    find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith('crash-row-');
    }),
    findsNothing,
    reason: 'une ligne de crash est affichée',
  );
}
