import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: la surface {'trend'} affiche {'Taux de crash du jour'}
Future<void> laSurfaceAffiche(
  WidgetTester tester,
  String surface,
  String text,
) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface(surface)),
      matching: find.textContaining(text),
    ),
    'la surface $surface doit afficher « $text »',
  );
}
