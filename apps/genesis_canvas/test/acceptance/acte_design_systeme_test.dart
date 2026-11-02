// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/les_polices_reelles_de_la_scene_sont_chargees.dart';
import './step/la_plateforme_simulee_est_linux.dart';
import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_avec_une_horloge_virtuelle.dart';
import './step/lapp_est_fermee_le_faux_backend_arrete_et_la_semantique_liberee.dart';
import './step/la_plateforme_simulee_est_restauree.dart';
import './step/le_tableau_de_la_release34_est_affiche.dart';
import './step/tout_texte_visible_de_lecran_fait_au_moins_px.dart';
import './step/je_dis.dart';
import './step/le_serveur_emet_la_liste_des_crashs_jusquau_temps.dart';
import './step/la_barre_dactions_est_jouee_en_direct.dart';
import './step/aucune_erreur_nest_signalee.dart';
import './step/les_valeurs_deltas_seuils_et_etiquettes_de_lecran_sont_en_police.dart';
import './step/les_chiffres_des_valeurs_de_lecran_sont_tabulaires.dart';
import './step/les_titres_legendes_libelles_de_boutons_et_textes_courants_de_lecran_sont_en_police.dart';
import './step/les_deux_polices_viennent_des_assets_du_paquet_de_design_systeme_et_de_leurs_licences_enregistrees.dart';
import './step/aucune_police_nest_chargee_par_le_reseau.dart';
import './step/je_note_les_rectangles_des_zones_de_lecran.dart';
import './step/le_canevas_affiche_une_grille_de_colonnes_sur_lignes.dart';
import './step/le_canevas_fait_points_de_haut.dart';
import './step/aucun_libelle_de_la_surface_nest_tronque.dart';
import './step/aucun_libelle_de_letagere_nest_tronque.dart';
import './step/les_rectangles_des_zones_de_lecran_nont_pas_bouge.dart';
import './step/le_statut_est_affiche_avec_son_mot_la_couleur_sur_un_fond_et_le_glyphe.dart';
import './step/le_glyphe_dun_statut_nest_pas_annonce_par_la_semantique.dart';
import './step/le_statut_est_affiche_avec_son_mot_la_couleur_sur_un_fond_et_sans_glyphe.dart';
import './step/le_contraste_du_mot_de_chaque_statut_sur_son_fond_compose_est_dau_moins.dart';
import './step/le_contenu_de_la_surface_est_a_peine_visible.dart';
import './step/le_contenu_de_la_surface_est_decale_de_points_vers_le_bas.dart';
import './step/millisecondes_secoulent.dart';
import './step/le_contenu_de_la_surface_nest_pas_encore_pleinement_visible.dart';
import './step/le_contenu_de_la_surface_est_pleinement_visible.dart';
import './step/le_contenu_de_la_surface_nest_plus_decale.dart';
import './step/parmi_les_statuts_seul_le_statut_bat_en_continu.dart';
import './step/les_animations_du_systeme_sont_desactivees.dart';
import './step/aucune_animation_en_boucle_nest_active_orbe_et_squelette_compris.dart';
import './step/la_serie_du_graphique_est_tracee_en_en_trait_plein.dart';
import './step/la_serie_du_graphique_est_tracee_en_en_pointilles.dart';
import './step/le_seuil_du_graphique_est_trace_en_en_tirets.dart';
import './step/aucune_serie_du_graphique_nest_tracee_avec_une_couleur_de_statut_ni_avec.dart';

