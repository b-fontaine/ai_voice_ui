// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/lapp_lancee_sans_scenario.dart';
import './step/le_canevas_est_vide.dart';
import './step/lorbe_est_visible.dart';
import './step/lapp_lancee_avec_le_scenario.dart';
import './step/le_rejeu_se_termine.dart';
import './step/une_surface_affiche_le_texte.dart';
import './step/la_valeur_liee_au_modele_de_donnees_est_affichee.dart';
import './step/lapp_lancee_avec_genesis_snapshot_vers_un_fichier_temporaire.dart';
import './step/un_png_non_vide_est_ecrit_a_ce_chemin.dart';
import './step/lapp_se_ferme_avec_le_code0.dart';

void main() {
  group('''Outillage de boucle dans l'app''', () {
    testWidgets('''H-01 Canevas vide, orbe visible''', (tester) async {
      await lappLanceeSansScenario(tester);
      await leCanevasEstVide(tester);
      await lorbeEstVisible(tester);
    });
    testWidgets('''H-02 Rejeu act1-replay et surface''', (tester) async {
      await lappLanceeAvecLeScenario(tester, 'act1-replay');
      await leRejeuSeTermine(tester);
      await uneSurfaceAfficheLeTexte(tester, 'Sessions sans crash');
      await laValeurLieeAuModeleDeDonneesEstAffichee(tester);
    });
    testWidgets('''H-03 Capture PNG puis sortie 0''', (tester) async {
      await lappLanceeAvecGenesisSnapshotVersUnFichierTemporaire(tester);
      await leRejeuSeTermine(tester);
      await unPngNonVideEstEcritACeChemin(tester);
      await lappSeFermeAvecLeCode0(tester);
    });
  });
}
