// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend.dart';
import './step/lapp_est_fermee_et_le_faux_backend_arrete.dart';
import './step/une_session_voix_demarree.dart';
import './step/le_serveur_emet_la_phrase.dart';
import './step/le_serveur_emet_un_plan_qui_retient_seulement_lagent.dart';
import './step/le_serveur_emet_lactivite_au_travail_de_lagent.dart';
import './step/lagent_est_affiche.dart';
import './step/le_serveur_emet_un_plan_vide.dart';
import './step/le_rail_affiche.dart';
import './step/le_serveur_emet_la_surface_en_trois_temps.dart';
import './step/le_panneau_protocole_est_replie.dart';
import './step/je_clique_sur_le_bouton_du_panneau_protocole.dart';
import './step/le_panneau_protocole_est_deplie.dart';
import './step/le_message_en_cours_est_mis_en_evidence_dans_le_panneau.dart';
import './step/la_surface_porte_le_contour_pointille.dart';
import './step/la_surface_ne_porte_pas_le_contour_pointille.dart';
import './step/le_serveur_emet_toute_la_session_de_lacte1_du_contrat.dart';
import './step/letagere_affiche.dart';
import './step/le_composant_de_letagere_est.dart';
import './step/le_serveur_emet_la_fixture_refusee.dart';
import './step/le_panneau_protocole_affiche_un_message.dart';
import './step/aucune_surface_nest_affichee.dart';
import './step/la_surface_affiche.dart';
import './step/je_clique_sur_lindicateur_dacte.dart';
import './step/lindicateur_dacte_affiche.dart';
import './step/je_clique_sur_remettre_a_vide.dart';
import './step/le_faux_backend_a_recu_exactement_une_requete_de_remise_a_vide.dart';
import './step/le_canevas_est_vide.dart';
import './step/le_panneau_protocole_est_vide.dart';
import './step/le_rail_ne_contient_plus_aucun_agent_du_plan.dart';
import './step/le_serveur_emet_lindicateur_cle_sans_sa_valeur.dart';
import './step/la_surface_affiche_letat_neutre.dart';
import './step/aucune_erreur_nest_signalee.dart';

void main() {
  group('''Acte 1 - écran de fabrication (rail, panneau, étagère, remise à vide)''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackend(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeEtLeFauxBackendArrete(tester);
    }

    testWidgets(
      '''A1 Un plan à un agent allume cet agent et met les autres en veille''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLaPhrase(tester, 'Montre-moi les avis');
          await leServeurEmetUnPlanQuiRetientSeulementLagent(
            tester,
            'Voix du client',
          );
          await leServeurEmetLactiviteAuTravailDeLagent(
            tester,
            'Voix du client',
          );
          await lagentEstAffiche(tester, 'Voix du client', 'en cours');
          await lagentEstAffiche(tester, 'Qualité', 'en veille');
          await lagentEstAffiche(tester, 'Livraison', 'en veille');
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets('''A1 Un plan vide affiche aucun agent retenu''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetUnPlanVide(tester);
        await leRailAffiche(tester, 'aucun agent retenu');
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets(
      '''A2 Le panneau du protocole est replié par défaut et se déplie au clic''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'kpi');
          await lePanneauProtocoleEstReplie(tester);
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await lePanneauProtocoleEstDeplie(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets(
      '''A2 Le message en cours est relié à sa surface par un contour pointillé''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'kpi');
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'trend');
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await leMessageEnCoursEstMisEnEvidenceDansLePanneau(tester);
          await laSurfacePorteLeContourPointille(tester, 'trend');
          await laSurfaceNePortePasLeContourPointille(tester, 'kpi');
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets('''A2 L'étagère affiche quatre composants utilisés sur six''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetTouteLaSessionDeLacte1DuContrat(tester);
        await letagereAffiche(tester, '4 / 6 utilisés');
        await leComposantDeLetagereEst(tester, 'KeyIndicator', 'utilisé');
        await leComposantDeLetagereEst(tester, 'TrendChart', 'utilisé');
        await leComposantDeLetagereEst(tester, 'ReviewSentiment', 'utilisé');
        await leComposantDeLetagereEst(tester, 'ReleaseChecklist', 'utilisé');
        await leComposantDeLetagereEst(tester, 'ActionBar', 'inutilisé');
        await leComposantDeLetagereEst(tester, 'CrashList', 'inutilisé');
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets(
      '''A3 Un composant hors catalogue est refusé et le flux continue''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await leServeurEmetLaFixtureRefusee(tester, 'component_not_allowed');
          await lePanneauProtocoleAfficheUnMessage(tester, 'refusé');
          await aucuneSurfaceNestAffichee(tester);
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'kpi');
          await laSurfaceAffiche(tester, 'kpi', '99,57 %');
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets(
      '''A4 La remise à vide efface l'acte 1 et le panneau reste vide''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetTouteLaSessionDeLacte1DuContrat(tester);
          await lagentEstAffiche(tester, 'Livraison', 'terminé');
          await letagereAffiche(tester, '4 / 6 utilisés');
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await jeCliqueSurLindicateurDacte(tester);
          await lindicateurDacteAffiche(tester, 'Acte 2/3');
          await jeCliqueSurRemettreAVide(tester);
          await leFauxBackendARecuExactementUneRequeteDeRemiseAVide(tester);
          await leCanevasEstVide(tester);
          await aucuneSurfaceNestAffichee(tester);
          await lePanneauProtocoleEstVide(tester);
          await letagereAffiche(tester, '0 / 6 utilisés');
          await leRailNeContientPlusAucunAgentDuPlan(tester);
          await lindicateurDacteAffiche(tester, 'Acte 1/3');
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets(
      '''A5 Des données incomplètes donnent l'état neutre sans casser la démo''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLindicateurCleSansSaValeur(tester);
          await laSurfaceAfficheLetatNeutre(
            tester,
            'kpi',
            'Données indisponibles',
          );
          await aucuneErreurNestSignalee(tester);
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'trend');
          await laSurfaceAffiche(tester, 'trend', 'Taux de crash du jour');
        } finally {
          await bddTearDown(tester);
        }
      },
    );
  });
}
