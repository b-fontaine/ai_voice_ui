import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Ligne de la table « Tailles de texte » du design system
/// (`product/sources/design-system-2026-11-02/tokens.json`, § type ; pdr-0087 :
/// plus de plancher de 24 px, pdr-0088 F1).
typedef _Row = ({
  TextStyle style,
  String family,
  double size,
  double height,
  int wght,
  double letterSpacingEm,
  Color color,
  bool tabular,
});

void main() {
  const theme = SceneTheme.dark();
  final rows = <String, _Row>{
    'value (kpi-xl)': (
      style: theme.value,
      family: SceneFonts.mono,
      size: 76,
      height: 1.0,
      wght: 600,
      letterSpacingEm: -0.04,
      color: theme.textPrimary,
      tabular: true,
    ),
    'verdict': (
      style: theme.verdict,
      family: SceneFonts.mono,
      size: 28,
      height: 32 / 28,
      wght: 700,
      letterSpacingEm: 0.04,
      color: theme.textPrimary,
      tabular: true,
    ),
    'data': (
      style: theme.data,
      family: SceneFonts.mono,
      size: 15,
      height: 20 / 15,
      wght: 500,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: true,
    ),
    'label': (
      style: theme.label,
      family: SceneFonts.mono,
      size: 11,
      height: 14 / 11,
      wght: 500,
      letterSpacingEm: 0.14,
      color: theme.textSecondary,
      tabular: false,
    ),
    'title': (
      style: theme.title,
      family: SceneFonts.sans,
      size: 18,
      height: 24 / 18,
      wght: 600,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
    'transcript': (
      style: theme.transcript,
      family: SceneFonts.sans,
      size: 20,
      height: 28 / 20,
      wght: 500,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
    'body': (
      style: theme.body,
      family: SceneFonts.sans,
      size: 15,
      height: 22 / 15,
      wght: 400,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
    'button': (
      style: theme.button,
      family: SceneFonts.sans,
      size: 15,
      height: 20 / 15,
      wght: 600,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
    'actIndicator': (
      style: theme.actIndicator,
      family: SceneFonts.sans,
      size: 28,
      height: 1.2,
      wght: 700,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
  };

  group('styles de SceneTheme : échelle de texte du design system (pdr-0087 / pdr-0088 F1)', () {
    rows.forEach((name, row) {
      group(name, () {
        final TextStyle style = row.style;
        test('taille, hauteur de ligne et couleur', () {
          expect(style.fontSize, row.size);
          // Plus de plancher de 24 px (pdr-0087 / pdr-0088 F1).
          expect(style.height, closeTo(row.height, 1e-12));
          expect(style.color, row.color);
        });
        test('famille de la table, repli DejaVu Sans', () {
          expect(style.fontFamily, row.family);
          expect(style.fontFamilyFallback, SceneFonts.fallbackList);
        });
        test('fontWeight et axe wght portent la même valeur (sceneWeight)', () {
          final SceneWeight weight = sceneWeight(row.wght);
          expect(style.fontWeight, weight.fontWeight);
          expect(style.fontVariations, weight.variations);
        });
        test('interlettrage en px = em x taille', () {
          expect(
            style.letterSpacing ?? 0,
            closeTo(row.letterSpacingEm * row.size, 1e-9),
          );
        });
        test(
          row.tabular ? 'chiffres tabulaires' : 'pas de chiffres tabulaires',
          () {
            final List<FontFeature> features =
                style.fontFeatures ?? const <FontFeature>[];
            expect(
              features.contains(const FontFeature.tabularFigures()),
              row.tabular,
            );
          },
        );
      });
    });
  });

  test('neuf styles, tous dans la famille embarquée du paquet', () {
    expect(rows.length, 9);
    for (final _Row row in rows.values) {
      expect(
        row.style.fontFamily,
        startsWith('packages/shared_design_system/'),
      );
    }
  });

  test('plus aucun plancher : seul le chiffre héros dépasse 28 px', () {
    // pdr-0087 : la lisibilité vient de l'échelle du design system.
    final smallest = rows.values
        .map((row) => row.style.fontSize!)
        .reduce((a, b) => a < b ? a : b);
    expect(smallest, 11);
    expect(theme.value.fontSize, 76);
  });
}
