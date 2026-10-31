import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: le texte de la liste des crashs fait au moins {24} px
///
/// Lisibilité à la distance d'une salle (NFR-03) : taille résolue de chaque
/// paragraphe de la cellule `surface-crashes`.
Future<void> leTexteDeLaListeDesCrashsFaitAuMoinsPx(
  WidgetTester tester,
  num minText,
) async {
  final paragraphs = find.descendant(
    of: find.byKey(AcceptanceKeys.surface('crashes')),
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsWidgets, reason: 'aucun texte dans la liste');
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.text.style?.fontSize ?? 0,
      greaterThanOrEqualTo(minText),
      reason: 'texte trop petit : « ${paragraph.text.toPlainText()} »',
    );
  }
}
