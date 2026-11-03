import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// Usage: le serveur émet l'indicateur clé avec la valeur {'n/d'}
Future<void> leServeurEmetLindicateurCleAvecLaValeur(
  WidgetTester tester,
  String value,
) async {
  final String session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(tester, () async {
    final surfaces = await ContractFixtures.act1Surfaces(
      catalogId: SessionHarness.backend.catalogId,
    );
    final kpi = surfaces.firstWhere((s) => s.surfaceId == 'kpi');
    final Map<String, Object?> message = Map<String, Object?>.from(
      kpi.messages.firstWhere((m) => m.containsKey('updateDataModel')),
    );
    final Map<String, Object?> update = Map<String, Object?>.from(
      message['updateDataModel']! as Map,
    );
    update['value'] = <String, Object?>{
      ...Map<String, Object?>.from(update['value']! as Map),
      'value': value,
    };
    message['updateDataModel'] = update;
    SessionHarness.backend.emit(
      session,
      'a2ui',
      message,
      agent: kpi.agent,
      task: kpi.task,
    );
  });
}
