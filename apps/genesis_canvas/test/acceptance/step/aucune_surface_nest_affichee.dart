import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

import '../support/keys.dart';

/// Usage: aucune surface n'est affichée
///
/// Ni cellule, ni squelette, ni moteur : un message refusé ne laisse rien.
Future<void> aucuneSurfaceNestAffichee(WidgetTester tester) async {
  for (final id in AcceptanceKeys.act1Surfaces) {
    expect(
      find.byKey(AcceptanceKeys.surface(id)),
      findsNothing,
      reason: 'la surface $id ne doit pas être affichée',
    );
    expect(find.byKey(AcceptanceKeys.skeleton(id)), findsNothing);
  }
  expect(find.byType(Surface), findsNothing);
}
