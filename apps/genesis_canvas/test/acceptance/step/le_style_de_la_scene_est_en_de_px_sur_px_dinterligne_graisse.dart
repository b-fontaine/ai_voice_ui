import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_style_harness.dart';

import 'package:flutter/painting.dart';

/// Usage: le style {'body'} de la scène est en {'Space Grotesk'} de {15} px sur {22} px d'interligne, graisse {400}
Future<void> leStyleDeLaSceneEstEnDePxSurPxDinterligneGraisse(
  WidgetTester tester,
  String name,
  String family,
  num size,
  num lineHeight,
  num weight,
) async {
  final TextStyle style = Fidelity.sceneStyle(tester, name);
  expect(style.fontSize, size, reason: "taille du style « $name »");
  Fidelity.expectNear(
    (style.height ?? 0) * (style.fontSize ?? 0),
    lineHeight,
    0.6,
    what: "interligne du style « $name »",
  );
  expect(
    style.fontWeight?.value ?? 400,
    weight,
    reason: "graisse du style « $name »",
  );
  expect(
    SceneStyleHarness.bareFamily(style.fontFamily),
    family,
    reason: "famille du style « $name »",
  );
}
