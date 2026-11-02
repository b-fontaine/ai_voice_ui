import 'dart:ui' show Color;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../../support/contrast.dart';
import '../support/scene_palette.dart';
import '../support/scene_style_harness.dart';

/// Usage: le contraste du mot de chaque statut sur son fond composé est d'au moins {4.5}
///
/// Les statuts absents de l'écran ne sont pas jugés (à l'acte 1, aucune puce
/// « blocking » n'existe). Le fond réel de chaque puce affichée (le `*-ghost` translucide) est composé
/// par `Color.alphaBlend` sur `surface-100`, `surface-200` puis `surface-300`,
/// les trois fonds sur lesquels une puce se pose ; le mot doit atteindre le
/// seuil sur chacun.
Future<void> leContrasteDuMotDeChaqueStatutSurSonFondComposeEstDauMoins(
  WidgetTester tester,
  num minimum,
) async {
  final List<String> failures = <String>[];
  var checked = 0;
  for (final SceneStatus status in SceneStatus.values) {
    final Finder chips = SceneStyleHarness.chips(status);
    checked += chips.evaluate().length;
    for (var i = 0; i < chips.evaluate().length; i++) {
      final Finder chip = chips.at(i);
      final String label = tester.widget<DsStatusChip>(chip).label;
      final Color word = SceneStyleHarness.wordColor(tester, chip, label);
      final List<Color> fills = SceneStyleHarness.fills(chip);
      expect(fills, isNotEmpty, reason: 'puce « $label » sans fond');
      for (final Color base in ScenePalette.chipBases) {
        final Color composed = Color.alphaBlend(fills.last, base);
        final double ratio = contrast(word, composed);
        if (ratio < minimum) {
          failures.add(
            '« $label » (${status.name}) sur ${ScenePalette.describe(base)} : '
            '${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    }
  }
  expect(
    checked,
    greaterThan(0),
    reason: "aucune puce de statut n'est affichée",
  );
  expect(
    failures,
    isEmpty,
    reason: 'contraste inférieur à $minimum :\n${failures.join('\n')}',
  );
}
