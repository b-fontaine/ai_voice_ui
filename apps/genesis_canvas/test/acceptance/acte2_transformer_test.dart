// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/les_polices_reelles_de_la_scene_sont_chargees.dart';
import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_en_relevant_ses_erreurs.dart';
import './step/lapp_est_fermee_et_le_faux_backend_arrete.dart';
import './step/le_tableau_de_la_release34_est_affiche.dart';
import './step/je_dis.dart';
import './step/les_surfaces_existantes_restent_a_leur_place.dart';
import './step/les_donnees_affichees_concernent_uniquement_android.dart';
import './step/une_comparaison_avec_la33_apparait.dart';
import './step/je_clique_sur_arreter.dart';
import './step/je_clique_sur_demarrer.dart';
import './step/la_session_active_est_la_seconde_du_relais.dart';
import './step/aucun_message_a2ui_nest_refuse.dart';
import './step/aucun_squelette_nest_reapparu.dart';
import './step/la_ligne_de_comparaison_de_la_surface_a_disparu.dart';
import './step/la_courbe_ne_contient_que_la_serie.dart';
import './step/la_surface_affiche.dart';
import './step/la_ligne_de_comparaison_de_la_surface_affiche.dart';
import './step/la_ligne_de_comparaison_de_la_surface_na_pas_de_couleur_de_statut.dart';
import './step/le_serveur_emet_lacte2_de_la_surface_sans_le_champ_de_la_comparaison.dart';
import './step/la_surface_naffiche_pas_letat_neutre.dart';
import './step/aucune_erreur_nest_signalee.dart';

void main() {
  group('''Acte 2 - transformer sans recréer''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await lesPolicesReellesDeLaSceneSontChargees(tester);
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendEnRelevantSesErreurs(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeEtLeFauxBackendArrete(tester);
    }

    testWidgets('''S-02 Acte 2 - transformer sans recréer''', (tester) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstAffiche(tester);
        await jeDis(tester, 'Concentre-toi sur Android et compare avec la 3.3');
        await lesSurfacesExistantesRestentALeurPlace(tester);
        await lesDonneesAfficheesConcernentUniquementAndroid(tester);
        await uneComparaisonAvecLa33Apparait(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['S-02', 'FR-07']);
    testWidgets(
      '''B1 Une seconde session transforme le tableau de la première''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeCliqueSurArreter(tester);
          await jeCliqueSurDemarrer(tester);
          await laSessionActiveEstLaSecondeDuRelais(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await aucunMessageA2uiNestRefuse(tester);
          await lesSurfacesExistantesRestentALeurPlace(tester);
          await aucunSqueletteNestReapparu(tester);
          await lesDonneesAfficheesConcernentUniquementAndroid(tester);
          await uneComparaisonAvecLa33Apparait(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets(
      '''B2 La correction vers iOS retire la comparaison sans recréer''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await uneComparaisonAvecLa33Apparait(tester);
          await jeDis(tester, 'Non, plutôt iOS');
          await laLigneDeComparaisonDeLaSurfaceADisparu(tester, 'kpi');
          await laLigneDeComparaisonDeLaSurfaceADisparu(tester, 'reviews');
          await laCourbeNeContientQueLaSerie(tester, 'iOS 3.4');
          await laSurfaceAffiche(tester, 'kpi', '99,80 %');
          await laSurfaceAffiche(tester, 'checklist', 'GO iOS');
          await lesSurfacesExistantesRestentALeurPlace(tester);
          await aucunSqueletteNestReapparu(tester);
          await aucunMessageA2uiNestRefuse(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets(
      '''B4 La ligne de comparaison de l'indicateur clé est neutre''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await jeDis(
            tester,
            'Concentre-toi sur Android et compare avec la 3.3',
          );
          await laLigneDeComparaisonDeLaSurfaceAffiche(
            tester,
            'kpi',
            '3.3 : 99,71 % · −0,28 pt',
          );
          await laLigneDeComparaisonDeLaSurfaceAffiche(
            tester,
            'reviews',
            '3.3 : 14 % négatifs · +16 pts',
          );
          await laLigneDeComparaisonDeLaSurfaceNaPasDeCouleurDeStatut(
            tester,
            'kpi',
          );
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets('''B4 Une comparaison sans écart omet seulement sa ligne''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstAffiche(tester);
        await jeDis(tester, 'Concentre-toi sur Android et compare avec la 3.3');
        await laLigneDeComparaisonDeLaSurfaceAffiche(
          tester,
          'kpi',
          '3.3 : 99,71 % · −0,28 pt',
        );
        await leServeurEmetLacte2DeLaSurfaceSansLeChampDeLaComparaison(
          tester,
          'kpi',
          'delta',
        );
        await laSurfaceAffiche(tester, 'kpi', '99,43 %');
        await laLigneDeComparaisonDeLaSurfaceADisparu(tester, 'kpi');
        await laSurfaceNaffichePasLetatNeutre(tester, 'kpi');
        await aucuneErreurNestSignalee(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''B4 Une comparaison sans valeur omet seulement sa ligne''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await leTableauDeLaRelease34EstAffiche(tester);
        await jeDis(tester, 'Concentre-toi sur Android et compare avec la 3.3');
        await laLigneDeComparaisonDeLaSurfaceAffiche(
          tester,
          'reviews',
          '3.3 : 14 % négatifs · +16 pts',
        );
        await leServeurEmetLacte2DeLaSurfaceSansLeChampDeLaComparaison(
          tester,
          'reviews',
          'value',
        );
        await laSurfaceAffiche(tester, 'reviews', '30 %');
        await laLigneDeComparaisonDeLaSurfaceADisparu(tester, 'reviews');
        await laSurfaceNaffichePasLetatNeutre(tester, 'reviews');
        await aucuneErreurNestSignalee(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
  });
}
