import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'reviews-card-0-meta'} est à gauche de l'élément {'reviews-card-0-text'}
Future<void> lelementEstAGaucheDeLelement(
  WidgetTester tester,
  String first,
  String second,
) async {
  expect(
    Fidelity.rect(tester, first).right,
    lessThanOrEqualTo(Fidelity.rect(tester, second).left + 0.5),
    reason: "« $first » doit être à gauche de « $second »",
  );
}
