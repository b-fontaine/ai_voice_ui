import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: aucune animation en boucle n'est active, orbe et squelette compris
///
/// À appeler après « les animations du système sont désactivées ». Après deux
/// images, aucun `Ticker` n'est actif (`transientCallbackCount`), aucune
/// image n'est demandée et `pumpAndSettle` converge.
Future<void> aucuneAnimationEnBoucleNestActiveOrbeEtSqueletteCompris(
  WidgetTester tester,
) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.binding.transientCallbackCount,
    0,
    reason: 'des Ticker restent actifs : une animation tourne en boucle',
  );
  expect(
    tester.binding.hasScheduledFrame,
    isFalse,
    reason: 'une image est encore demandée : une animation tourne en boucle',
  );
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } on FlutterError catch (error) {
    fail('pumpAndSettle ne converge pas : ${error.message}');
  }
}
