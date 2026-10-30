import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';
import '../support/session_harness.dart';
import '../support/keys.dart';

/// Usage: la courbe ne contient que la série {'iOS 3.4'}
///
/// Le chemin `/trend` est remplacé, pas fusionné : l'ancienne série disparaît.
Future<void> laCourbeNeContientQueLaSerie(
  WidgetTester tester,
  String series,
) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface('trend')),
      matching: find.byKey(AcceptanceKeys.trendSeries(series)),
    ),
    'la série « $series » est absente de la courbe '
    '(clé trend-series-$series)',
  );
  expect(trendSeriesNames(tester), <String>[
    series,
  ], reason: 'une seule série attendue dans la courbe');
}
