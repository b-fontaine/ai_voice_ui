// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/les_polices_reelles_de_la_scene_sont_chargees.dart';
import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_avec_une_horloge_virtuelle.dart';
import './step/lapp_est_fermee_le_faux_backend_arrete_et_la_semantique_liberee.dart';
import './step/le_tableau_de_la_release34_est_affiche.dart';
import './step/le_serveur_emet_une_replique_de_lia_commencee_a_ms.dart';
import './step/la_ligne_de_la_transcription_affiche.dart';
import './step/le_serveur_emet_un_niveau_dorbe_de.dart';
import './step/lorbe_est_a_letat.dart';
import './step/le_serveur_emet_linterruption_de_cause_overlap_a_ms.dart';
import './step/la_piste_distante_est_coupee.dart';
import './step/la_ligne_de_la_transcription_naffiche_pas.dart';
import './step/les_surfaces_affichees_sont.dart';
import './step/le_serveur_emet_la_delegation_de_la_correction_a_ms.dart';
import './step/la_piste_distante_est_retablie.dart';
import './step/secondes_secoulent_sans_parole_de_lia.dart';
import './step/une_session_voix_demarree.dart';
import './step/le_serveur_emet_le_plan_a_trois_agents.dart';
import './step/le_serveur_emet_lactivite_au_travail_de_lagent.dart';
import './step/lagent_est_affiche.dart';
import './step/la_liaison_de_delegation_de_lagent_est_affichee.dart';
import './step/le_serveur_emet_letat_de_lagent.dart';
import './step/la_liaison_de_delegation_de_lagent_nest_plus_affichee.dart';
import './step/le_serveur_emet_lannulation_de_lagent_qualite.dart';
import './step/le_serveur_emet_un_plan_vide.dart';
import './step/le_rail_affiche.dart';
import './step/aucune_liaison_de_delegation_nest_affichee.dart';
import './step/les_animations_du_systeme_sont_desactivees.dart';
import './step/je_note_limage_de_la_liaison_de_delegation_de_lagent.dart';
import './step/millisecondes_secoulent.dart';
import './step/la_liaison_de_delegation_de_lagent_est_identique_a_limage_notee.dart';
import './step/la_liaison_de_delegation_de_lagent_differe_de_limage_notee.dart';
import './step/le_serveur_emet_le_plan_a_trois_agents_et_leur_activite_au_travail.dart';
import './step/le_serveur_emet_la_surface_en_trois_temps.dart';
import './step/le_serveur_emet_la_fin_de_lactivite_des_trois_agents.dart';
import './step/je_clique_sur_lecture.dart';
import './step/le_rejeu_avance_de_secondes.dart';

