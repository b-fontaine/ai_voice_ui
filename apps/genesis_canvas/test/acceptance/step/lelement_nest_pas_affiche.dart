import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'action-block_release-dashes'} n'est pas affiché
Future<void> lelementNestPasAffiche(WidgetTester tester, String element) async {
  expect(
    Fidelity.key(element),
    findsNothing,
    reason: "l'élément « $element » ne devrait pas être affiché",
  );
}
