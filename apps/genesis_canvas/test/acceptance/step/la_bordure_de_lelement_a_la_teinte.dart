import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_palette.dart';

import 'package:flutter/painting.dart';

/// Usage: la bordure de l'élément {'agent-tile-Orchestrateur'} a la teinte {'plasma'}
Future<void> laBordureDeLelementALaTeinte(
  WidgetTester tester,
  String element,
  String color,
) async {
  final Color? border = Fidelity.borderColorOf(Fidelity.one(element));
  expect(border, isNotNull, reason: "« $element » n'a pas de bordure");
  expect(
    Fidelity.sameTint(border!, ScenePalette.named(color)),
    isTrue,
    reason:
        "bordure de « $element » : ${ScenePalette.describe(border)}, teinte attendue $color",
  );
}
