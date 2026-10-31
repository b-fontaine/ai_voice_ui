import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/delegation_link_harness.dart';

/// Usage: la liaison de délégation de l'agent {'Qualité'} diffère de l'image notée
Future<void> laLiaisonDeDelegationDeLagentDiffereDeLimageNotee(
  WidgetTester tester,
  String agent,
) async {
  final before = DelegationLinkHarness.noted[agent]!;
  final after = await DelegationLinkHarness.capture(tester, agent);
  expect(
    listEquals(before, after),
    isFalse,
    reason:
        "les pointillés de la liaison de l'agent $agent ne défilent pas "
        'alors que les animations sont actives',
  );
}
