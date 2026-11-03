import 'package:flutter_test/flutter_test.dart';

import '../../support/paragraphs.dart';
import '../support/design_harness.dart';

/// Usage: le texte de la surface {'reviews'} fait au moins {11} px
Future<void> leTexteDeLaSurfaceFaitAuMoinsPx(
  WidgetTester tester,
  String surface,
  num size,
) async {
  expect(
    size,
    minSceneFontSize,
    reason: 'seuil de la scène : 11 px (pdr-0087 / pdr-0088 F1)',
  );
  final cell = DesignHarness.surface(surface);
  expect(cell, findsOneWidget, reason: 'la surface $surface est absente');
  expect(
    paragraphsBelowMinimum(tester, root: cell),
    isEmpty,
    reason: 'texte de moins de $size px dans la surface $surface',
  );
}
