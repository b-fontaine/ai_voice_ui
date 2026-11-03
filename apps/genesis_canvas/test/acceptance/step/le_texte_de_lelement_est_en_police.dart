import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_style_harness.dart';

/// Usage: le texte de l'élément {'protocol-entry-0-no'} est en police {'JetBrains Mono'}
Future<void> leTexteDeLelementEstEnPolice(
  WidgetTester tester,
  String element,
  String family,
) async {
  final String? actual = SceneStyleHarness.bareFamily(
    Fidelity.styleOf(tester, element).fontFamily,
  );
  expect(actual, family, reason: "police du texte de « $element »");
}
