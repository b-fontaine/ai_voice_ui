import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'indicateur clé sans sa valeur
///
/// Les trois temps de `kpi`, mais le champ requis `value` est retiré de
/// l'objet lié (RG-10) : l'état neutre doit s'afficher.
Future<void> leServeurEmetLindicateurCleSansSaValeur(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(tester, () async {
    final surfaces = await ContractFixtures.act1Surfaces(
      catalogId: SessionHarness.backend.catalogId,
    );
    final kpi = surfaces.firstWhere((s) => s.surfaceId == 'kpi');
    for (final original in kpi.messages) {
      final message = Map<String, Object?>.from(original);
      final data = message['updateDataModel'];
      if (data is Map) {
        final copy = Map<String, Object?>.from(data);
        final value = Map<String, Object?>.from(copy['value']! as Map)
          ..remove('value');
        copy['value'] = value;
        message['updateDataModel'] = copy;
      }
      SessionHarness.backend.emit(
        session,
        'a2ui',
        message,
        agent: kpi.agent,
        task: kpi.task,
      );
    }
  });
}
