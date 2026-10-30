// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_avec_une_horloge_virtuelle.dart';
import './step/lapp_est_fermee_le_faux_backend_arrete_et_la_semantique_liberee.dart';
import './step/le_tableau_de_la_release34_est_joue_en_direct_une_surface_toutes_les_secondes.dart';
import './step/je_clique_sur_le_bouton_du_panneau_protocole.dart';
import './step/le_panneau_protocole_affiche_ses_derniers_messages.dart';
import './step/je_note_le_rendu_affiche.dart';
import './step/je_note_le_nombre_de_requetes_recues_par_le_faux_backend.dart';
import './step/je_clique_sur_lecture.dart';
import './step/la_surface_nest_pas_encore_affichee.dart';
import './step/lindicateur_dacte_affiche.dart';
import './step/je_choisis_la_vitesse.dart';
import './step/jattends_la_fin_du_rejeu.dart';
import './step/le_rendu_affiche_est_identique_a_celui_note.dart';
import './step/le_faux_backend_na_recu_aucune_requete_depuis.dart';
import './step/aucun_message_a2ui_nest_refuse.dart';
import './step/la_seconde_duree_mesuree_vaut_fois_la_premiere.dart';
import './step/le_rejeu_avance_de_secondes.dart';
import './step/je_note_la_position_du_curseur.dart';
import './step/la_position_du_curseur_na_pas_bouge_de_plus_de_points.dart';
import './step/le_bouton_de_lecture_affiche.dart';
import './step/la_position_du_curseur_a_avance_de_points_a_points_pres.dart';
import './step/je_clique_sur_pause.dart';
import './step/je_place_le_curseur_au_milieu.dart';
import './step/les_surfaces_affichees_sont.dart';
import './step/le_panneau_protocole_compte_messages.dart';
import './step/je_pose_le_doigt_au_milieu_du_curseur.dart';
import './step/je_glisse_le_doigt_vers_le_debut_du_curseur.dart';
import './step/je_relache_le_doigt.dart';
import './step/le_rejeu_est_termine.dart';
import './step/le_curseur_est_a_environ_a_points_pres.dart';
import './step/je_clique_sur_recommencer.dart';
import './step/la_barre_dactions_est_jouee_en_direct.dart';
import './step/les_boutons_de_la_barre_dactions_sont_actifs.dart';
import './step/les_boutons_de_la_barre_dactions_sont_inactifs.dart';
import './step/le_serveur_emet_un_message_a2ui_vivant.dart';
import './step/une_session_voix_est_active.dart';
import './step/un_seul_transport_a_ete_cree.dart';
import './step/le_relais_na_recu_aucun_delete.dart';
import './step/je_clique_sur_arreter.dart';
import './step/le_bouton_demarrer_est_affiche.dart';
import './step/le_bouton_demarrer_est_inactif.dart';
import './step/je_clique_sur_direct.dart';
import './step/aucune_surface_nest_affichee.dart';
import './step/le_panneau_protocole_est_vide.dart';
import './step/letagere_affiche.dart';
import './step/le_faux_backend_a_recu_exactement_une_requete_de_remise_a_vide.dart';
import './step/lindicateur_dacte_naffiche_plus.dart';
import './step/le_bouton_lecture_est_inactif.dart';
import './step/une_session_voix_demarree.dart';
import './step/le_serveur_emet_le_plan_a_trois_agents_et_leur_activite_au_travail.dart';
import './step/le_serveur_emet_la_surface_en_trois_temps.dart';
import './step/le_serveur_emet_la_fin_de_lactivite_des_trois_agents.dart';
import './step/le_bouton_lecture_est_actif.dart';
import './step/secondes_secoulent_sur_lhorloge_de_lapp.dart';
import './step/le_rejeu_nest_pas_termine.dart';
import './step/je_clique_sur_remettre_a_vide.dart';
import './step/la_page_est_demontee_pendant_la_lecture.dart';
import './step/aucun_minuteur_nest_reste_actif.dart';

