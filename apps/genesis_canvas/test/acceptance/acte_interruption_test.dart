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
import './step/le_serveur_emet_linterruption_a_ms.dart';
import './step/la_piste_distante_est_coupee.dart';
import './step/lorbe_est_a_letat.dart';
import './step/la_ligne_de_la_transcription_naffiche_pas.dart';
import './step/les_surfaces_affichees_sont.dart';
import './step/secondes_secoulent_sans_parole_de_lia.dart';
import './step/la_piste_distante_est_retablie.dart';
import './step/une_session_voix_demarree.dart';
import './step/le_serveur_emet_lagent_qualite_au_travail.dart';
import './step/lagent_est_affiche.dart';
import './step/le_serveur_emet_lannulation_de_lagent_qualite.dart';
import './step/le_bouton_remettre_a_vide_est_actif.dart';
import './step/aucun_message_a2ui_nest_refuse.dart';
import './step/lindicateur_dacte_affiche.dart';
import './step/le_serveur_emet_la_barre_dactions_de_la_fin_de_lacte2.dart';
import './step/la_checklist_gonogo_est_affichee.dart';
import './step/je_clique_sur.dart';
import './step/je_dis.dart';
import './step/je_clique_sur_lindicateur_dacte.dart';
import './step/je_clique_sur_remettre_a_vide.dart';
import './step/la_fenetre_de_lapp_fait_sur_px.dart';
import './step/le_statut_de_la_checklist_passe_a.dart';
import './step/le_statut_de_la_checklist_est_visible_en_entier.dart';
import './step/je_note_le_nombre_de_requetes_daction_recues.dart';
import './step/le_bouton_affiche.dart';
import './step/le_bouton_est_inactif.dart';
import './step/je_clique_sur_le_bouton.dart';
import './step/le_faux_backend_na_recu_aucune_requete_daction_depuis.dart';
import './step/le_bouton_est_actif.dart';

void main() {
  group('''Interruption vocale, indicateur d'acte et retour au clic''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await lesPolicesReellesDeLaSceneSontChargees(tester);
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendAvecUneHorlogeVirtuelle(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeLeFauxBackendArreteEtLaSemantiqueLiberee(tester);
    }

    testWidgets(
      '''K-05 Couper la parole à l'IA coupe la piste distante et tronque la réplique''',
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
          await leServeurEmetLinterruptionAMs(tester, 2500);
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
          await lesSurfacesAfficheesSont(tester, 'kpi,trend,reviews,checklist');
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['S-05', 'FR-13', 'FR-15', 'FR-19'],
    );
    testWidgets(
      '''K-05 Après un silence l'orbe écoute et la piste distante est rétablie''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
          await leServeurEmetLinterruptionAMs(tester, 2500);
          await lorbeEstALetat(tester, 'Interrompue');
          await leServeurEmetUnNiveauDorbeDe(tester, '0');
          await secondesSecoulentSansParoleDeLia(tester, 3);
          await lorbeEstALetat(tester, 'Écoute');
          await laPisteDistanteEstRetablie(tester);
          await lesSurfacesAfficheesSont(tester, 'kpi,trend,reviews,checklist');
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['S-05', 'FR-13', 'FR-19'],
    );
    testWidgets(
      '''K-05 Un agent annulé est montré interrompu et l'app n'est plus occupée''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLagentQualiteAuTravail(tester);
          await lagentEstAffiche(tester, 'Qualité', 'en cours');
          await leServeurEmetLannulationDeLagentQualite(tester);
          await lagentEstAffiche(tester, 'Qualité', 'interrompu');
          await leBoutonRemettreAVideEstActif(tester);
          await aucunMessageA2uiNestRefuse(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['FR-15'],
    );
    testWidgets(
      '''K-06 L'acte 2 s'affiche quand la Barre d'actions apparaît''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await lindicateurDacteAffiche(tester, 'Acte 1/3');
          await leServeurEmetLaBarreDactionsDeLaFinDeLacte2(tester);
          await lindicateurDacteAffiche(tester, 'Acte 2/3');
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['FR-08'],
    );
    testWidgets('''K-06 L'acte 3 s'affiche au clic accepté''', (tester) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await lindicateurDacteAffiche(tester, 'Acte 2/3');
        await jeCliqueSur(tester, 'Bloquer la release');
        await lindicateurDacteAffiche(tester, 'Acte 3/3');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets('''K-06 L'indicateur ne recule jamais tout seul''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await jeCliqueSur(tester, 'Bloquer la release');
        await lindicateurDacteAffiche(tester, 'Acte 3/3');
        await jeDis(tester, 'Concentre-toi sur Android et compare avec la 3.3');
        await lindicateurDacteAffiche(tester, 'Acte 3/3');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets('''K-06 Le clic manuel sur l'indicateur corrige l'acte''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await lindicateurDacteAffiche(tester, 'Acte 2/3');
        await jeCliqueSurLindicateurDacte(tester);
        await lindicateurDacteAffiche(tester, 'Acte 3/3');
        await jeCliqueSurLindicateurDacte(tester);
        await lindicateurDacteAffiche(tester, 'Acte 1/3');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets('''K-06 La remise à vide ramène à l'acte 1''', (tester) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await lindicateurDacteAffiche(tester, 'Acte 2/3');
        await jeCliqueSurRemettreAVide(tester);
        await lindicateurDacteAffiche(tester, 'Acte 1/3');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets('''K-07 Le statut Bloquée est visible en entier''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laFenetreDeLappFaitSurPx(tester, 1366, 768);
        await laChecklistGonogoEstAffichee(tester);
        await jeCliqueSur(tester, 'Bloquer la release');
        await leStatutDeLaChecklistPasseA(tester, 'Bloquée');
        await leStatutDeLaChecklistEstVisibleEnEntier(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets('''K-07 Le bouton passe à fait sans nouvelle requête''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await jeCliqueSur(tester, 'Bloquer la release');
        await leStatutDeLaChecklistPasseA(tester, 'Bloquée');
        await jeNoteLeNombreDeRequetesDactionRecues(tester);
        await leBoutonAffiche(tester, 'block_release', 'fait');
        await leBoutonEstInactif(tester, 'block_release');
        await jeCliqueSurLeBouton(tester, 'block_release');
        await leFauxBackendNaRecuAucuneRequeteDactionDepuis(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets(
      '''K-07 Une demande vocale qui réécrit la checklist réactive le bouton''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await laChecklistGonogoEstAffichee(tester);
          await jeCliqueSur(tester, 'Bloquer la release');
          await leStatutDeLaChecklistPasseA(tester, 'Bloquée');
          await leBoutonEstInactif(tester, 'block_release');
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leBoutonEstActif(tester, 'block_release');
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['FR-08'],
    );
  });
}
