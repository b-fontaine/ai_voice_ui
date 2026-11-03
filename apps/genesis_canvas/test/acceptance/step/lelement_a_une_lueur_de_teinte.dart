import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_palette.dart';

import 'package:flutter/painting.dart';

/// Usage: l'élément {'shelf-ActionBar'} a une lueur de teinte {'signal'}
Future<void> lelementAUneLueurDeTeinte(
  WidgetTester tester,
  String element,
  String color,
) async {
  final Color expected = ScenePalette.named(color);
  final List<BoxShadow> shadows = Fidelity.shadowsOf(Fidelity.one(element));
  expect(
    shadows.any(
      (BoxShadow s) => s.color.a > 0 && Fidelity.sameTint(s.color, expected),
    ),
    isTrue,
    reason:
        "« $element » doit avoir une lueur $color (BoxDecoration.boxShadow) : ${shadows.map((BoxShadow s) => ScenePalette.describe(s.color)).toList()}",
  );
}
