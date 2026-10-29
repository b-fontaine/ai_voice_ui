// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/un_faux_backend_local.dart';
import './step/lapp_lancee_sur_ce_backend.dart';
import './step/lapp_est_fermee_et_le_faux_backend_arrete.dart';
import './step/une_session_voix_demarree.dart';
import './step/le_serveur_emet_la_phrase_du_speaker_et_la_delegation.dart';
import './step/la_ligne_de_la_transcription_affiche.dart';
import './step/le_serveur_emet_lagent_qualite_au_travail.dart';
import './step/lagent_est_affiche.dart';
import './step/le_serveur_emet_les_trois_temps_de_la_surface.dart';
import './step/une_surface_affiche_le_texte.dart';
import './step/la_valeur_liee_au_modele_de_donnees_est_affichee.dart';
import './step/le_serveur_emet_la_fin_de_lactivite_de_lagent_qualite.dart';
import './step/le_serveur_emet_un_niveau_dorbe_de.dart';
import './step/le_niveau_lisse_de_lorbe_monte.dart';
import './step/le_niveau_lisse_de_lorbe_retombe_a_zero.dart';
import './step/lorbe_est_au_repos.dart';
import './step/je_clique_sur_demarrer.dart';
import './step/le_relais_a_recu_loffre_du_transport.dart';
import './step/le_transport_a_applique_lanswer_du_relais.dart';
import './step/lapp_ouvre_ensuite_le_canal_temps_reel_de_cette_session.dart';
import './step/le_bouton_arreter_est_affiche.dart';
import './step/je_clique_sur_arreter.dart';
import './step/le_relais_a_recu_un_delete_de_cette_session.dart';
import './step/le_transport_est_libere_dans_lordre_apres_le_delete.dart';
import './step/le_bouton_demarrer_est_affiche.dart';
import './step/deux_transports_distincts_ont_ete_crees.dart';
import './step/le_relais_a_recu_une_offre_par_transport.dart';
import './step/la_session_active_est_la_seconde_du_relais.dart';
import './step/je_clique_deux_fois_sur_demarrer.dart';
import './step/une_session_voix_est_active.dart';
import './step/un_seul_transport_a_ete_cree.dart';
import './step/le_relais_a_recu_une_seule_offre.dart';
import './step/le_faux_backend_en_mode.dart';
import './step/le_message_detat_contient.dart';
import './step/le_transport_est_libere.dart';
import './step/le_faux_backend_redevient_joignable.dart';
import './step/aucun_message_detat_nest_affiche.dart';
import './step/le_serveur_a_emis_toute_la_session_enregistree.dart';
import './step/la_connexion_temps_reel_est_coupee_par_le_reseau.dart';
import './step/le_backend_ferme_la_session_pour_la_raison.dart';
import './step/le_relais_na_recu_aucun_delete.dart';

