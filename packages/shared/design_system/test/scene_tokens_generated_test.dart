import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Forme du fichier généré (sans Node) : ombres constantes, aucune ombre
/// `inset`, nombres émis sans arrondi.
void main() {
  final source = File('lib/src/generated/scene_tokens.g.dart')
      .readAsStringSync();

  test('aucune ombre inset dans le fichier généré', () {
    expect(source.toLowerCase(), isNot(contains('inset')));
  });

  test('les ombres sont des List<BoxShadow> constantes', () {
    final shadows = RegExp(
      r'^\s*static (\w+) List<BoxShadow> (\w+) =',
      multiLine: true,
    ).allMatches(source).toList();
    expect(shadows.map((m) => m.group(2)), <String>[
      'shadowPanel',
      'shadowGlowSignal',
      'shadowGlowNogo',
      'shadowGlowPlasma',
      'shadowGlowPlasmaDot',
      'shadowTextGlowNogo',
    ]);
    for (final match in shadows) {
      expect(match.group(1), 'const', reason: match.group(2));
    }
    expect(source, contains("import 'package:flutter/painting.dart'"));
  });

  test('le flou CSS est converti sans arrondi (règle sigma = B / 2)', () {
    // 48 px de flou CSS : (48 / 2 - 0,5) / 0,57735, tous chiffres conservés.
    expect(source, contains('blurRadius: ${(48 / 2 - 0.5) / 0.57735}'));
    expect(source, contains('blurRadius: ${(28 / 2 - 0.5) / 0.57735}'));
  });

  test('les couleurs avec alpha sont émises en 0xAARRGGBB', () {
    expect(source, contains('colorOkBackground = Color(0x1C3EF2A5)'));
    expect(source, contains('colorOrbVeil = Color(0xB3424242)'));
    expect(source, contains('colorPanelHighlight = Color(0x08FFFFFF)'));
  });

  test('chaque graisse a sa variation wght jumelle, constante', () {
    final weights = RegExp(
      r'static const FontWeight (text\w+)FontWeight = FontWeight\.w(\d+);',
    ).allMatches(source).toList();
    expect(weights.length, greaterThanOrEqualTo(9));
    for (final match in weights) {
      expect(
        source,
        contains(
          RegExp(
            'static const List<FontVariation> ${match.group(1)}FontVariations'
            r' =\s*\[\s*FontVariation\(\s*.wght.,\s*'
            '${match.group(2)}.0,?\\s*\\),?\\s*\\];',
          ),
        ),
        reason: match.group(1),
      );
    }
  });

  test('les familles de texte et leur repli sont émises par style', () {
    expect(
      source,
      contains(
        RegExp(
          r"textValueFontFamily =\s*'packages/shared_design_system/JetBrains Mono'",
        ),
      ),
    );
    expect(source, contains('textValueLetterSpacing = -3.04'));
    expect(source, contains('textLabelLetterSpacing = 1.54'));
    expect(source, contains('textVerdictLetterSpacing = 1.12'));
    // 9 styles de texte et 15 micro-styles, chacun avec son repli.
    final textFallbacks = RegExp(r'text\w+FontFamilyFallback =');
    final microFallbacks = RegExp(r'micro\w+FontFamilyFallback =');
    expect(textFallbacks.allMatches(source).length, 9);
    expect(microFallbacks.allMatches(source).length, 15);
  });
}
