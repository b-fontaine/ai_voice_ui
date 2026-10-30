import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: le serveur émet la Barre d'actions jusqu'au temps {'components'}
///
/// Temps : `skeleton` (createSurface), `components` (updateComponents) ou
/// `data` (updateDataModel). Les temps déjà émis ne sont pas renvoyés.
Future<void> leServeurEmetLaBarreDactionsJusquauTemps(
  WidgetTester tester,
  String stage,
) async {
  final upTo = SurfaceStage.values.firstWhere(
    (s) => s.name == stage,
    orElse: () => fail('temps de surface inconnu : $stage'),
  );
  final from = SurfaceStage.values[Acte3Harness.actionsStagesEmitted];
  Acte3Harness.actionsStagesEmitted = upTo.index + 1;
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActions(
      session,
      from: from,
      upTo: upTo,
    ),
  );
}
