// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/les_polices_reelles_de_la_scene_sont_chargees.dart';
import './step/la_plateforme_simulee_est_linux.dart';
import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_avec_une_horloge_virtuelle.dart';
import './step/lapp_est_fermee_le_faux_backend_arrete_et_la_semantique_liberee.dart';
import './step/la_plateforme_simulee_est_restauree.dart';
import './step/le_tableau_de_la_release34_est_joue_en_direct_une_surface_toutes_les_secondes.dart';
import './step/le_canevas_commence_points_sous_le_rail_des_agents.dart';
import './step/le_canevas_fait_points_de_haut.dart';
import './step/la_premiere_surface_est_au_ras_du_haut_du_canevas.dart';
import './step/je_clique_sur_lecture.dart';
import './step/jattends_la_fin_du_rejeu.dart';
import './step/le_tableau_de_la_release34_est_affiche.dart';
import './step/je_dis.dart';
import './step/le_serveur_emet_la_liste_des_crashs_jusquau_temps.dart';
import './step/le_canevas_affiche_une_grille_de_colonnes_sur_lignes.dart';
import './step/aucun_libelle_de_la_surface_nest_tronque.dart';
import './step/la_surface_affiche_entre_et_extraits_davis_entiers_et_lindication_n_avis_pour_les_autres.dart';
import './step/le_texte_de_la_surface_fait_au_moins_px.dart';
import './step/aucune_erreur_nest_signalee.dart';
import './step/le_titre_de_la_courbe_nest_pas_tronque.dart';
import './step/la_legende_de_la_courbe_est_sous_son_titre.dart';
import './step/letagere_affiche.dart';
import './step/letagere_affiche_noms_de_composants_entiers.dart';
import './step/aucun_libelle_de_letagere_nest_tronque.dart';
import './step/le_composant_de_letagere_porte_une_icone_detat_et_est_annonce.dart';
import './step/licone_detat_dun_composant_utilise_differe_de_celle_dun_composant_inutilise.dart';
import './step/lindicateur_dacte_est_empile_audessus_du_bouton_remettre_a_vide.dart';
import './step/lindicateur_dacte_fait_au_moins_points_dans_les_deux_sens.dart';
import './step/le_bouton_remettre_a_vide_fait_au_moins_points_dans_les_deux_sens.dart';
import './step/le_serveur_emet_la_fixture_refusee.dart';
import './step/la_barre_dactions_est_jouee_en_direct.dart';
import './step/je_clique_sur_le_bouton_du_panneau_protocole.dart';
import './step/le_panneau_protocole_est_deplie.dart';
import './step/le_panneau_protocole_affiche_un_message.dart';
import './step/le_panneau_protocole_deplie_ne_depasse_pas_le_haut_du_canevas.dart';
import './step/un_squelette_est_visible_pour_la_surface.dart';
import './step/le_contenu_de_la_surface_est_a_peine_visible.dart';
import './step/millisecondes_secoulent.dart';
import './step/le_contenu_de_la_surface_est_pleinement_visible.dart';
import './step/aucun_squelette_nest_visible_pour_la_surface.dart';
import './step/la_ligne_de_la_liste_des_crashs_est_a_peine_visible.dart';
import './step/la_ligne_de_la_liste_des_crashs_est_pleinement_visible.dart';
import './step/les_animations_du_systeme_sont_desactivees.dart';
import './step/je_choisis_la_vitesse.dart';
import './step/javance_par_pas_de_millisecondes_jusqua_ce_que_les_composants_de_la_surface_soient_affiches.dart';
import './step/une_session_voix_demarree.dart';
import './step/je_note_les_rectangles_des_zones_de_lecran.dart';
import './step/le_serveur_emet_le_plan_a_trois_agents_et_leur_activite_au_travail.dart';
import './step/les_rectangles_des_zones_de_lecran_nont_pas_bouge.dart';
import './step/je_note_les_rectangles_des_surfaces.dart';
import './step/les_rectangles_des_surfaces_nont_pas_bouge.dart';
import './step/les_surfaces_existantes_restent_a_leur_place.dart';
import './step/les_rectangles_des_surfaces_restent_constants_a_chaque_image_pendant_millisecondes.dart';
import './step/les_surfaces_de_lacte1_gardent_leur_state.dart';

