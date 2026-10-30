import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/acte4_harness.dart';
import '../support/keys.dart';
import '../support/session_harness.dart';
import 'la_surface_affiche.dart';
import 'une_session_voix_demarree.dart';

/// Usage: le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
///
/// Session démarrée, plan et activité des trois agents, puis les quatre
/// surfaces de l'acte 1 depuis les exemples du contrat ; l'horloge virtuelle
/// avance de [seconds] entre deux surfaces (le journal en garde les écarts) ;
/// enfin les agents ont terminé (« Lecture » n'est pas bloquée par un agent).
Future<void> leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
  WidgetTester tester,
  num seconds,
) async {
  Acte4Harness.spacing = Acte4Harness.seconds(seconds);
  await uneSessionVoixDemarree(tester);
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(tester, () async {
    SessionHarness.backend.emitGenesisPlan(
      session,
      selected: AcceptanceKeys.act1Agents,
    );
    await SessionHarness.backend.emitGenesisActivity(session, 'working');
  });
  for (final (index, surface) in AcceptanceKeys.act1Surfaces.indexed) {
    if (index > 0) Acte4Harness.clock.advance(Acte4Harness.spacing);
    await SessionHarness.onServer(
      tester,
      () => SessionHarness.backend.emitGenesisSurface(session, surface),
    );
  }
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActivity(session, 'completed'),
  );
  await laSurfaceAffiche(tester, 'kpi', '99,57 %');
  await laSurfaceAffiche(tester, 'trend', 'Taux de crash du jour');
  await laSurfaceAffiche(tester, 'reviews', '24 %');
  await laSurfaceAffiche(tester, 'checklist', 'Checklist go/no-go');
  await settleReal(tester, duration: const Duration(milliseconds: 100));
}
