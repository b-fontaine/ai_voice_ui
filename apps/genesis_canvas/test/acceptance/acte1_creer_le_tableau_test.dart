// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend.dart';
import './step/lapp_est_fermee_et_le_faux_backend_arrete.dart';
import './step/le_canevas_est_vide.dart';
import './step/une_session_voix_demarree.dart';
import './step/le_serveur_emet_la_phrase_du_speaker_et_la_delegation.dart';
import './step/la_ligne_de_la_transcription_affiche.dart';
import './step/le_serveur_emet_le_plan_a_trois_agents_et_leur_activite_au_travail.dart';
import './step/lagent_est_affiche.dart';
import './step/le_serveur_emet_la_creation_des_quatre_surfaces.dart';
import './step/un_squelette_est_visible_pour_chaque_surface.dart';
import './step/le_serveur_emet_les_composants_des_quatre_surfaces.dart';
import './step/aucune_valeur_nest_encore_affichee.dart';
import './step/le_serveur_emet_les_donnees_des_quatre_surfaces.dart';
import './step/la_surface_affiche.dart';

void main() {
  group('''Acte 1 - créer le tableau de release''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackend(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeEtLeFauxBackendArrete(tester);
    }

    testWidgets('''S-01 Acte 1 - créer le tableau de release''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leCanevasEstVide(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetLaPhraseDuSpeakerEtLaDelegation(tester);
        await laLigneDeLaTranscriptionAffiche(
          tester,
          'user',
          'Prépare la release 3.4',
        );
        await leServeurEmetLePlanATroisAgentsEtLeurActiviteAuTravail(tester);
        await lagentEstAffiche(tester, 'Qualité', 'en cours');
        await lagentEstAffiche(tester, 'Voix du client', 'en cours');
        await lagentEstAffiche(tester, 'Livraison', 'en cours');
        await leServeurEmetLaCreationDesQuatreSurfaces(tester);
        await unSqueletteEstVisiblePourChaqueSurface(tester);
        await leServeurEmetLesComposantsDesQuatreSurfaces(tester);
        await aucuneValeurNestEncoreAffichee(tester);
        await leServeurEmetLesDonneesDesQuatreSurfaces(tester);
        await laSurfaceAffiche(tester, 'kpi', '99,57 %');
        await laSurfaceAffiche(tester, 'trend', 'Taux de crash du jour');
        await laSurfaceAffiche(tester, 'reviews', '24 %');
        await laSurfaceAffiche(tester, 'checklist', 'Checklist go/no-go');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['S-01']);
  });
}
