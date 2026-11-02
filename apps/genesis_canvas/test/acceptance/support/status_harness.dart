import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import 'scene_palette.dart';
import 'scene_style_harness.dart';

/// Vérifications d'une puce de statut (U-04, RG-09) : le mot, la couleur du
/// design system, le fond `*-ghost`, le glyphe éventuel.
abstract final class StatusHarness {
  /// Statut du contrat (`ok`, `risk`, `blocking`) ; erreur de test sinon.
  static SceneStatus status(String code) {
    final SceneStatus? status = SceneStatus.fromCode(code);
    if (status == null) throw ArgumentError('statut inconnu « $code »');
    return status;
  }

  /// Vérifie toutes les puces de [code] : mot affiché, couleur du mot
  /// [foreground], fond [background] et glyphe [glyph] (`null` : aucun texte
  /// autre que le mot).
  static void expectChips(
    WidgetTester tester, {
    required String code,
    required String foreground,
    required String background,
    required String? glyph,
  }) {
    final Finder chips = SceneStyleHarness.chips(status(code));
    expect(
      chips,
      findsWidgets,
      reason: 'aucune puce de statut « $code » affichée',
    );
    final Color expectedFg = ScenePalette.named(foreground);
    final Color expectedBg = ScenePalette.named(background);
    for (var i = 0; i < chips.evaluate().length; i++) {
      final Finder chip = chips.at(i);
      final String label = tester.widget<DsStatusChip>(chip).label;
      expect(label.trim(), isNotEmpty, reason: 'puce « $code » sans mot');

      final Color fg = SceneStyleHarness.wordColor(tester, chip, label);
      expect(
        ScenePalette.sameColor(fg, expectedFg),
        isTrue,
        reason:
            'mot « $label » (statut $code) : couleur '
            '${ScenePalette.describe(fg)}, attendue $foreground '
            '${ScenePalette.describe(expectedFg)}',
      );

      final List<Color> fills = SceneStyleHarness.fills(chip);
      expect(
        fills.any((Color c) => ScenePalette.sameColor(c, expectedBg)),
        isTrue,
        reason:
            'puce « $label » (statut $code) : fonds '
            '${fills.map(ScenePalette.describe).toList()}, attendu '
            '$background ${ScenePalette.describe(expectedBg)}',
      );

      final List<String> texts = <String>[
        for (final Element e
            in find
                .descendant(of: chip, matching: find.byType(Text))
                .evaluate())
          (e.widget as Text).data ?? (e.widget as Text).textSpan!.toPlainText(),
      ];
      if (glyph == null) {
        expect(texts, <String>[
          label,
        ], reason: 'puce « $label » (statut $code) : seul le mot est attendu');
      } else {
        expect(
          texts,
          contains(glyph),
          reason: 'puce « $label » (statut $code) : glyphe « $glyph » absent',
        );
        expect(texts, contains(label), reason: 'le mot « $label » est absent');
      }
    }
  }
}
