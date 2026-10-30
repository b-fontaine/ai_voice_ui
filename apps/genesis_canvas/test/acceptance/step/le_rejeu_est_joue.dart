import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';

/// Usage: le rejeu est joué
///
/// Le rejeu s'enchaîne sans attente (frontière « temps ») ; un temps réel
/// laisse ensuite passer toute requête réseau tardive.
Future<void> leRejeuEstJoue(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );
  await settleReal(tester, duration: const Duration(milliseconds: 500));
}