void main() {
  group('''Acte 4 - rejouer la construction du tableau''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendAvecUneHorlogeVirtuelle(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeLeFauxBackendArreteEtLaSemantiqueLiberee(tester);
    }

    testWidgets(
      '''R-01 Le rejeu est identique au direct, sans aucune requête''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await lePanneauProtocoleAfficheSesDerniersMessages(tester);
          await jeNoteLeRenduAffiche(tester);
          await jeNoteLeNombreDeRequetesRecuesParLeFauxBackend(tester);
          await jeCliqueSurLecture(tester);
          await laSurfaceNestPasEncoreAffichee(tester, 'checklist');
          await lindicateurDacteAffiche(tester, 'Acte 4 · Rejeu');
          await jeChoisisLaVitesse(tester, 2);
          await jattendsLaFinDuRejeu(tester);
          await leRenduAfficheEstIdentiqueACeluiNote(tester);
          await leFauxBackendNaRecuAucuneRequeteDepuis(tester);
          await aucunMessageA2uiNestRefuse(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['R-01', 'FR-09', 'NFR-08'],
    );
    testWidgets('''R-02 La durée du rejeu est proportionnelle à 1/vitesse''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
          tester,
          2,
        );
        await jeCliqueSurLecture(tester);
        await jeChoisisLaVitesse(tester, 2);
        await jattendsLaFinDuRejeu(tester);
        await jeCliqueSurLecture(tester);
        await jeChoisisLaVitesse(tester, 0.25);
        await jattendsLaFinDuRejeu(tester);
        await laSecondeDureeMesureeVautFoisLaPremiere(tester, 8);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['R-02', 'FR-09']);
    testWidgets(
      '''R-02 Changer de vitesse en cours de lecture n'interrompt ni ne saute''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await jeCliqueSurLecture(tester);
          await leRejeuAvanceDeSecondes(tester, 2);
          await jeNoteLaPositionDuCurseur(tester);
          await jeChoisisLaVitesse(tester, 2);
          await laPositionDuCurseurNaPasBougeDePlusDePoints(tester, 5);
          await leBoutonDeLectureAffiche(tester, 'Pause');
          await leRejeuAvanceDeSecondes(tester, 1);
          await laPositionDuCurseurAAvanceDePointsAPointsPres(tester, 33, 5);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['R-02', 'FR-09'],
    );
    testWidgets(
      '''R-03 Le curseur avant puis arrière laisse les surfaces et le panneau de ce point''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await jeCliqueSurLecture(tester);
          await jeCliqueSurPause(tester);
          await jePlaceLeCurseurAuMilieu(tester);
          await lesSurfacesAfficheesSont(tester, 'kpi,trend');
          await lePanneauProtocoleCompteMessages(tester, 6);
          await jeNoteLeRenduAffiche(tester);
          await jeCliqueSurLecture(tester);
          await leRejeuAvanceDeSecondes(tester, 2);
          await lesSurfacesAfficheesSont(tester, 'kpi,trend,reviews');
          await jeCliqueSurPause(tester);
          await jePlaceLeCurseurAuMilieu(tester);
          await lesSurfacesAfficheesSont(tester, 'kpi,trend');
          await lePanneauProtocoleCompteMessages(tester, 6);
          await leRenduAfficheEstIdentiqueACeluiNote(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['R-03', 'FR-09'],
    );
    testWidgets(
      '''R-03 Glisser le curseur ne déclenche qu'un seul seek, au relâchement''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await jeCliqueSurLecture(tester);
          await leRejeuAvanceDeSecondes(tester, 2.5);
          await jeCliqueSurPause(tester);
          await jeNoteLeRenduAffiche(tester);
          await jePoseLeDoigtAuMilieuDuCurseur(tester);
          await jeGlisseLeDoigtVersLeDebutDuCurseur(tester);
          await leRenduAfficheEstIdentiqueACeluiNote(tester);
          await jeRelacheLeDoigt(tester);
          await lesSurfacesAfficheesSont(tester, 'kpi');
          await lePanneauProtocoleCompteMessages(tester, 3);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['R-03', 'FR-09'],
    );
    testWidgets('''R-04 Pause, reprise et fin du rejeu''', (tester) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
          tester,
          2,
        );
        await jeCliqueSurLecture(tester);
        await leRejeuAvanceDeSecondes(tester, 2.5);
        await jeCliqueSurPause(tester);
        await jeNoteLeRenduAffiche(tester);
        await leRejeuAvanceDeSecondes(tester, 5);
        await leRenduAfficheEstIdentiqueACeluiNote(tester);
        await leBoutonDeLectureAffiche(tester, 'Lecture');
        await jeCliqueSurLecture(tester);
        await leRejeuAvanceDeSecondes(tester, 5);
        await leRejeuEstTermine(tester);
        await lesSurfacesAfficheesSont(tester, 'kpi,trend,reviews,checklist');
        await leBoutonDeLectureAffiche(tester, 'Lecture');
        await jeCliqueSurLecture(tester);
        await leRejeuAvanceDeSecondes(tester, 0.3);
        await leCurseurEstAEnvironAPointsPres(tester, 5, 5);
        await laSurfaceNestPasEncoreAffichee(tester, 'checklist');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['R-04', 'FR-09']);
    testWidgets('''R-04 Recommencer repart du début''', (tester) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
          tester,
          2,
        );
        await jeCliqueSurLecture(tester);
        await leRejeuAvanceDeSecondes(tester, 4.5);
        await lesSurfacesAfficheesSont(tester, 'kpi,trend,reviews');
        await jeCliqueSurRecommencer(tester);
        await leCurseurEstAEnvironAPointsPres(tester, 0, 5);
        await laSurfaceNestPasEncoreAffichee(tester, 'reviews');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['R-04', 'FR-09']);
    testWidgets(
      '''R-05 Pendant le rejeu, un message vivant est écarté et la voix n'est pas touchée''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await laBarreDactionsEstJoueeEnDirect(tester);
          await lesBoutonsDeLaBarreDactionsSontActifs(tester);
          await jeCliqueSurLecture(tester);
          await jattendsLaFinDuRejeu(tester);
          await lesBoutonsDeLaBarreDactionsSontInactifs(tester);
          await lePanneauProtocoleCompteMessages(tester, 15);
          await leServeurEmetUnMessageA2uiVivant(tester);
          await lePanneauProtocoleCompteMessages(tester, 15);
          await lesSurfacesAfficheesSont(
            tester,
            'kpi,trend,reviews,checklist,actions',
          );
          await uneSessionVoixEstActive(tester);
          await unSeulTransportAEteCree(tester);
          await leRelaisNaRecuAucunDelete(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['R-05', 'FR-09', 'RG-19'],
    );
    testWidgets('''R-05 Pendant le rejeu, le bouton Démarrer est inactif''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
          tester,
          2,
        );
        await jeCliqueSurArreter(tester);
        await leBoutonDemarrerEstAffiche(tester);
        await jeCliqueSurLecture(tester);
        await leBoutonDemarrerEstInactif(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['R-05', 'FR-09', 'RG-19']);
    testWidgets(
      '''R-06 Direct vide tout, demande la remise à vide et vide le journal''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await jeCliqueSurLecture(tester);
          await leRejeuAvanceDeSecondes(tester, 2.5);
          await jeCliqueSurDirect(tester);
          await aucuneSurfaceNestAffichee(tester);
          await lePanneauProtocoleEstVide(tester);
          await letagereAffiche(tester, '0 / 6 utilisés');
          await leFauxBackendARecuExactementUneRequeteDeRemiseAVide(tester);
          await lindicateurDacteNaffichePlus(tester, 'Rejeu');
          await leBoutonLectureEstInactif(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['R-06', 'FR-09'],
    );
    testWidgets('''R-07 Sans message enregistré, Lecture est inactif''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leBoutonLectureEstInactif(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['R-07', 'FR-09']);
    testWidgets('''R-07 Pendant qu'un agent travaille, Lecture est inactif''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetLePlanATroisAgentsEtLeurActiviteAuTravail(tester);
        await leServeurEmetLaSurfaceEnTroisTemps(tester, 'kpi');
        await leBoutonLectureEstInactif(tester);
        await leServeurEmetLaFinDeLactiviteDesTroisAgents(tester);
        await leBoutonLectureEstActif(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['R-07', 'FR-09']);
    testWidgets(
      '''R-08 Un long silence est plafonné et le curseur couvre la durée comprimée''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'kpi');
          await secondesSecoulentSurLhorlogeDeLapp(tester, 60);
          await leServeurEmetLaSurfaceEnTroisTemps(tester, 'trend');
          await leServeurEmetLaFinDeLactiviteDesTroisAgents(tester);
          await jeCliqueSurLecture(tester);
          await leRejeuAvanceDeSecondes(tester, 1.5);
          await leCurseurEstAEnvironAPointsPres(tester, 50, 6);
          await leRejeuNestPasTermine(tester);
          await leRejeuAvanceDeSecondes(tester, 2);
          await leRejeuEstTermine(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['R-08', 'FR-09'],
    );
    testWidgets('''R-09 Remettre à vide pendant le rejeu équivaut à Direct''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
          tester,
          2,
        );
        await jeCliqueSurLecture(tester);
        await leRejeuAvanceDeSecondes(tester, 2.5);
        await jeCliqueSurRemettreAVide(tester);
        await aucuneSurfaceNestAffichee(tester);
        await leFauxBackendARecuExactementUneRequeteDeRemiseAVide(tester);
        await lindicateurDacteNaffichePlus(tester, 'Rejeu');
        await leBoutonLectureEstInactif(tester);
        await aucunMessageA2uiNestRefuse(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['R-09', 'FR-09']);
    testWidgets(
      '''Démonter la page pendant une lecture ne laisse aucun minuteur actif''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await jeCliqueSurLecture(tester);
          await leRejeuAvanceDeSecondes(tester, 1);
          await laPageEstDemonteePendantLaLecture(tester);
          await aucunMinuteurNestResteActif(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['FR-09'],
    );
  });
}
