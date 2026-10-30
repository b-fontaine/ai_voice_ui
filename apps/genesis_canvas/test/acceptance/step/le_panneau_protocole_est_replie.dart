import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: le panneau protocole est replié
///
/// Le panneau existe (avec son bouton) mais n'affiche aucune entrée, bien que
/// des messages aient été reçus.
Future<void> lePanneauProtocoleEstReplie(WidgetTester tester) async {
  expect(
    find.byKey(AcceptanceKeys.protocolPanel),
    findsOneWidget,
    reason: 'le panneau protocole (protocol-panel) doit être monté',
  );
  expect(find.byKey(AcceptanceKeys.protocolToggle), findsOneWidget);
  expect(find.byKey(AcceptanceKeys.protocolEntry(0)), findsNothing);
}
