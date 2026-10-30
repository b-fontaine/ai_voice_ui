import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/keys.dart';

/// Usage: le statut de la checklist ne passe pas à {'Bloquée'}
Future<void> leStatutDeLaChecklistNePassePasA(
  WidgetTester tester,
  String status,
) async {
  await settleReal(tester);
  expect(
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface('checklist')),
      matching: find.text(status),
    ),
    findsNothing,
    reason: 'la checklist affiche « $status » alors que rien ne le justifie',
  );
}
