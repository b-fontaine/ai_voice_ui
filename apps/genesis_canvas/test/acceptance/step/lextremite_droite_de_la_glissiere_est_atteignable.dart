import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/replay_bar_harness.dart';

/// Usage: l'extrémité droite de la glissière est atteignable
///
/// La glissière ne positionne qu'au relâchement : ses deux extrémités doivent
/// recevoir le clic, pas seulement son centre.
Future<void> lextremiteDroiteDeLaGlissiereEstAtteignable(
  WidgetTester tester,
) async {
  final rect = tester.getRect(find.byKey(ReplayKeys.slider));
  ReplayBarHarness.expectHit(
    tester,
    ReplayKeys.slider,
    rect.centerRight - const Offset(2, 0),
  );
  ReplayBarHarness.expectHit(
    tester,
    ReplayKeys.slider,
    rect.centerLeft + const Offset(2, 0),
  );
}
