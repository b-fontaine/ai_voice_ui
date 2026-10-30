import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Luminance relative WCAG 2.x.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const theme = SceneTheme.dark();

  group('contraste WCAG AA (4,5:1 visé partout)', () {
    final pairs = <String, (Color, Color)>{
      'texte principal / fond de scène': (theme.textPrimary, theme.background),
      'texte principal / surface': (theme.textPrimary, theme.surface),
      'texte secondaire / fond de scène': (
        theme.textSecondary,
        theme.background,
      ),
      'texte secondaire / surface': (theme.textSecondary, theme.surface),
      'accent / fond de scène': (theme.accent, theme.background),
      'accent / surface': (theme.accent, theme.surface),
      'ok premier plan / fond': (theme.okForeground, theme.okBackground),
      'risk premier plan / fond': (theme.riskForeground, theme.riskBackground),
      'blocking premier plan / fond': (
        theme.blockingForeground,
        theme.blockingBackground,
      ),
      'ligne de comparaison (neutre) / surface': (
        theme.textSecondary,
        theme.surface,
      ),
      'contour de mise en évidence / fond de scène': (
        theme.highlightOutline,
        theme.background,
      ),
    };
    pairs.forEach((name, pair) {
      test(name, () {
        final ratio = contrast(pair.$1, pair.$2);
        // ignore: avoid_print
        print('CONTRAST $name = ${ratio.toStringAsFixed(2)}');
        expect(ratio, greaterThanOrEqualTo(4.5));
      });
    });
  });

  group(
    'contraste des éléments graphiques sur la surface (3:1, WCAG 1.4.11)',
    () {
      final graphics = <String, Color>{
        'accent (série de rang 0)': theme.accent,
        'ok premier plan (série, seuil)': theme.okForeground,
        'risk premier plan (série)': theme.riskForeground,
        'blocking premier plan (seuil)': theme.blockingForeground,
        'contour de mise en évidence': theme.highlightOutline,
        'agent en cours': theme.agentWorking,
        'agent en veille': theme.agentIdle,
        'agent hors périmètre': theme.agentRejected,
        'agent interrompu': theme.agentInterrupted,
        'graphique iOS': theme.chartIos,
        'graphique Android': theme.chartAndroid,
        'graphique autre plateforme': theme.chartOther,
      };
      graphics.forEach((name, color) {
        test('$name / surface', () {
          expect(contrast(color, theme.surface), greaterThanOrEqualTo(3));
          expect(contrast(color, theme.background), greaterThanOrEqualTo(3));
        });
      });
    },
  );

  test('la palette de graphique ne reprend aucune couleur de statut', () {
    final chart = <Color>{theme.chartIos, theme.chartAndroid, theme.chartOther};
    expect(chart, hasLength(3));
    expect(
      chart.intersection(<Color>{
        theme.okForeground,
        theme.riskForeground,
        theme.blockingForeground,
      }),
      isEmpty,
    );
  });

  test('toutes les tailles de texte sont >= 24 px', () {
    final styles = {
      'body': theme.body,
      'label': theme.label,
      'value': theme.value,
      'title': theme.title,
      'actIndicator': theme.actIndicator,
    };
    styles.forEach((name, style) {
      expect(style.fontSize, isNotNull, reason: name);
      expect(style.fontSize, greaterThanOrEqualTo(24), reason: name);
    });
    expect(theme.value.fontSize, greaterThanOrEqualTo(48));
  });

  group('SceneStatus.fromCode', () {
    test('codes connus', () {
      expect(SceneStatus.fromCode('ok'), SceneStatus.ok);
      expect(SceneStatus.fromCode('risk'), SceneStatus.risk);
      expect(SceneStatus.fromCode('blocking'), SceneStatus.blocking);
    });
    test('inconnu ou null donne null', () {
      expect(SceneStatus.fromCode(null), isNull);
      expect(SceneStatus.fromCode('OK'), isNull);
      expect(SceneStatus.fromCode('validé'), isNull);
      expect(SceneStatus.fromCode(''), isNull);
    });
  });

  group('copyWith et lerp', () {
    test('copyWith remplace seulement ce qui est donné', () {
      final copy = theme.copyWith(accent: const Color(0xFF00FF00));
      expect(copy.accent, const Color(0xFF00FF00));
      expect(copy.background, theme.background);
      expect(copy.body, theme.body);
    });

    test('lerp aux bornes et au milieu', () {
      final other = theme.copyWith(background: const Color(0xFFFFFFFF));
      expect(theme.lerp(other, 0).background, theme.background);
      expect(theme.lerp(other, 1).background, const Color(0xFFFFFFFF));
      final mid = theme.lerp(other, 0.5).background;
      expect(mid, Color.lerp(theme.background, const Color(0xFFFFFFFF), 0.5));
    });

    test('lerp avec un autre type renvoie this', () {
      expect(theme.lerp(null, 0.5), same(theme));
    });
  });

  test('statut vers couleurs, null vers neutre', () {
    expect(theme.statusBackground(SceneStatus.ok), theme.okBackground);
    expect(theme.statusForeground(SceneStatus.risk), theme.riskForeground);
    expect(
      theme.statusBackground(SceneStatus.blocking),
      theme.blockingBackground,
    );
    expect(theme.statusBackground(null), theme.neutralBackground);
    expect(theme.statusForeground(null), theme.neutralForeground);
    expect(
      contrast(theme.neutralForeground, theme.neutralBackground),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('SceneTheme.of lit l\'extension', (tester) async {
    late SceneTheme found;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [SceneTheme.dark()]),
        home: Builder(
          builder: (context) {
            found = SceneTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, theme);
  });
}
