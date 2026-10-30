import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: deux transports distincts ont été créés
Future<void> deuxTransportsDistinctsOntEteCrees(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => SessionHarness.transports.created.length >= 2,
    timeout: SessionHarness.wait,
    reason: 'le second démarrage doit créer un nouveau transport',
  );
  final created = SessionHarness.transports.created;
  expect(created, hasLength(2));
  expect(identical(created.first, created.last), isFalse);
  // Le premier a été libéré avant la création du second et jamais réutilisé.
  expect(created.first.isReleased, isTrue);
  expect(created.last.calls, isNot(contains('dispose')));
}
