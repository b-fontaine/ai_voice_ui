import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';
import 'la_ligne_de_comparaison_de_la_surface_affiche.dart';
import 'la_surface_affiche.dart';

/// Usage: une comparaison avec la 3.3 apparaît
///
/// Ligne de comparaison du KPI et des avis, deux séries nommées dans la courbe,
/// valeurs de la 3.3 dans la checklist et recommandation NO-GO Android.
Future<void> uneComparaisonAvecLa33Apparait(WidgetTester tester) async {
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
  expect(
    trendSeriesNames(tester),
    <String>['Android 3.4', 'Android 3.3'],
    reason:
        'deux séries nommées attendues dans la courbe '
        '(entrées de légende trend-series-<nom>)',
  );
  await laSurfaceAffiche(tester, 'checklist', '3.3 : 99,71 %');
  await laSurfaceAffiche(tester, 'checklist', '3.3 : 14 %');
  await laSurfaceAffiche(tester, 'checklist', 'NO-GO Android');
}
