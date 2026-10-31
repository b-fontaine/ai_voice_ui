import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';

/// Usage: la capture du micro n'est pas arrêtée
///
/// Une seule source de capture : couper le micro désactive la piste, il ne
/// libère ni ne rouvre la capture (le faux transport n'a reçu ni `stop` ni
/// `dispose`, et n'a créé qu'une seule offre).
Future<void> laCaptureDuMicroNestPasArretee(WidgetTester tester) async {
  await tester.pump();
  final calls = InterruptionHarness.lastTransport.calls as List<String>;
  expect(
    calls,
    contains('setMicEnabled(false)'),
    reason: 'la piste du micro n\'a jamais été désactivée : $calls',
  );
  expect(
    calls,
    isNot(anyOf(contains('stop'), contains('dispose'))),
    reason: 'la capture a été arrêtée : $calls',
  );
  expect(
    calls.where((c) => c == 'createOfferSdp'),
    hasLength(1),
    reason: 'la capture a été rouverte : $calls',
  );
}
