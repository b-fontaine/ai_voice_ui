import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taille minimale de texte de la scène (RG-09, NFR-05).
const double minSceneFontSize = 24;

/// Les paragraphes de texte rendus sous [root] (toute l'arborescence si
/// `null`) dont la taille est inférieure à [minSceneFontSize], décrits par
/// leur texte et leur taille. Les glyphes d'icônes (police d'icônes) et le
/// texte peint à la main par un `CustomPainter` n'en font pas partie.
List<String> paragraphsBelowMinimum(WidgetTester tester, {Finder? root}) {
  final Finder paragraphs = root == null
      ? find.byType(RichText)
      : find.descendant(of: root, matching: find.byType(RichText));
  final List<String> small = <String>[];
  for (final RenderParagraph paragraph
      in tester.renderObjectList<RenderParagraph>(paragraphs)) {
    final InlineSpan span = paragraph.text;
    final TextStyle? style = span.style;
    if (style?.fontFamily == 'MaterialIcons') continue;
    final double? size = style?.fontSize;
    if (size == null || size < minSceneFontSize) {
      small.add('« ${span.toPlainText()} » : $size px');
    }
  }
  return small;
}
