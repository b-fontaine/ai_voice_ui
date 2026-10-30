import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';
import 'la_surface_affiche.dart';
import 'le_serveur_emet_toute_la_session_de_lacte1_du_contrat.dart';
import 'une_session_voix_demarree.dart';

/// Usage: le tableau de la release 3.4 est affiché
///
/// Session démarrée, acte 1 joué depuis les exemples du contrat, quatre
/// surfaces complètes ; relève l'identité de rendu de chacune.
Future<void> leTableauDeLaRelease34EstAffiche(WidgetTester tester) async {
  await uneSessionVoixDemarree(tester);
  await leServeurEmetTouteLaSessionDeLacte1DuContrat(tester);
  await laSurfaceAffiche(tester, 'kpi', '99,57 %');
  await laSurfaceAffiche(tester, 'trend', 'Taux de crash du jour');
  await laSurfaceAffiche(tester, 'reviews', '24 %');
  await laSurfaceAffiche(tester, 'checklist', 'Checklist go/no-go');
  Acte2Harness.capture(tester);
}
