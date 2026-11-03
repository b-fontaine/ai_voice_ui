import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/keys.dart';

/// Usage: aucun texte de la surface {'kpi'} ne contient {'vs seuil'}
Future<void> aucunTexteDeLaSurfaceNeContient(
  WidgetTester tester,
  String surface,
  String forbidden,
) async {
  final String actual = Fidelity.textOf(
    find.byKey(AcceptanceKeys.surface(surface)),
  );
  expect(
    Fidelity.containsText(actual, forbidden),
    isFalse,
    reason:
        "la surface $surface affiche « $forbidden » (valeur calculée, jamais donnée : Q-94) : « $actual »",
  );
}
