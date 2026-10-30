import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';

/// Usage: les boutons de la Barre d'actions ont un texte d'au moins {24} px et une cible d'au moins {48} px
///
/// Lisibilité à la distance d'une salle (NFR-03) et cible tactile : le corps
/// du texte (taille résolue du paragraphe) et la boîte du bouton.
Future<void>
lesBoutonsDeLaBarreDactionsOntUnTexteDauMoinsPxEtUneCibleDauMoinsPx(
  WidgetTester tester,
  num minText,
  num minTarget,
) async {
  for (final button in Acte3Harness.buttons()) {
    expect(button, findsOneWidget, reason: 'bouton absent de la barre');
    final size = tester.getSize(button);
    expect(
      size.width >= minTarget && size.height >= minTarget,
      isTrue,
      reason: 'cible de $size, attendue d\'au moins $minTarget px',
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: button, matching: find.byType(RichText)).first,
    );
    expect(
      paragraph.text.style?.fontSize ?? 0,
      greaterThanOrEqualTo(minText),
      reason: 'texte du bouton trop petit',
    );
  }
}
