import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_palette.dart';

import 'package:flutter/painting.dart';

/// Usage: l'élément {'replay-speed-1-visual'} est de couleur {'ink'}
Future<void> lelementEstDeCouleur(
  WidgetTester tester,
  String element,
  String color,
) async {
  final Color? actual = Fidelity.fillOf(Fidelity.one(element));
  expect(actual, isNotNull, reason: "« $element » n'a aucune couleur de fond");
  expect(
    ScenePalette.sameColor(actual!, ScenePalette.named(color)),
    isTrue,
    reason:
        "couleur de « $element » : ${ScenePalette.describe(actual)}, attendue $color ${ScenePalette.describe(ScenePalette.named(color))}",
  );
}