void main() {
  group(
    '''Couper la parole à l'IA en parlant, et liaison animée de délégation''',
    () {
      Future<void> bddSetUp(WidgetTester tester) async {
        await lesPolicesReellesDeLaSceneSontChargees(tester);
        await unFauxBackendLocal(tester);
        await lappLanceeSurCeBackendAvecUneHorlogeVirtuelle(tester);
      }

      Future<void> bddTearDown(WidgetTester tester) async {
        await lappEstFermeeLeFauxBackendArreteEtLaSemantiqueLiberee(tester);
      }

      testWidgets(
        '''S-05 Couper la parole à l'IA sans mot d'arrêt coupe la piste distante et tronque la réplique''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await leTableauDeLaRelease34EstAffiche(tester);
            await leServeurEmetUneRepliqueDeLiaCommenceeAMs(
              tester,
              'Le tableau Android est prêt',
              2000,
            );
            await laLigneDeLaTranscriptionAffiche(
              tester,
              'ai',
              'Le tableau Android est prêt',
            );
            await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
            await lorbeEstALetat(tester, 'parole');
            await leServeurEmetLinterruptionDeCauseOverlapAMs(tester, 2500);
            await laPisteDistanteEstCoupee(tester);
            await lorbeEstALetat(tester, 'Interrompue');
            await leServeurEmetUneRepliqueDeLiaCommenceeAMs(
              tester,
              ' et la décision attend',
              3000,
            );
            await laLigneDeLaTranscriptionNaffichePas(
              tester,
              'ai',
              'la décision attend',
            );
            await lesSurfacesAfficheesSont(
              tester,
              'kpi,trend,reviews,checklist',
            );
            await leServeurEmetUnNiveauDorbeDe(tester, '0');
            await leServeurEmetLaDelegationDeLaCorrectionAMs(tester, 4000);
            await lorbeEstALetat(tester, 'Écoute');
            await laPisteDistanteEstRetablie(tester);
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['S-05', 'FR-13', 'FR-15', 'FR-19'],
      );
      testWidgets(
        '''S-05 Pendant le chevauchement la demande du speaker rend la parole à l'IA''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await leTableauDeLaRelease34EstAffiche(tester);
            await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
            await leServeurEmetLinterruptionDeCauseOverlapAMs(tester, 2500);
            await lorbeEstALetat(tester, 'Interrompue');
            await laPisteDistanteEstCoupee(tester);
            await leServeurEmetUnNiveauDorbeDe(tester, '0');
            await leServeurEmetLaDelegationDeLaCorrectionAMs(tester, 4000);
            await lorbeEstALetat(tester, 'Écoute');
            await laPisteDistanteEstRetablie(tester);
            await lesSurfacesAfficheesSont(
              tester,
              'kpi,trend,reviews,checklist',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['S-05', 'FR-13', 'FR-19'],
      );
      testWidgets(
        '''S-05 bis La délégation du speaker arrive avant l'interruption de cause overlap''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await leTableauDeLaRelease34EstAffiche(tester);
            await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
            await leServeurEmetLaDelegationDeLaCorrectionAMs(tester, 4000);
            await leServeurEmetLinterruptionDeCauseOverlapAMs(tester, 2500);
            await lorbeEstALetat(tester, 'Écoute');
            await laPisteDistanteEstRetablie(tester);
            await lesSurfacesAfficheesSont(
              tester,
              'kpi,trend,reviews,checklist',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['S-05', 'FR-13', 'FR-19'],
      );
      testWidgets(
        '''O-01 Sans délégation, le silence de reprise rend l'écoute et la piste''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await leTableauDeLaRelease34EstAffiche(tester);
            await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
            await leServeurEmetLinterruptionDeCauseOverlapAMs(tester, 2500);
            await lorbeEstALetat(tester, 'Interrompue');
            await leServeurEmetUnNiveauDorbeDe(tester, '0');
            await secondesSecoulentSansParoleDeLia(tester, 3);
            await lorbeEstALetat(tester, 'Écoute');
            await laPisteDistanteEstRetablie(tester);
            await lesSurfacesAfficheesSont(
              tester,
              'kpi,trend,reviews,checklist',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['S-05', 'FR-13', 'FR-19'],
      );
      testWidgets(
        '''O-01 Une délégation antérieure à l'interruption ne met pas fin à l'interruption''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await leTableauDeLaRelease34EstAffiche(tester);
            await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
            await leServeurEmetLaDelegationDeLaCorrectionAMs(tester, 1000);
            await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
            await leServeurEmetLinterruptionDeCauseOverlapAMs(tester, 2500);
            await lorbeEstALetat(tester, 'Interrompue');
            await laPisteDistanteEstCoupee(tester);
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['S-05', 'FR-13', 'FR-19'],
      );
      testWidgets(
        '''O-01 Reçue alors que l'orbe écoute déjà, l'interruption rend aussitôt l'écoute et la piste''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await leTableauDeLaRelease34EstAffiche(tester);
            await lorbeEstALetat(tester, 'Écoute');
            await leServeurEmetLinterruptionDeCauseOverlapAMs(tester, 2500);
            await lorbeEstALetat(tester, 'Écoute');
            await laPisteDistanteEstRetablie(tester);
            await lesSurfacesAfficheesSont(
              tester,
              'kpi,trend,reviews,checklist',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['S-05', 'FR-13', 'FR-19'],
      );
      testWidgets(
        '''L-01 Une liaison relie l'orchestrateur à chaque agent en attente ou en cours''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await uneSessionVoixDemarree(tester);
            await leServeurEmetLePlanATroisAgents(tester);
            await leServeurEmetLactiviteAuTravailDeLagent(tester, 'Qualité');
            await leServeurEmetLactiviteAuTravailDeLagent(
              tester,
              'Voix du client',
            );
            await lagentEstAffiche(tester, 'Qualité', 'en cours');
            await lagentEstAffiche(tester, 'Voix du client', 'en cours');
            await lagentEstAffiche(tester, 'Livraison', 'en attente');
            await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
            await laLiaisonDeDelegationDeLagentEstAffichee(
              tester,
              'Voix du client',
            );
            await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Livraison');
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['FR-03', 'NFR-04'],
      );
      testWidgets('''L-02 La liaison disparaît quand l'agent est terminé''', (
        tester,
      ) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLePlanATroisAgents(tester);
          await leServeurEmetLactiviteAuTravailDeLagent(tester, 'Qualité');
          await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
          await leServeurEmetLetatDeLagent(tester, 'terminé', 'Qualité');
          await lagentEstAffiche(tester, 'Qualité', 'terminé');
          await laLiaisonDeDelegationDeLagentNestPlusAffichee(
            tester,
            'Qualité',
          );
          await laLiaisonDeDelegationDeLagentEstAffichee(
            tester,
            'Voix du client',
          );
        } finally {
          await bddTearDown(tester);
        }
      }, tags: ['FR-03', 'NFR-04']);
      testWidgets('''L-02 La liaison disparaît quand l'agent est en échec''', (
        tester,
      ) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLePlanATroisAgents(tester);
          await leServeurEmetLactiviteAuTravailDeLagent(tester, 'Qualité');
          await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
          await leServeurEmetLetatDeLagent(tester, 'échec', 'Qualité');
          await lagentEstAffiche(tester, 'Qualité', 'échec');
          await laLiaisonDeDelegationDeLagentNestPlusAffichee(
            tester,
            'Qualité',
          );
          await laLiaisonDeDelegationDeLagentEstAffichee(
            tester,
            'Voix du client',
          );
        } finally {
          await bddTearDown(tester);
        }
      }, tags: ['FR-03', 'NFR-04']);
      testWidgets(
        '''L-02 La liaison disparaît quand l'agent est hors périmètre''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await uneSessionVoixDemarree(tester);
            await leServeurEmetLePlanATroisAgents(tester);
            await leServeurEmetLactiviteAuTravailDeLagent(tester, 'Qualité');
            await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
            await leServeurEmetLetatDeLagent(
              tester,
              'hors périmètre',
              'Qualité',
            );
            await lagentEstAffiche(tester, 'Qualité', 'hors périmètre');
            await laLiaisonDeDelegationDeLagentNestPlusAffichee(
              tester,
              'Qualité',
            );
            await laLiaisonDeDelegationDeLagentEstAffichee(
              tester,
              'Voix du client',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['FR-03', 'NFR-04'],
      );
      testWidgets(
        '''L-02 La liaison disparaît quand l'agent est interrompu''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await uneSessionVoixDemarree(tester);
            await leServeurEmetLePlanATroisAgents(tester);
            await leServeurEmetLactiviteAuTravailDeLagent(tester, 'Qualité');
            await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
            await leServeurEmetLannulationDeLagentQualite(tester);
            await lagentEstAffiche(tester, 'Qualité', 'interrompu');
            await laLiaisonDeDelegationDeLagentNestPlusAffichee(
              tester,
              'Qualité',
            );
            await laLiaisonDeDelegationDeLagentEstAffichee(
              tester,
              'Voix du client',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['FR-03', 'NFR-04'],
      );
      testWidgets('''L-02 Aucun agent retenu, aucune liaison''', (
        tester,
      ) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLePlanATroisAgents(tester);
          await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
          await leServeurEmetUnPlanVide(tester);
          await leRailAffiche(tester, 'aucun agent retenu');
          await aucuneLiaisonDeDelegationNestAffichee(tester);
        } finally {
          await bddTearDown(tester);
        }
      }, tags: ['FR-03', 'NFR-04']);
      testWidgets(
        '''L-03 Animations du système coupées, la liaison reste et ne bouge plus''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await uneSessionVoixDemarree(tester);
            await lesAnimationsDuSystemeSontDesactivees(tester);
            await leServeurEmetLePlanATroisAgents(tester);
            await leServeurEmetLactiviteAuTravailDeLagent(tester, 'Qualité');
            await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
            await jeNoteLimageDeLaLiaisonDeDelegationDeLagent(
              tester,
              'Qualité',
            );
            await millisecondesSecoulent(tester, 130);
            await laLiaisonDeDelegationDeLagentEstIdentiqueALimageNotee(
              tester,
              'Qualité',
            );
            await millisecondesSecoulent(tester, 130);
            await laLiaisonDeDelegationDeLagentEstIdentiqueALimageNotee(
              tester,
              'Qualité',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['FR-03', 'NFR-04'],
      );
      testWidgets(
        '''L-03 Témoin, animations actives, les pointillés défilent''',
        (tester) async {
          try {
            await bddSetUp(tester);
            await uneSessionVoixDemarree(tester);
            await leServeurEmetLePlanATroisAgents(tester);
            await leServeurEmetLactiviteAuTravailDeLagent(tester, 'Qualité');
            await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
            await jeNoteLimageDeLaLiaisonDeDelegationDeLagent(
              tester,
              'Qualité',
            );
            await millisecondesSecoulent(tester, 130);
            await laLiaisonDeDelegationDeLagentDiffereDeLimageNotee(
              tester,
              'Qualité',
            );
          } finally {
            await bddTearDown(tester);
          }
        },
        tags: ['FR-03', 'NFR-04'],
      );
      testWidgets('''L-04 Pendant le rejeu, aucune liaison n'est affichée''', (
        tester,
      ) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLePlanATroisAgentsEtLeurActiviteAuTravail(tester);
          await laLiaisonDeDelegationDeLagentEstAffichee(tester, 'Qualité');
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'kpi');
          await leServeurEmetLaFinDeLactiviteDesTroisAgents(tester);
          await laLiaisonDeDelegationDeLagentNestPlusAffichee(
            tester,
            'Qualité',
          );
          await jeCliqueSurLecture(tester);
          await leRejeuAvanceDeSecondes(tester, 1.5);
          await aucuneLiaisonDeDelegationNestAffichee(tester);
        } finally {
          await bddTearDown(tester);
        }
      }, tags: ['FR-03', 'FR-09']);
    },
  );
}