void main() {
  group('''Session voix, orbe et rendu du flux vivant''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await unFauxBackendLocal(tester);
      await lappLanceeSurCeBackend(tester);
    }

    Future<void> bddTearDown(WidgetTester tester) async {
      await lappEstFermeeEtLeFauxBackendArrete(tester);
    }

    testWidgets('''V1 Une phrase donne une surface''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetLaPhraseDuSpeakerEtLaDelegation(tester);
        await laLigneDeLaTranscriptionAffiche(
          tester,
          'user',
          'Prépare la release 3.4',
        );
        await leServeurEmetLagentQualiteAuTravail(tester);
        await lagentEstAffiche(tester, 'Qualité', 'en cours');
        await leServeurEmetLesTroisTempsDeLaSurface(tester);
        await uneSurfaceAfficheLeTexte(tester, 'Sessions sans crash');
        await laValeurLieeAuModeleDeDonneesEstAffichee(tester);
        await leServeurEmetLaFinDeLactiviteDeLagentQualite(tester);
        await lagentEstAffiche(tester, 'Qualité', 'terminé');
        await laLigneDeLaTranscriptionAffiche(
          tester,
          'ai',
          'analyse de la release',
        );
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V2 L'orbe suit la voix''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurEmetUnNiveauDorbeDe(tester, '0.1');
        await leNiveauLisseDeLorbeMonte(tester);
        await leServeurEmetUnNiveauDorbeDe(tester, '0');
        await leNiveauLisseDeLorbeRetombeAZero(tester);
        await lorbeEstAuRepos(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V3 L'offre part au relais''', (tester) async {
      try {
        await bddSetUp(tester);
        await jeCliqueSurDemarrer(tester);
        await leRelaisARecuLoffreDuTransport(tester);
        await leTransportAAppliqueLanswerDuRelais(tester);
        await lappOuvreEnsuiteLeCanalTempsReelDeCetteSession(tester);
        await leBoutonArreterEstAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V3 Arrêter libère la session''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await jeCliqueSurArreter(tester);
        await leRelaisARecuUnDeleteDeCetteSession(tester);
        await leTransportEstLibereDansLordreApresLeDelete(tester);
        await leBoutonDemarrerEstAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V3 Redémarrer ouvre un transport neuf''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await jeCliqueSurArreter(tester);
        await jeCliqueSurDemarrer(tester);
        await deuxTransportsDistinctsOntEteCrees(tester);
        await leRelaisARecuUneOffreParTransport(tester);
        await laSessionActiveEstLaSecondeDuRelais(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V3 Un double Démarrer, une session''', (tester) async {
      try {
        await bddSetUp(tester);
        await jeCliqueDeuxFoisSurDemarrer(tester);
        await uneSessionVoixEstActive(tester);
        await unSeulTransportAEteCree(tester);
        await leRelaisARecuUneSeuleOffre(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V4 Backend injoignable''', (tester) async {
      try {
        await bddSetUp(tester);
        await leFauxBackendEnMode(tester, 'unreachable');
        await jeCliqueSurDemarrer(tester);
        await leMessageDetatContient(tester, 'injoignable');
        await lorbeEstAuRepos(tester);
        await leTransportEstLibere(tester);
        await leBoutonDemarrerEstAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V4 Relais saturé (429)''', (tester) async {
      try {
        await bddSetUp(tester);
        await leFauxBackendEnMode(tester, 'rate-limited');
        await jeCliqueSurDemarrer(tester);
        await leMessageDetatContient(tester, 'Trop de demandes');
        await lorbeEstAuRepos(tester);
        await leTransportEstLibere(tester);
        await leBoutonDemarrerEstAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V4 Relais en erreur (502)''', (tester) async {
      try {
        await bddSetUp(tester);
        await leFauxBackendEnMode(tester, 'bad-gateway');
        await jeCliqueSurDemarrer(tester);
        await leMessageDetatContient(tester, 'relais');
        await lorbeEstAuRepos(tester);
        await leTransportEstLibere(tester);
        await leBoutonDemarrerEstAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V4 Nouvel essai après un échec''', (tester) async {
      try {
        await bddSetUp(tester);
        await leFauxBackendEnMode(tester, 'unreachable');
        await jeCliqueSurDemarrer(tester);
        await leMessageDetatContient(tester, 'injoignable');
        await leFauxBackendRedevientJoignable(tester);
        await jeCliqueSurDemarrer(tester);
        await uneSessionVoixEstActive(tester);
        await aucunMessageDetatNestAffiche(tester);
        await deuxTransportsDistinctsOntEteCrees(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V5 Connexion perdue en pleine session''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leServeurAEmisTouteLaSessionEnregistree(tester);
        await laConnexionTempsReelEstCoupeeParLeReseau(tester);
        await leMessageDetatContient(tester, 'Connexion perdue');
        await uneSurfaceAfficheLeTexte(tester, 'Sessions sans crash');
        await leRelaisARecuUnDeleteDeCetteSession(tester);
        await leTransportEstLibere(tester);
        await lorbeEstAuRepos(tester);
        await leBoutonDemarrerEstAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
    testWidgets('''V5bis Fermeture décidée par le backend''', (tester) async {
      try {
        await bddSetUp(tester);
        await uneSessionVoixDemarree(tester);
        await leBackendFermeLaSessionPourLaRaison(tester, 'expired');
        await leMessageDetatContient(tester, 'expirée');
        await leTransportEstLibere(tester);
        await leRelaisNaRecuAucunDelete(tester);
        await leBoutonDemarrerEstAffiche(tester);
      } finally {
        await bddTearDown(tester);
      }
    });
  });
}
