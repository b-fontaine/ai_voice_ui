// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_en_relevant_ses_erreurs.dart';
import './step/lapp_est_fermee_et_le_faux_backend_arrete.dart';
import './step/le_tableau_de_la_release34_est_affiche.dart';
import './step/le_serveur_emet_la_liste_des_crashs_jusquau_temps.dart';
import './step/la_surface_affiche.dart';
import './step/le_canevas_affiche_une_grille_de_colonnes_sur_lignes.dart';
import './step/les_surfaces_du_canevas_se_lisent_dans_lordre.dart';
import './step/les_surfaces_de_lacte1_gardent_leur_state.dart';
import './step/letagere_affiche.dart';
import './step/le_composant_de_letagere_est.dart';
import './step/aucun_squelette_nest_reapparu.dart';
import './step/aucun_message_a2ui_nest_refuse.dart';
import './step/un_squelette_est_visible_pour_la_surface.dart';
import './step/aucune_ligne_de_la_liste_des_crashs_nest_affichee.dart';
import './step/aucun_squelette_nest_visible_pour_la_surface.dart';
import './step/la_surface_naffiche_pas_letat_neutre.dart';
import './step/la_liste_des_crashs_affiche_lignes.dart';
import './step/aucune_erreur_nest_signalee.dart';
import './step/le_texte_de_la_liste_des_crashs_fait_au_moins_px.dart';
import './step/chaque_libelle_de_la_liste_des_crashs_tient_sur_ligne_puis_une_ellipse.dart';
import './step/le_serveur_emet_la_liste_des_crashs_dont_le_champ_est_une_chaine.dart';
import './step/la_surface_affiche_letat_neutre.dart';
import './step/le_serveur_emet_la_liste_des_crashs_dont_une_ligne_na_pas_de_libelle.dart';

void main() {
  group('''Liste des crashs - cinquième surface du canevas''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendEnRelevantSesErreurs(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeEtLeFauxBackendArrete(tester);
    }

    testWidgets(
      '''F-01 La liste des crashs devient la cinquième cellule sans recréer les quatre autres''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await laSurfaceAffiche(tester, 'crashes', 'Principaux crashs · 3.4');
          await leCanevasAfficheUneGrilleDeColonnesSurLignes(tester, 3, 2);
          await lesSurfacesDuCanevasSeLisentDansLordre(
            tester,
            'kpi, trend, reviews, checklist, crashes',
          );
          await lesSurfacesDeLacte1GardentLeurState(tester);
          await letagereAffiche(tester, '5 / 6 utilisés');
          await leComposantDeLetagereEst(tester, 'CrashList', 'utilisé');
          await aucunSqueletteNestReapparu(tester);
          await aucunMessageA2uiNestRefuse(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['F-01', 'FR-01', 'FR-06'],
    );
    testWidgets(
      '''F-02 La liste des crashs passe par le squelette, l'absence de données puis les données''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'skeleton');
          await unSqueletteEstVisiblePourLaSurface(tester, 'crashes');
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'components');
          await aucuneLigneDeLaListeDesCrashsNestAffichee(tester);
          await aucunSqueletteNestVisiblePourLaSurface(tester, 'crashes');
          await laSurfaceNaffichePasLetatNeutre(tester, 'crashes');
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await laListeDesCrashsAfficheLignes(tester, 5);
          await laSurfaceAffiche(
            tester,
            'crashes',
            'Plantage à la validation du panier (3-D Secure 2)',
          );
          await laSurfaceAffiche(
            tester,
            'crashes',
            'Plantage à l\'ouverture d\'une notification push',
          );
          await aucuneErreurNestSignalee(tester);
          await aucunMessageA2uiNestRefuse(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['F-02', 'FR-01', 'RG-10'],
    );
    testWidgets(
      '''F-02 Le texte de la liste est lisible et les libellés longs tiennent sur une ligne puis une ellipse''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetLaListeDesCrashsJusquauTemps(tester, 'data');
          await laListeDesCrashsAfficheLignes(tester, 5);
          await leTexteDeLaListeDesCrashsFaitAuMoinsPx(tester, 24);
          await chaqueLibelleDeLaListeDesCrashsTientSurLignePuisUneEllipse(
            tester,
            1,
          );
          await aucuneErreurNestSignalee(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['F-02', 'NFR-03'],
    );
    testWidgets('''F-02 Un champ items de mauvais type donne l'état neutre''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstAffiche(tester);
        await leServeurEmetLaListeDesCrashsDontLeChampEstUneChaine(
          tester,
          'items',
        );
        await laSurfaceAfficheLetatNeutre(
          tester,
          'crashes',
          'Données indisponibles',
        );
        await aucuneLigneDeLaListeDesCrashsNestAffichee(tester);
        await lesSurfacesDeLacte1GardentLeurState(tester);
        await aucuneErreurNestSignalee(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['F-02', 'RG-10']);
    testWidgets('''F-02 Une ligne sans libellé donne l'état neutre''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstAffiche(tester);
        await leServeurEmetLaListeDesCrashsDontUneLigneNaPasDeLibelle(tester);
        await laSurfaceAfficheLetatNeutre(
          tester,
          'crashes',
          'Données indisponibles',
        );
        await aucuneLigneDeLaListeDesCrashsNestAffichee(tester);
        await lesSurfacesDeLacte1GardentLeurState(tester);
        await aucuneErreurNestSignalee(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['F-02', 'RG-10']);
  });
}
