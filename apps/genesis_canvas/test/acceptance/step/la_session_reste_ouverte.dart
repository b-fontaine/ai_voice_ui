import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: la session reste ouverte
///
/// Le bouton Arrêter est toujours là et le transport n'a été ni arrêté ni
/// libéré : ni faire taire ni couper le micro ne ferment la session.
Future<void> laSessionResteOuverte(WidgetTester tester) async {
  await tester.pump();
  expect(
    find.byKey(SessionHarness.stopKey),
    findsOneWidget,
    reason: 'la session n\'est plus active (bouton Arrêter absent)',
  );
  final calls = InterruptionHarness.lastTransport.calls as List<String>;
  expect(
    calls,
    isNot(anyOf(contains('stop'), contains('dispose'))),
    reason: 'le transport a été fermé : $calls',
  );
}