void main() {
  group('''Design et ergonomie - écran lisible, régie à portée de main, apparition animée''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await lesPolicesReellesDeLaSceneSontChargees(tester);
      await laPlateformeSimuleeEstLinux(tester);
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendAvecUneHorlogeVirtuelle(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeLeFauxBackendArreteEtLaSemantiqueLiberee(tester);
      await laPlateformeSimuleeEstRestauree(tester);
    }

    testWidgets(
      '''D-01 Aucune bande vide entre le rail et le canevas, en direct puis en rejeu''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await leCanevasCommencePointsSousLeRailDesAgents(tester, 8);
          await leCanevasFaitPointsDeHaut(tester, 676);
          await laPremiereSurfaceEstAuRasDuHautDuCanevas(tester);
          await jeCliqueSurLecture(tester);
          await jattendsLaFinDuRejeu(tester);
          await leCanevasCommencePointsSousLeRailDesAgents(tester, 8);
          await leCanevasFaitPointsDeHaut(tester, 676);
          await laPremiereSurfaceEstAuRasDuHautDuCanevas(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-01', 'FR-01', 'NFR-05'],
    );
    testWidgets(
      '''D-02 La checklist et les avis de l'acte 2 ne sont tronqués nulle part en 3 x 2''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await leCanevasAfficheUneGrilleDeColonnesSurLignes(tester, 3, 2);
          await aucunLibelleDeLaSurfaceNestTronque(tester, 'checklist');
          await aucunLibelleDeLaSurfaceNestTronque(tester, 'reviews');
          await laSurfaceAfficheEntreEtExtraitsDavisEntiersEtLindicationNAvisPourLesAutres(
            tester,
            'reviews',
            1,
            2,
          );
          await leTexteDeLaSurfaceFaitAuMoinsPx(tester, 'checklist', 24);
          await leTexteDeLaSurfaceFaitAuMoinsPx(tester, 'reviews', 24);
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-02', 'FR-06', 'NFR-05'],
    );
    testWidgets(
      '''D-03 Le titre de la courbe est entier et la légende passe sous le titre''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await leCanevasAfficheUneGrilleDeColonnesSurLignes(tester, 3, 2);
          await leTitreDeLaCourbeNestPasTronque(tester);
          await laLegendeDeLaCourbeEstSousSonTitre(tester);
          await aucunLibelleDeLaSurfaceNestTronque(tester, 'trend');
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-03', 'FR-06', 'NFR-05'],
    );
    testWidgets(
      '''D-04 L'étagère affiche six noms entiers et porte l'état par une icône et la sémantique''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await letagereAffiche(tester, '4 / 6 utilisés');
          await letagereAfficheNomsDeComposantsEntiers(tester, 6);
          await aucunLibelleDeLetagereNestTronque(tester);
          await leComposantDeLetagerePorteUneIconeDetatEtEstAnnonce(
            tester,
            'KeyIndicator',
            'utilisé',
          );
          await leComposantDeLetagerePorteUneIconeDetatEtEstAnnonce(
            tester,
            'ReleaseChecklist',
            'utilisé',
          );
          await leComposantDeLetagerePorteUneIconeDetatEtEstAnnonce(
            tester,
            'ActionBar',
            'inutilisé',
          );
          await leComposantDeLetagerePorteUneIconeDetatEtEstAnnonce(
            tester,
            'CrashList',
            'inutilisé',
          );
          await liconeDetatDunComposantUtiliseDiffereDeCelleDunComposantInutilise(
            tester,
          );
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-04', 'FR-06', 'NFR-05'],
    );
    testWidgets(
      '''D-05 La régie empile deux contrôles de 48 points et le panneau déplié reste dans sa zone''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await lindicateurDacteEstEmpileAudessusDuBoutonRemettreAVide(tester);
          await lindicateurDacteFaitAuMoinsPointsDansLesDeuxSens(tester, 48);
          await leBoutonRemettreAVideFaitAuMoinsPointsDansLesDeuxSens(
            tester,
            48,
          );
          await leServeurEmetLaFixtureRefusee(tester, 'component_not_allowed');
          await laBarreDactionsEstJoueeEnDirect(tester);
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await lePanneauProtocoleEstDeplie(tester);
          await lePanneauProtocoleAfficheUnMessage(tester, 'refusé');
          await lePanneauProtocoleDeplieNeDepassePasLeHautDuCanevas(tester);
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-05', 'FR-11', 'NFR-05'],
    );
    testWidgets(
      '''D-06 Une surface apparaît en trois temps : squelette, composants, données''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'skeleton');
          await unSqueletteEstVisiblePourLaSurface(tester, 'crashes');
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'components');
          await leContenuDeLaSurfaceEstAPeineVisible(tester, 'crashes');
          await millisecondesSecoulent(tester, 250);
          await leContenuDeLaSurfaceEstPleinementVisible(tester, 'crashes');
          await aucunSqueletteNestVisiblePourLaSurface(tester, 'crashes');
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await laLigneDeLaListeDesCrashsEstAPeineVisible(tester, 1);
          await millisecondesSecoulent(tester, 200);
          await laLigneDeLaListeDesCrashsEstPleinementVisible(tester, 1);
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-06', 'FR-04', 'NFR-04'],
    );
    testWidgets(
      '''D-06 Avec les animations du système désactivées, le résultat est immédiat''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await lesAnimationsDuSystemeSontDesactivees(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'components');
          await leContenuDeLaSurfaceEstPleinementVisible(tester, 'crashes');
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await laLigneDeLaListeDesCrashsEstPleinementVisible(tester, 1);
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-06', 'FR-04', 'NFR-04'],
    );
    testWidgets(
      '''D-06 En rejeu à 2 x la durée de l'apparition est divisée par deux''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await jeCliqueSurLecture(tester);
          await jeChoisisLaVitesse(tester, 2);
          await javanceParPasDeMillisecondesJusquaCeQueLesComposantsDeLaSurfaceSoientAffiches(
            tester,
            10,
            'checklist',
          );
          await leContenuDeLaSurfaceEstAPeineVisible(tester, 'checklist');
          await millisecondesSecoulent(tester, 120);
          await leContenuDeLaSurfaceEstPleinementVisible(tester, 'checklist');
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-06', 'FR-04', 'FR-09', 'NFR-04'],
    );
    testWidgets('''D-07 L'arrivée du premier plan ne déplace aucune zone''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await jeNoteLesRectanglesDesZonesDeLecran(tester);
        await leServeurEmetLePlanATroisAgentsEtLeurActiviteAuTravail(tester);
        await lesRectanglesDesZonesDeLecranNontPasBouge(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['D-07', 'FR-03', 'NFR-04']);
    testWidgets(
      '''D-07 Une mutation de l'acte 2 ne déplace ni zone ni surface''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeNoteLesRectanglesDesZonesDeLecran(tester);
          await jeNoteLesRectanglesDesSurfaces(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await lesRectanglesDesZonesDeLecranNontPasBouge(tester);
          await lesRectanglesDesSurfacesNontPasBouge(tester);
          await lesSurfacesExistantesRestentALeurPlace(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-07', 'S-02', 'NFR-04'],
    );
    testWidgets(
      '''D-07 L'arrivée du bandeau d'actions ne déplace ni zone ni surface''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeNoteLesRectanglesDesZonesDeLecran(tester);
          await jeNoteLesRectanglesDesSurfaces(tester);
          await laBarreDactionsEstJoueeEnDirect(tester);
          await lesRectanglesDesZonesDeLecranNontPasBouge(tester);
          await lesRectanglesDesSurfacesNontPasBouge(tester);
          await lesSurfacesExistantesRestentALeurPlace(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-07', 'S-02', 'NFR-04'],
    );
    testWidgets(
      '''D-07 L'arrivée d'une surface de la grille ne recrée aucun State et ne déplace aucune surface en cours d'image''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'skeleton');
          await jeNoteLesRectanglesDesSurfaces(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await lesRectanglesDesSurfacesRestentConstantsAChaqueImagePendantMillisecondes(
            tester,
            400,
          );
          await lesSurfacesDeLacte1GardentLeurState(tester);
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['D-07', 'S-02', 'NFR-04'],
    );
  });
}
