import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_palette.dart';

import 'package:flutter/painting.dart';

/// Usage: l'élément {'shelf-ActionBar'} n'a pas de lueur
Future<void> lelementNaPasDeLueur(WidgetTester tester, String element) async {
  final List<BoxShadow> shadows = Fidelity.shadowsOf(Fidelity.one(element));
  expect(
    shadows.where((BoxShadow s) => s.color.a > 0),
    isEmpty,
    reason:
        "« $element » ne devrait plus avoir de lueur : ${shadows.map((BoxShadow s) => ScenePalette.describe(s.color)).toList()}",
  );
}
