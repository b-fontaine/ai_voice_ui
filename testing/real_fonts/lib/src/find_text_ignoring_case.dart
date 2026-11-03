import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cherche un widget [Text] dont le contenu égale [text] à la casse près.
///
/// Le design system affiche en capitales les étiquettes, puces, en-têtes et
/// segments (`DsCaps`), alors que la donnée reste inchangée. Un test qui
/// cherche un libellé de ce genre utilise donc cet outil plutôt que
/// `find.text`, pour ne pas dépendre de la casse d'affichage. La chaîne doit
/// toujours correspondre en entier (comme `find.text`), seule la casse est
/// ignorée. Les chaînes de données (valeurs, noms de critères) restent
/// cherchées par `find.text`.
Finder findTextIgnoringCase(String text) {
  final String wanted = text.toLowerCase();
  return find.byWidgetPredicate(
    (Widget widget) => _shown(widget)?.toLowerCase() == wanted,
    description: 'Text "$text" (casse ignorée)',
  );
}

/// Variante de [findTextIgnoringCase] pour un contenu qui **contient** [text]
/// (comme `find.textContaining`), casse ignorée.
Finder findTextContainingIgnoringCase(String text) {
  final String wanted = text.toLowerCase();
  return find.byWidgetPredicate(
    (Widget widget) => _shown(widget)?.toLowerCase().contains(wanted) ?? false,
    description: 'Text contenant "$text" (casse ignorée)',
  );
}

String? _shown(Widget widget) {
  if (widget is! Text) {
    return null;
  }
  return widget.data ?? widget.textSpan?.toPlainText();
}
