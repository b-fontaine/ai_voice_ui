import 'package:flutter_test/flutter_test.dart';

import '../support/delegation_link_harness.dart';

/// Usage: la liaison de délégation de l'agent {'Qualité'} n'est plus affichée
Future<void> laLiaisonDeDelegationDeLagentNestPlusAffichee(
  WidgetTester tester,
  String agent,
) => DelegationLinkHarness.expectLinkAbsentSoon(tester, agent);
