import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';

/// Usage: aucun message A2UI n'est refusé
///
/// Le validateur de la page (instance unique, jamais remise à zéro à un
/// changement de session) écrit « Message A2UI refusé : <code> » à chaque refus.
Future<void> aucunMessageA2uiNestRefuse(WidgetTester tester) async {
  final errors = Acte2Harness.errors.toString();
  expect(
    errors.contains('refusé'),
    isFalse,
    reason: "le validateur A2UI a refusé un message de l'acte 2 : $errors",
  );
}
