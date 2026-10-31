import 'package:flutter_test/flutter_test.dart';

import '../support/delegation_link_harness.dart';

/// Usage: je note l'image de la liaison de délégation de l'agent {'Qualité'}
Future<void> jeNoteLimageDeLaLiaisonDeDelegationDeLagent(
  WidgetTester tester,
  String agent,
) async {
  DelegationLinkHarness.noted[agent] = await DelegationLinkHarness.capture(
    tester,
    agent,
  );
}
