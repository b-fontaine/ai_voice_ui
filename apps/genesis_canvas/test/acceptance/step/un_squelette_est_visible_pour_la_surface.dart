import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: un squelette est visible pour la surface {'actions'}
Future<void> unSqueletteEstVisiblePourLaSurface(
  WidgetTester tester,
  String surface,
) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface(surface)),
      matching: find.byKey(AcceptanceKeys.skeleton(surface)),
    ),
    'un squelette (skeleton-$surface) doit être visible pour la surface $surface',
  );
}
