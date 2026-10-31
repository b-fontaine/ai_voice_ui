import 'package:flutter_test/flutter_test.dart';

import '../acceptance/step/le_canevas_affiche_une_grille_de_colonnes_sur_lignes.dart';
import '../acceptance/step/le_rejeu_se_termine.dart';
import '../acceptance/step/les_surfaces_du_canevas_se_lisent_dans_lordre.dart';
import '../acceptance/step/letagere_affiche.dart';
import '../acceptance/step/la_surface_affiche.dart';
import '../acceptance/support/harness.dart';

/// Le scénario connu `crashlist-replay` (asset dérivé du contrat) rejoue
/// l'acte 1 puis la liste des crashs : c'est ce que `app-smoke.sh
/// crashlist-replay` capture en 1920 × 1080 (spec 012, T43).
void main() {
  testWidgets('crashlist-replay : la liste des crashs est la cinquième cellule '
      'de la grille 3 × 2, sans message refusé', (tester) async {
    await Harness.launch(tester, scenario: 'crashlist-replay');
    await leRejeuSeTermine(tester);

    await laSurfaceAffiche(tester, 'crashes', 'Principaux crashs · 3.4');
    await leCanevasAfficheUneGrilleDeColonnesSurLignes(tester, 3, 2);
    await lesSurfacesDuCanevasSeLisentDansLordre(
      tester,
      'kpi, trend, reviews, checklist, crashes',
    );
    await letagereAffiche(tester, '5 / 6 utilisés');
  });
}
