import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: la surface {'checklist'} n'est pas encore affichée
Future<void> laSurfaceNestPasEncoreAffichee(
  WidgetTester tester,
  String surface,
) async {
  await tester.pump();
  expect(
    find.byKey(AcceptanceKeys.surface(surface)),
    findsNothing,
    reason: 'la surface $surface ne devrait pas encore être reconstruite',
  );
}
