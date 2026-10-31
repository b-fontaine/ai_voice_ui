import 'package:flutter_test/flutter_test.dart';

import '../support/delegation_link_harness.dart';

/// Usage: aucune liaison de délégation n'est affichée
Future<void> aucuneLiaisonDeDelegationNestAffichee(WidgetTester tester) async {
  await tester.pump();
  expect(
    DelegationLinkHarness.anyLink,
    findsNothing,
    reason: 'aucune liaison delegation-link-<agent> ne doit être affichée',
  );
}
