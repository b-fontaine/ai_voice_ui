import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

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
      // Les étiquettes s'affichent en capitales (pdr-0088 F6) : la casse de
      // la donnée n'est pas ce qu'on observe.
      matching: findTextContainingIgnoringCase(text),
    ),
    'la surface $surface doit afficher « $text »',
  );
}
