import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/design_harness.dart';

/// Usage: aucun libellé de la surface {'checklist'} n'est tronqué
///
/// Aucun paragraphe de la cellule n'atteint son `maxLines` (polices réelles) ;
/// les libellés de crash (une ligne puis ellipse, pdr-0074 D10) sont exclus par
/// l'utilitaire.
Future<void> aucunLibelleDeLaSurfaceNestTronque(
  WidgetTester tester,
  String surface,
) async {
  final cell = DesignHarness.surface(surface);
  expect(cell, findsOneWidget, reason: 'la surface $surface est absente');
  expect(
    paragraphsTruncated(tester, root: cell),
    isEmpty,
    reason: 'libellés tronqués dans la surface $surface',
  );
}
