import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_palette.dart';

import 'package:flutter/painting.dart';

/// Usage: le texte de l'élément {'protocol-entry-0-kind'} est de couleur {'signal'}
Future<void> leTexteDeLelementEstDeCouleur(
  WidgetTester tester,
  String element,
  String color,
) async {
  final Color? actual = Fidelity.styleOf(tester, element).color;
  expect(actual, isNotNull, reason: "texte de « $element » sans couleur");
  expect(
    ScenePalette.sameColor(actual!, ScenePalette.named(color)),
    isTrue,
    reason:
        "couleur du texte de « $element » : ${ScenePalette.describe(actual)}, attendue $color",
  );
}
