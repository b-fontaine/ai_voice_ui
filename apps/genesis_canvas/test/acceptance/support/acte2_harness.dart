import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

import 'keys.dart';

/// État partagé entre les étapes des scénarios de l'acte 2 (spec 008) : la
/// photographie du tableau de l'acte 1 (identité de rendu, positions) et le
/// journal d'erreurs de l'app.
class Acte2Harness {
  Acte2Harness._();

  /// Sortie d'erreurs de l'app (`errorSink`) : « Message A2UI refusé : <code> »
  /// à chaque refus du validateur.
  static StringBuffer errors = StringBuffer();

  /// `State` de la `Surface` de chaque surface, relevé quand le tableau de
  /// l'acte 1 est complet.
  static final Map<String, State> surfaceStates = <String, State>{};

  /// Position de chaque cellule, relevée au même moment.
  static final Map<String, Offset> surfacePositions = <String, Offset>{};

  /// Numéro de la délégation en cours, pour des identifiants uniques.
  static int delegations = 1;

  static void reset() {
    errors = StringBuffer();
    surfaceStates.clear();
    surfacePositions.clear();
    delegations = 1;
  }

  /// Le moteur de rendu (`Surface`) de la cellule [id].
  static Finder engineOf(String id) => find.descendant(
    of: find.byKey(AcceptanceKeys.surface(id)),
    matching: find.byType(Surface),
  );

  /// Relève l'état du rendu de chaque surface de l'acte 1.
  static void capture(WidgetTester tester) {
    surfaceStates.clear();
    surfacePositions.clear();
    for (final id in AcceptanceKeys.act1Surfaces) {
      surfaceStates[id] = tester.state<State>(engineOf(id));
      surfacePositions[id] = tester.getTopLeft(
        find.byKey(AcceptanceKeys.surface(id)),
      );
    }
  }

  /// Texte de la ligne de comparaison de la surface [id], ou `null` si absente.
  static Text? comparisonLine(WidgetTester tester, String id) {
    final line = find.descendant(
      of: find.byKey(AcceptanceKeys.surface(id)),
      matching: find.byKey(AcceptanceKeys.comparison(id)),
    );
    if (line.evaluate().isEmpty) return null;
    final text = find.descendant(
      of: line,
      matching: find.byType(Text),
      matchRoot: true,
    );
    return tester.widget<Text>(text.first);
  }
}

/// Noms des séries de la courbe, lus sur les entrées de légende
/// ([AcceptanceKeys.trendSeries]) de la surface `trend`.
List<String> trendSeriesNames(WidgetTester tester) {
  final entries = find.descendant(
    of: find.byKey(AcceptanceKeys.surface('trend')),
    matching: find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith(AcceptanceKeys.trendSeriesPrefix);
    }),
  );
  return entries
      .evaluate()
      .map((element) => (element.widget.key! as ValueKey<String>).value)
      .map((value) => value.substring(AcceptanceKeys.trendSeriesPrefix.length))
      .toList();
}
