// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_avec_une_horloge_virtuelle.dart';
import './step/lapp_est_fermee_le_faux_backend_arrete_et_la_semantique_liberee.dart';
import './step/le_tableau_de_la_release34_est_joue_en_direct_une_surface_toutes_les_secondes.dart';
import './step/le_rejeu_est_en_pause_a_miparcours.dart';
import './step/je_clique_sur_le_bouton_du_panneau_protocole.dart';
import './step/chaque_commande_de_la_barre_de_rejeu_est_atteignable.dart';
import './step/lextremite_droite_de_la_glissiere_est_atteignable.dart';
import './step/la_barre_dactions_est_jouee_en_direct.dart';
import './step/le_panneau_protocole_deplie_ne_recouvre_ni_la_rangee_du_bas_ni_le_rail.dart';
import './step/les_entrees_du_panneau_et_son_bouton_replier_sont_visibles_dans_la_fenetre.dart';
import './step/le_panneau_protocole_deplie_montre_entrees.dart';
import './step/les_commandes_hors_du_panneau_restent_atteignables.dart';
import './step/je_clique_sur_lecture.dart';
import './step/je_choisis_la_vitesse.dart';
import './step/jattends_la_fin_du_rejeu.dart';
import './step/aucun_message_a2ui_nest_refuse.dart';

void main() {
  group('''Barre de rejeu toujours atteignable, panneau du protocole replié ou déplié''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendAvecUneHorlogeVirtuelle(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeLeFauxBackendArreteEtLaSemantiqueLiberee(tester);
    }

    testWidgets(
      '''RB-01 Panneau déplié, chaque commande de la barre de rejeu est atteignable''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await leRejeuEstEnPauseAMiparcours(tester);
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await chaqueCommandeDeLaBarreDeRejeuEstAtteignable(tester);
          await lextremiteDroiteDeLaGlissiereEstAtteignable(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['RB-01', 'FR-09', 'FR-05'],
    );
    testWidgets(
      '''RB-02 Panneau replié, chaque commande de la barre de rejeu est atteignable''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await leRejeuEstEnPauseAMiparcours(tester);
          await chaqueCommandeDeLaBarreDeRejeuEstAtteignable(tester);
          await lextremiteDroiteDeLaGlissiereEstAtteignable(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['RB-02', 'FR-09', 'FR-05'],
    );
    testWidgets(
      '''RB-03 Panneau déplié, la rangée du bas et le rail restent libres et les clics hors du panneau le traversent''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstJoueEnDirectUneSurfaceToutesLesSecondes(
            tester,
            2,
          );
          await laBarreDactionsEstJoueeEnDirect(tester);
          await jeCliqueSurLeBoutonDuPanneauProtocole(tester);
          await lePanneauProtocoleDeplieNeRecouvreNiLaRangeeDuBasNiLeRail(
            tester,
          );
          await lesEntreesDuPanneauEtSonBoutonReplierSontVisiblesDansLaFenetre(
            tester,
          );
          await lePanneauProtocoleDeplieMontreEntrees(tester, 4);
          await lesCommandesHorsDuPanneauRestentAtteignables(tester);
          await jeCliqueSurLecture(tester);
          await jeChoisisLaVitesse(tester, 2);
          await jattendsLaFinDuRejeu(tester);
          await aucunMessageA2uiNestRefuse(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['RB-03', 'FR-09', 'FR-05'],
    );
  });
}
