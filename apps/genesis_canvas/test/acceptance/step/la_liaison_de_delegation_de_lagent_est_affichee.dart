import 'package:flutter_test/flutter_test.dart';

import '../support/delegation_link_harness.dart';
import '../support/session_harness.dart';

/// Usage: la liaison de délégation de l'agent {'Qualité'} est affichée
Future<void> laLiaisonDeDelegationDeLagentEstAffichee(
  WidgetTester tester,
  String agent,
) => SessionHarness.waitFor(
  tester,
  DelegationLinkHarness.link(agent),
  "la liaison de délégation de l'agent $agent (delegation-link-$agent) "
  "doit relier l'orchestrateur à sa tuile",
);
