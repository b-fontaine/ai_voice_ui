// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/les_polices_reelles_de_la_scene_sont_chargees.dart';
import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend_avec_une_horloge_virtuelle.dart';
import './step/lapp_est_fermee_le_faux_backend_arrete_et_la_semantique_liberee.dart';
import './step/une_session_voix_demarree.dart';
import './step/le_serveur_emet_un_niveau_dorbe_de.dart';
import './step/lorbe_est_a_letat.dart';
import './step/je_clique_sur_la_commande.dart';
import './step/la_piste_distante_est_coupee.dart';
import './step/la_session_reste_ouverte.dart';
import './step/secondes_secoulent_sans_parole_de_lia.dart';
import './step/la_piste_distante_est_retablie.dart';
import './step/jappuie_sur_la_touche_echap.dart';
import './step/je_note_letat_de_lorbe.dart';
import './step/le_voile_est_affiche.dart';
import './step/le_voile_nest_plus_affiche.dart';
import './step/lorbe_est_revenu_a_letat_note.dart';
import './step/la_piste_du_micro_est_desactivee.dart';
import './step/la_capture_du_micro_nest_pas_arretee.dart';
import './step/la_piste_du_micro_est_active.dart';
import './step/le_tableau_de_la_release34_est_affiche.dart';
import './step/le_serveur_emet_linterruption_de_cause_correction_a_ms.dart';
import './step/le_serveur_emet_la_delegation_de_la_correction_a_ms.dart';
import './step/les_surfaces_affichees_sont.dart';

void main() {
  group('''Faire taire l'IA, couper le micro et corriger en vol''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await lesPolicesReellesDeLaSceneSontChargees(tester);
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackendAvecUneHorlogeVirtuelle(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeLeFauxBackendArreteEtLaSemantiqueLiberee(tester);
    }

    testWidgets('''S-09 Faire taire l'IA par le bouton''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
        await lorbeEstALetat(tester, 'parole');
        await jeCliqueSurLaCommande(tester, 'silence-button');
        await laPisteDistanteEstCoupee(tester);
        await lorbeEstALetat(tester, 'Interrompue');
        await laSessionResteOuverte(tester);
        await leServeurEmetUnNiveauDorbeDe(tester, '0');
        await secondesSecoulentSansParoleDeLia(tester, 3);
        await lorbeEstALetat(tester, 'Écoute');
        await laPisteDistanteEstRetablie(tester);
        await laSessionResteOuverte(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['S-09', 'FR-20', 'NFR-12']);
    testWidgets('''S-09 Faire taire l'IA par la touche Échap''', (
      tester,
    ) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
        await lorbeEstALetat(tester, 'parole');
        await jappuieSurLaToucheEchap(tester);
        await laPisteDistanteEstCoupee(tester);
        await lorbeEstALetat(tester, 'Interrompue');
        await laSessionResteOuverte(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['S-09', 'FR-20', 'NFR-12']);
    testWidgets('''M-01 Couper puis rétablir le micro''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await jeNoteLetatDeLorbe(tester);
        await jeCliqueSurLaCommande(tester, 'mic-button');
        await leVoileEstAffiche(tester, 'Micro coupé');
        await laSessionResteOuverte(tester);
        await jeCliqueSurLaCommande(tester, 'mic-button');
        await leVoileNestPlusAffiche(tester, 'Micro coupé');
        await lorbeEstRevenuALetatNote(tester);
        await laSessionResteOuverte(tester);
      } finally {
        await bddTearDown(tester);
      }
    }, tags: ['FR-12', 'NFR-12']);
    testWidgets(
      '''M-02 Micro coupé, la piste est désactivée sans arrêter la capture''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await uneSessionVoixDemarree(tester);
          await jeCliqueSurLaCommande(tester, 'mic-button');
          await laPisteDuMicroEstDesactivee(tester);
          await laCaptureDuMicroNestPasArretee(tester);
          await laSessionResteOuverte(tester);
          await jeCliqueSurLaCommande(tester, 'mic-button');
          await laPisteDuMicroEstActive(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['FR-12'],
    );
    testWidgets(
      '''S-07 Une correction rend la parole à l'IA dès la réponse à la correction''',
      (tester) async {
        try {
          await bddSetUp(tester);
          await leTableauDeLaRelease34EstAffiche(tester);
          await leServeurEmetUnNiveauDorbeDe(tester, '0.4');
          await leServeurEmetLinterruptionDeCauseCorrectionAMs(tester, 2500);
          await lorbeEstALetat(tester, 'Interrompue');
          await laPisteDistanteEstCoupee(tester);
          await leServeurEmetUnNiveauDorbeDe(tester, '0');
          await leServeurEmetLaDelegationDeLaCorrectionAMs(tester, 4000);
          await lorbeEstALetat(tester, 'Écoute');
          await laPisteDistanteEstRetablie(tester);
          await lesSurfacesAfficheesSont(tester, 'kpi,trend,reviews,checklist');
        } finally {
          await bddTearDown(tester);
        }
      },
      tags: ['S-07', 'FR-14', 'FR-17'],
    );
  });
}
