import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: la remise à vide précède la première session
Future<void> laRemiseAVidePrecedeLaPremiereSession(WidgetTester tester) async {
  final events = SessionHarness.backend.events;
  final reset = events.indexOf('canvas reset');
  final first = events.indexOf('relay POST sess-1');
  expect(
    reset,
    isNot(-1),
    reason: 'aucune remise à vide enregistrée : $events',
  );
  expect(first, isNot(-1), reason: 'aucune session enregistrée : $events');
  expect(reset, lessThan(first), reason: 'ordre des requêtes : $events');
}
