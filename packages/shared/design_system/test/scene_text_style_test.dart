import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Ligne de la table « Tailles de texte » de `specs/017-design-system-v2/spec.md`.
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
      size: 24,
      height: 1.3,
      wght: 500,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: true,
    ),
    'label': (
      style: theme.label,
      family: SceneFonts.mono,
      size: 24,
      height: 1.3,
      wght: 500,
      letterSpacingEm: 0.14,
      color: theme.textSecondary,
      tabular: false,
    ),
    'title': (
      style: theme.title,
      family: SceneFonts.sans,
      size: 24,
      height: 1.2,
      wght: 600,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
    'transcript': (
      style: theme.transcript,
      family: SceneFonts.sans,
      size: 24,
      height: 1.3,
      wght: 500,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
    'body': (
      style: theme.body,
      family: SceneFonts.sans,
      size: 24,
      height: 1.3,
      wght: 400,
      letterSpacingEm: 0,
      color: theme.textPrimary,
      tabular: false,
    ),
    'button': (
      style: theme.button,
      family: SceneFonts.sans,
      size: 24,
      height: 1.3,
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

  group('styles de SceneTheme : table de tailles de texte (spec 017)', () {
    rows.forEach((name, row) {
      group(name, () {
        final TextStyle style = row.style;
        test('taille, hauteur de ligne et couleur', () {
          expect(style.fontSize, row.size);
          expect(style.fontSize, greaterThanOrEqualTo(24));
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

  test('label et button restent distinguables (classement par rôle)', () {
    final TextStyle label = theme.label;
    final TextStyle button = theme.button;
    expect(label.fontWeight, isNot(button.fontWeight));
    expect(label.letterSpacing, isNot(button.letterSpacing));
  });

  test('aucune famille ni taille codée hors de la table : 9 styles', () {
    expect(rows.length, 9);
    for (final _Row row in rows.values) {
      expect(
        row.style.fontFamily,
        startsWith('packages/shared_design_system/'),
      );
    }
  });

  testWidgets(
    'sceneTextStyle reprend la famille ambiante et garde taille et graisse',
    (tester) async {
      late TextStyle resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Ambiante',
              fontFamilyFallback: <String>['Secours'],
            ),
            child: Builder(
              builder: (context) {
                resolved = sceneTextStyle(
                  context,
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved.fontFamily, 'Ambiante');
      expect(resolved.fontFamilyFallback, <String>['Secours']);
      expect(resolved.fontSize, 26);
      expect(resolved.fontWeight, FontWeight.w700);
    },
  );
}
