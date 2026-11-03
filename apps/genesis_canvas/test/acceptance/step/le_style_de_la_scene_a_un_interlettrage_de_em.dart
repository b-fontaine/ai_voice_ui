import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

import 'package:flutter/painting.dart';

/// Usage: le style {'label'} de la scène a un interlettrage de {'0.14'} em
Future<void> leStyleDeLaSceneAUnInterlettrageDeEm(
  WidgetTester tester,
  String name,
  String em,
) async {
  final TextStyle style = Fidelity.sceneStyle(tester, name);
  Fidelity.expectNear(
    style.letterSpacing ?? 0,
    double.parse(em) * (style.fontSize ?? 0),
    0.01,
    what: "interlettrage du style « $name » ($em em)",
  );
}
