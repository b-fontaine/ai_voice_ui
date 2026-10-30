import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: les surfaces affichées sont {'kpi,trend,reviews,checklist'}
///
/// Ensemble exact des cellules du canevas (ordre indifférent).
Future<void> lesSurfacesAfficheesSont(
  WidgetTester tester,
  String surfaces,
) async {
  await tester.pump();
  expect(
    Acte4Harness.displayedSurfaces(),
    surfaces.split(',').map((s) => s.trim()).toSet(),
    reason: 'surfaces affichées dans le canevas',
  );
}
