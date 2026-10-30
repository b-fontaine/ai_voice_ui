import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: la surface {'kpi'} affiche l'état neutre {'Données indisponibles'}
Future<void> laSurfaceAfficheLetatNeutre(
  WidgetTester tester,
  String surface,
  String text,
) async {
  final neutral = find.descendant(
    of: find.byKey(AcceptanceKeys.surface(surface)),
    matching: find.byKey(AcceptanceKeys.neutral(surface)),
  );
  await SessionHarness.waitFor(
    tester,
    neutral,
    "la surface $surface doit afficher l'état neutre (neutral-$surface)",
  );
  expect(
    find.descendant(of: neutral, matching: find.text(text)),
    findsOneWidget,
  );
}
