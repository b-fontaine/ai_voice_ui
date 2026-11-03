import 'package:flutter_test/flutter_test.dart';

import '../../support/act_indicator_finder.dart';
import '../support/acte4_harness.dart';

/// Usage: la zone Rejeu est en pause à mi-parcours
///
/// État de l'arbre au moment de la sortie (la capture n'y change rien) :
/// indicateur « Acte 4 · Rejeu », curseur vers 50 %, bouton « Lecture » (donc
/// en pause).
Future<void> laZoneRejeuEstEnPauseAMiparcours(WidgetTester tester) async {
  Acte4Harness.ensureSemantics(tester);
  try {
    await tester.pump();
    expect(
      findActIndicatorLabel('Acte 4 · Rejeu'),
      findsOneWidget,
      reason: "l'indicateur d'acte doit afficher « Acte 4 · Rejeu »",
    );
    expect(Acte4Harness.position(tester), closeTo(50, 5));
    expect(Acte4Harness.playLabel(tester), contains('Lecture'));
  } finally {
    Acte4Harness.releaseSemantics();
  }
}
