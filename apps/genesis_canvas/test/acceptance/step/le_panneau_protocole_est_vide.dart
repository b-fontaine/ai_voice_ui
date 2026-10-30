import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: le panneau protocole est vide
Future<void> lePanneauProtocoleEstVide(WidgetTester tester) async {
  expect(
    find.byKey(AcceptanceKeys.protocolPanel),
    findsOneWidget,
    reason: 'le panneau protocole (protocol-panel) doit rester monté',
  );
  expect(find.byKey(AcceptanceKeys.protocolEntry(0)), findsNothing);
  expect(find.byKey(AcceptanceKeys.protocolCurrent), findsNothing);
}
