import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/delegation_link_harness.dart';

/// Usage: la liaison de délégation de l'agent {'Qualité'} est identique à l'image notée
Future<void> laLiaisonDeDelegationDeLagentEstIdentiqueALimageNotee(
  WidgetTester tester,
  String agent,
) async {
  final before = DelegationLinkHarness.noted[agent]!;
  final after = await DelegationLinkHarness.capture(tester, agent);
  expect(
    listEquals(before, after),
    isTrue,
    reason:
        "la liaison de l'agent $agent a bougé alors que les animations sont "
        'coupées : elle doit rester fixe',
  );
}
