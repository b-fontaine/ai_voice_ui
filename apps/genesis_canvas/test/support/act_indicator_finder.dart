import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trouve le `Semantics` du bouton `act-indicator` dont le libellé contient
/// [text] (sans tenir compte de la casse).
///
/// Lit les propriétés du widget : pas besoin d'activer la sémantique.
Finder findActIndicatorLabel(String text) {
  final String wanted = text.toLowerCase();
  return find.ancestor(
    of: find.byKey(const Key('act-indicator')),
    matching: find.byWidgetPredicate(
      (Widget w) =>
          w is Semantics &&
          (w.properties.label ?? '').toLowerCase().contains(wanted),
    ),
  );
}
