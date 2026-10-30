import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'acte 2 de la surface {'reviews'} sans le champ {'value'} de la comparaison
///
/// Le même `updateDataModel` que l'exemple du contrat, avec un `comparison`
/// incomplet (RG-10, D7).
Future<void> leServeurEmetLacte2DeLaSurfaceSansLeChampDeLaComparaison(
  WidgetTester tester,
  String surface,
  String field,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(tester, () async {
    final surfaces = await ContractFixtures.followUpSurfaces(
      GenesisFollowUp.act2,
      catalogId: SessionHarness.backend.catalogId,
    );
    final target = surfaces.firstWhere((s) => s.surfaceId == surface);
    final message = Map<String, Object?>.from(target.messages.single);
    final update = Map<String, Object?>.from(
      message['updateDataModel']! as Map,
    );
    final value = Map<String, Object?>.from(update['value']! as Map);
    final comparison = Map<String, Object?>.from(value['comparison']! as Map)
      ..remove(field);
    value['comparison'] = comparison;
    update['value'] = value;
    message['updateDataModel'] = update;
    SessionHarness.backend.emit(
      session,
      'a2ui',
      message,
      agent: target.agent,
      task: target.task,
    );
  });
}
