import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les paragraphes rendus sous [root] (toute l'arborescence si `null`) dont le
/// texte est tronqué (`RenderParagraph.didExceedMaxLines` : `maxLines` atteint,
/// avec ou sans ellipse), décrits par leur texte.
///
/// Les libellés de crash (clés `crash-label-*`) sont exclus : leur ligne
/// unique avec ellipse est voulue (pdr-0074 D10).
///
/// À utiliser avec les polices réelles ([loadRealFonts]) : avec Ahem, chaque
/// glyphe fait la taille de la police et la mesure n'a pas de sens.
List<String> paragraphsTruncated(WidgetTester tester, {Finder? root}) {
  final Finder paragraphs = root == null
      ? find.byType(RichText)
      : find.descendant(of: root, matching: find.byType(RichText));
  final List<String> truncated = <String>[];
  for (final Element element in paragraphs.evaluate()) {
    if (_insideCrashLabel(element)) continue;
    final RenderParagraph paragraph = element.renderObject! as RenderParagraph;
    if (paragraph.didExceedMaxLines) {
      truncated.add('« ${paragraph.text.toPlainText()} »');
    }
  }
  return truncated;
}

bool _insideCrashLabel(Element element) {
  var inside = false;
  element.visitAncestorElements((Element ancestor) {
    final Key? key = ancestor.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('crash-label-')) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}
