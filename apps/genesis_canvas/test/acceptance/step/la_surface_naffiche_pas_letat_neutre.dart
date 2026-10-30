import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: la surface {'kpi'} n'affiche pas l'état neutre
Future<void> laSurfaceNaffichePasLetatNeutre(
  WidgetTester tester,
  String surface,
) async {
  final cell = find.byKey(AcceptanceKeys.surface(surface));
  expect(
    find.descendant(
      of: cell,
      matching: find.byKey(AcceptanceKeys.neutral(surface)),
    ),
    findsNothing,
    reason: "la surface $surface affiche l'état neutre",
  );
  expect(
    find.descendant(of: cell, matching: find.text('Données indisponibles')),
    findsNothing,
  );
}
