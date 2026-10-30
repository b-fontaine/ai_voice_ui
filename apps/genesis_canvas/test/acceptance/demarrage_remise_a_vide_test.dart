// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/lapp_est_fermee_et_le_faux_backend_arrete.dart';
import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend.dart';
import './step/le_faux_backend_a_recu_une_requete_de_remise_a_vide_au_demarrage.dart';
import './step/aucune_session_voix_na_ete_creee.dart';
import './step/je_clique_sur_demarrer.dart';
import './step/le_relais_a_recu_loffre_du_transport.dart';
import './step/la_remise_a_vide_precede_la_premiere_session.dart';
import './step/le_faux_backend_a_recu_exactement_une_requete_de_remise_a_vide.dart';
import './step/lapp_lancee_en_rejeu_sur_ce_backend.dart';
import './step/le_rejeu_est_joue.dart';
import './step/le_faux_backend_na_recu_aucune_requete_de_remise_a_vide.dart';

void main() {
  group('''Démarrage de l'app - remise à vide du canevas du backend''', () {
    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeEtLeFauxBackendArrete(tester);
    }

    testWidgets(
      '''A3 En mode vivant, l'app vide le canevas du backend avant la première session''',
      (tester) async {
        try {
          await unFauxBackendLocal(tester);
          await lappLanceeSurCeBackend(tester);
          await leFauxBackendARecuUneRequeteDeRemiseAVideAuDemarrage(tester);
          await aucuneSessionVoixNaEteCreee(tester);
          await jeCliqueSurDemarrer(tester);
          await leRelaisARecuLoffreDuTransport(tester);
          await laRemiseAVidePrecedeLaPremiereSession(tester);
          await leFauxBackendARecuExactementUneRequeteDeRemiseAVide(tester);
        } finally {
          await bddTearDown(tester);
        }
      },
    );
    testWidgets('''A3 En mode rejeu, l'app ne demande aucune remise à vide''', (
      tester,
    ) async {
      try {
        await unFauxBackendLocal(tester);
        await lappLanceeEnRejeuSurCeBackend(tester, 'act1-replay');
        await leRejeuEstJoue(tester);
        await leFauxBackendNaRecuAucuneRequeteDeRemiseAVide(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
  });
}
