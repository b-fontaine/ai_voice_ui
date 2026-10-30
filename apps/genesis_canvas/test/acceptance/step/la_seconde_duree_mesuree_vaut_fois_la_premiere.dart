import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: la seconde durée mesurée vaut {8} fois la première
///
/// À un pas de lecteur de quantification près, multiplié par le rapport.
Future<void> laSecondeDureeMesureeVautFoisLaPremiere(
  WidgetTester tester,
  num ratio,
) async {
  final durations = Acte4Harness.durations;
  expect(durations.length, greaterThanOrEqualTo(2), reason: 'deux mesures');
  final expected = durations[0].inMilliseconds * ratio;
  final tolerance = Acte4Harness.tick.inMilliseconds * (ratio + 1);
  expect(
    durations[1].inMilliseconds,
    closeTo(expected, tolerance),
    reason:
        'durées mesurées : $durations (la durée est proportionnelle à 1/vitesse)',
  );
}
