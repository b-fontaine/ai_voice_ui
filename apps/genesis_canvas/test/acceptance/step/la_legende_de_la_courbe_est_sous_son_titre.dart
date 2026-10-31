import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';
import '../support/design_harness.dart';
import '../support/keys.dart';
import 'le_titre_de_la_courbe_nest_pas_tronque.dart' show trendTitle;

/// Usage: la légende de la courbe est sous son titre
///
/// Chaque entrée de légende (`trend-series-<nom>`) commence sous le bas du
/// titre : la légende passe à la ligne quand la place manque (A3).
Future<void> laLegendeDeLaCourbeEstSousSonTitre(WidgetTester tester) async {
  final title = tester.getRect(
    find.descendant(
      of: DesignHarness.surface('trend'),
      matching: find.text(trendTitle),
    ),
  );
  final names = trendSeriesNames(tester);
  expect(names, isNotEmpty, reason: 'aucune entrée de légende dans la courbe');
  for (final name in names) {
    final entry = tester.getRect(find.byKey(AcceptanceKeys.trendSeries(name)));
    expect(
      entry.top,
      greaterThanOrEqualTo(title.bottom - 0.5),
      reason:
          'la légende « $name » (haut ${entry.top}) doit être sous le titre '
          '(bas ${title.bottom})',
    );
  }
}
