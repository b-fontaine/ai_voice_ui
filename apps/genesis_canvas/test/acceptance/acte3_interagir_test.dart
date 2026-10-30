// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_en_relevant_ses_erreurs.dart';
import './step/lapp_est_fermee_et_le_faux_backend_arrete.dart';
import './step/la_checklist_gonogo_est_affichee.dart';
import './step/je_clique_sur.dart';
import './step/le_faux_backend_a_recu_laction_de_la_surface.dart';
import './step/lagent_livraison_sallume_dans_le_rail.dart';
import './step/lagent_est_affiche.dart';
import './step/le_statut_de_la_checklist_passe_a.dart';
import './step/les_criteres_la_recommandation_et_la_comparaison_sont_inchanges.dart';
import './step/aucun_message_a2ui_nest_refuse.dart';
import './step/le_faux_backend_repond_occupe_fois_aux_actions_puis_les_accepte.dart';
import './step/le_faux_backend_a_recu_requetes_daction.dart';
import './step/le_faux_backend_na_pas_recu_plus_de_requetes_daction_apres_le_delai_des_reessais.dart';
import './step/les_boutons_de_la_barre_dactions_sont_actifs.dart';
import './step/le_statut_de_la_checklist_ne_passe_pas_a.dart';
import './step/le_faux_backend_suspend_laction_apres_lavoir_acceptee.dart';
import './step/les_boutons_de_la_barre_dactions_sont_inactifs.dart';
import './step/le_serveur_emet_le_debut_de_laction.dart';
import './step/le_serveur_emet_le_resultat_de_laction.dart';
import './step/le_tableau_de_la_release34_est_affiche.dart';
import './step/le_serveur_emet_la_barre_dactions_jusquau_temps.dart';
import './step/un_squelette_est_visible_pour_la_surface.dart';
import './step/aucun_bouton_daction_nest_affiche.dart';
import './step/aucun_squelette_nest_visible_pour_la_surface.dart';
import './step/la_surface_affiche.dart';
import './step/le_serveur_emet_la_barre_dactions_avec_laction_inconnue.dart';
import './step/la_surface_affiche_letat_neutre.dart';
import './step/les_boutons_de_la_barre_dactions_ont_un_texte_dau_moins_px_et_une_cible_dau_moins_px.dart';
import './step/je_dis.dart';
import './step/le_serveur_emet_la_barre_dactions_de_la_fin_de_lacte2.dart';
import './step/la_barre_dactions_est_affichee_sous_la_grille.dart';
import './step/les_surfaces_existantes_restent_a_leur_place.dart';
import './step/letagere_affiche.dart';
import './step/aucun_squelette_nest_reapparu.dart';

