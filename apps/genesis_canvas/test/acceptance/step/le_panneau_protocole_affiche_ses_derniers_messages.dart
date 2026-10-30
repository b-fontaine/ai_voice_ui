import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le panneau protocole affiche ses derniers messages
///
/// Déplié, le panneau ne montre que les plus récents (pas `protocol-entry-0`) :
/// on attend le message en cours, mis en évidence.
Future<void> lePanneauProtocoleAfficheSesDerniersMessages(
  WidgetTester tester,
) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.protocolPanel),
      matching: find.byKey(AcceptanceKeys.protocolCurrent),
    ),
    'déplié, le panneau doit mettre un message en évidence (protocol-current)',
  );
}
