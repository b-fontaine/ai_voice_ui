import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'voice-orb-ring-0'} est animé
Future<void> lelementEstAnime(WidgetTester tester, String element) async {
  expect(
    await Fidelity.repaints(tester, element),
    isTrue,
    reason: "l'élément « $element » devrait se repeindre (animation en cours)",
  );
}
