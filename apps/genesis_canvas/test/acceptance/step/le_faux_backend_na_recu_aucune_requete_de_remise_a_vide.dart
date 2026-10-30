import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le faux backend n'a reçu aucune requête de remise à vide
Future<void> leFauxBackendNaRecuAucuneRequeteDeRemiseAVide(
  WidgetTester tester,
) async {
  expect(
    SessionHarness.backend.canvasResets,
    0,
    reason: 'le mode rejeu ne doit pas appeler POST /canvas/reset',
  );
}
