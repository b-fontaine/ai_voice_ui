import 'package:flutter_test/flutter_test.dart';

import '../../support/paragraphs.dart';

/// Usage: tout texte visible de l'écran fait au moins {24} px
///
/// Parcourt tous les paragraphes rendus (`Text` et `RichText`, `Material`
/// compris) hors `Offstage` : les fautifs sont listés dans le message d'échec.
/// Le texte peint à la main par un `CustomPainter` n'est pas un paragraphe.
Future<void> toutTexteVisibleDeLecranFaitAuMoinsPx(
  WidgetTester tester,
  num size,
) async {
  expect(size, minSceneFontSize, reason: 'seuil de la scène : RG-09, NFR-05');
  final List<String> small = paragraphsBelowMinimum(tester);
  expect(
    small,
    isEmpty,
    reason: 'textes visibles de moins de $size px :\n${small.join('\n')}',
  );
}