void main() {
  group('''Acte 3 - interagir avec un composant généré''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendEnRelevantSesErreurs(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeEtLeFauxBackendArrete(tester);
    }

    testWidgets('''S-03 Acte 3 - interagir avec un composant généré''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await jeCliqueSur(tester, 'Bloquer la release');
        await leFauxBackendARecuLactionDeLaSurface(
          tester,
          'block_release',
          'actions',
        );
        await lagentLivraisonSallumeDansLeRail(tester);
        await lagentEstAffiche(tester, 'Qualité', 'en veille');
        await lagentEstAffiche(tester, 'Voix du client', 'en veille');
        await lagentEstAffiche(tester, 'Livraison', 'terminé');
        await leStatutDeLaChecklistPasseA(tester, 'Bloquée');
        await lesCriteresLaRecommandationEtLaComparaisonSontInchanges(tester);
        await aucunMessageA2uiNestRefuse(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['S-03', 'FR-03', 'FR-08']);
    testWidgets('''C1 Valider la release affiche Validée''', (tester) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await jeCliqueSur(tester, 'Valider la release');
        await leFauxBackendARecuLactionDeLaSurface(
          tester,
          'validate_release',
          'actions',
        );
        await leStatutDeLaChecklistPasseA(tester, 'Validée');
        await lesCriteresLaRecommandationEtLaComparaisonSontInchanges(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets('''C1 La décision humaine la plus récente prime''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await jeCliqueSur(tester, 'Bloquer la release');
        await leStatutDeLaChecklistPasseA(tester, 'Bloquée');
        await jeCliqueSur(tester, 'Valider la release');
        await leFauxBackendARecuLactionDeLaSurface(
          tester,
          'validate_release',
          'actions',
        );
        await leStatutDeLaChecklistPasseA(tester, 'Validée');
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-08']);
    testWidgets('''C3 Un 409 occupé est réessayé puis l'action aboutit''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await leFauxBackendRepondOccupeFoisAuxActionsPuisLesAccepte(tester, 1);
        await jeCliqueSur(tester, 'Bloquer la release');
        await leFauxBackendARecuRequetesDaction(tester, 2);
        await leStatutDeLaChecklistPasseA(tester, 'Bloquée');
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets(
      '''C3 Les réessais sont bornés puis les boutons redeviennent actifs''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await laChecklistGonogoEstAffichee(tester);
          await leFauxBackendRepondOccupeFoisAuxActionsPuisLesAccepte(
            tester,
            50,
          );
          await jeCliqueSur(tester, 'Bloquer la release');
          await leFauxBackendNaPasRecuPlusDeRequetesDactionApresLeDelaiDesReessais(
            tester,
            10,
          );
          await lesBoutonsDeLaBarreDactionsSontActifs(tester);
          await leStatutDeLaChecklistNePassePasA(tester, 'Bloquée');
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets(
      '''C3 Les boutons sont inactifs de l'envoi jusqu'à la fin de l'action''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await laChecklistGonogoEstAffichee(tester);
          await leFauxBackendSuspendLactionApresLavoirAcceptee(tester);
          await lesBoutonsDeLaBarreDactionsSontActifs(tester);
          await jeCliqueSur(tester, 'Bloquer la release');
          await leFauxBackendARecuLactionDeLaSurface(
            tester,
            'block_release',
            'actions',
          );
          await lesBoutonsDeLaBarreDactionsSontInactifs(tester);
          await leServeurEmetLeDebutDeLaction(tester);
          await lagentEstAffiche(tester, 'Livraison', 'en cours');
          await lesBoutonsDeLaBarreDactionsSontInactifs(tester);
          await leServeurEmetLeResultatDeLaction(tester);
          await leStatutDeLaChecklistPasseA(tester, 'Bloquée');
          await lesBoutonsDeLaBarreDactionsSontActifs(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets(
      '''C6 La Barre d'actions passe par le squelette puis les composants puis les données''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetLaBarreDactionsJusquauTemps(tester, 'skeleton');
          await unSqueletteEstVisiblePourLaSurface(tester, 'actions');
          await leServeurEmetLaBarreDactionsJusquauTemps(tester, 'components');
          await aucunBoutonDactionNestAffiche(tester);
          await aucunSqueletteNestVisiblePourLaSurface(tester, 'actions');
          await leServeurEmetLaBarreDactionsJusquauTemps(tester, 'data');
          await laSurfaceAffiche(tester, 'actions', 'Décision');
          await laSurfaceAffiche(tester, 'actions', 'Bloquer la release');
          await laSurfaceAffiche(tester, 'actions', 'Valider la release');
          await lesBoutonsDeLaBarreDactionsSontActifs(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets('''C6 Une action hors contrat donne l'état neutre''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstAffiche(tester);
        await leServeurEmetLaBarreDactionsAvecLactionInconnue(
          tester,
          'delete_release',
        );
        await laSurfaceAfficheLetatNeutre(
          tester,
          'actions',
          'Données indisponibles',
        );
        await aucunBoutonDactionNestAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''C6 Les boutons sont lisibles et atteignables''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await laChecklistGonogoEstAffichee(tester);
        await lesBoutonsDeLaBarreDactionsSontActifs(tester);
        await lesBoutonsDeLaBarreDactionsOntUnTexteDauMoinsPxEtUneCibleDauMoinsPx(
          tester,
          24,
          48,
        );
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets(
      '''A1 La Barre d'actions arrive sous la grille sans bouger les quatre surfaces''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaBarreDactionsDeLaFinDeLacte2(tester);
          await laSurfaceAffiche(tester, 'actions', 'Bloquer la release');
          await laBarreDactionsEstAfficheeSousLaGrille(tester);
          await lesSurfacesExistantesRestentALeurPlace(tester);
          await letagereAffiche(tester, '5 / 6 utilisés');
          await aucunSqueletteNestReapparu(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
    );
  });
}