void main() {
  group('''Design system - habillage de la scène, texte lisible, polices embarquées, mouvement sobre''', () {
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
      '''U-01 Aucun texte de l'écran ne passe sous 24 px, aux actes 1, 2 et 3''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await toutTexteVisibleDeLecranFaitAuMoinsPx(tester, 24);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await toutTexteVisibleDeLecranFaitAuMoinsPx(tester, 24);
          await laBarreDactionsEstJoueeEnDirect(tester);
          await toutTexteVisibleDeLecranFaitAuMoinsPx(tester, 24);
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['U-01', 'NFR-05'],
    );
    testWidgets(
      '''U-02 Les données sont en JetBrains Mono à chiffres tabulaires, les mots en Space Grotesk, polices embarquées''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await lesValeursDeltasSeuilsEtEtiquettesDeLecranSontEnPolice(
            tester,
            'JetBrains Mono',
          );
          await lesChiffresDesValeursDeLecranSontTabulaires(tester);
          await lesTitresLegendesLibellesDeBoutonsEtTextesCourantsDeLecranSontEnPolice(
            tester,
            'Space Grotesk',
          );
          await lesDeuxPolicesViennentDesAssetsDuPaquetDeDesignSystemeEtDeLeursLicencesEnregistrees(
            tester,
          );
          await aucunePoliceNestChargeeParLeReseau(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['U-02', 'NFR-05', 'NFR-10'],
    );
    testWidgets(
      '''U-03 La disposition de 013 est inchangée avec les polices embarquées''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeNoteLesRectanglesDesZonesDeLecran(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await leCanevasAfficheUneGrilleDeColonnesSurLignes(tester, 3, 2);
          await leCanevasFaitPointsDeHaut(tester, 676);
          await aucunLibelleDeLaSurfaceNestTronque(tester, 'checklist');
          await aucunLibelleDeLaSurfaceNestTronque(tester, 'reviews');
          await aucunLibelleDeLaSurfaceNestTronque(tester, 'trend');
          await aucunLibelleDeLetagereNestTronque(tester);
          await lesRectanglesDesZonesDeLecranNontPasBouge(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['U-03', 'NFR-05', 'FR-06'],
    );
    testWidgets(
      '''U-04 Un statut s'affiche avec son mot et sa couleur du design system, jamais la couleur seule''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leStatutEstAfficheAvecSonMotLaCouleurSurUnFondEtLeGlyphe(
            tester,
            'ok',
            'go',
            'go-ghost',
            '✓',
          );
          await leGlypheDunStatutNestPasAnnonceParLaSemantique(tester);
          await leStatutEstAfficheAvecSonMotLaCouleurSurUnFondEtSansGlyphe(
            tester,
            'risk',
            'warn',
            'warn-ghost',
          );
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await leStatutEstAfficheAvecSonMotLaCouleurSurUnFondEtSansGlyphe(
            tester,
            'blocking',
            'nogo',
            'nogo-ghost',
          );
          await leContrasteDuMotDeChaqueStatutSurSonFondComposeEstDauMoins(
            tester,
            4.5,
          );
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['U-04', 'NFR-05', 'RG-09'],
    );
    testWidgets(
      '''U-05 Une surface apparaît en 480 ms avec 10 points de glissement, sans animation en boucle superflue''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'components');
          await leContenuDeLaSurfaceEstAPeineVisible(tester, 'crashes');
          await leContenuDeLaSurfaceEstDecaleDePointsVersLeBas(
            tester,
            'crashes',
            10,
          );
          await millisecondesSecoulent(tester, 240);
          await leContenuDeLaSurfaceNestPasEncorePleinementVisible(
            tester,
            'crashes',
          );
          await millisecondesSecoulent(tester, 260);
          await leContenuDeLaSurfaceEstPleinementVisible(tester, 'crashes');
          await leContenuDeLaSurfaceNestPlusDecale(tester, 'crashes');
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await parmiLesStatutsSeulLeStatutBatEnContinu(tester, 'blocking');
          await lesAnimationsDuSystemeSontDesactivees(tester);
          await aucuneAnimationEnBoucleNestActiveOrbeEtSqueletteCompris(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['U-05', 'FR-04', 'NFR-04'],
    );
    testWidgets(
      '''U-06 Les séries du graphique ont les couleurs du design system, la série 3.3 est en pointillés, le seuil en tirets''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await laSerieDuGraphiqueEstTraceeEnEnTraitPlein(
            tester,
            'Android 3.4',
            'signal',
          );
          await laSerieDuGraphiqueEstTraceeEnEnPointilles(
            tester,
            'Android 3.3',
            'signal',
          );
          await leSeuilDuGraphiqueEstTraceEnEnTirets(tester, 'nogo');
          await aucuneSerieDuGraphiqueNestTraceeAvecUneCouleurDeStatutNiAvec(
            tester,
            'plasma',
          );
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['U-06', 'FR-06', 'NFR-05'],
    );
  });
}
