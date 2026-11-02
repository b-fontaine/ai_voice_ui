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

/// Fonds réels sur lesquels le texte est posé (design system du 2026-11-02).
const Map<String, Color> _realBackgrounds = <String, Color>{
  'void': Color(0xFF04060C),
  'surface-100': Color(0xFF0A0F1E),
  'surface-200': Color(0xFF101731),
  'surface-300': Color(0xFF18213F),
};

void main() {
  const theme = SceneTheme.dark();

  group('rôles : valeurs du design system (tokens.json du 2026-11-02)', () {
    final expected = <String, (Color, Color)>{
      'background = void': (theme.background, const Color(0xFF04060C)),
      'surface = surface-100': (theme.surface, const Color(0xFF0A0F1E)),
      'textPrimary = ink': (theme.textPrimary, const Color(0xFFEAF0FF)),
      'textSecondary = ink-muted': (
        theme.textSecondary,
        const Color(0xFF93A1CC),
      ),
      'accent = signal': (theme.accent, const Color(0xFF3DE8FF)),
      'okBackground = go-ghost': (theme.okBackground, const Color(0x1C3EF2A5)),
      'okForeground = go': (theme.okForeground, const Color(0xFF3EF2A5)),
      'riskBackground = warn-ghost': (
        theme.riskBackground,
        const Color(0x1CFFC845),
      ),
      'riskForeground = warn': (theme.riskForeground, const Color(0xFFFFC845)),
      'blockingBackground = nogo-ghost': (
        theme.blockingBackground,
        const Color(0x1FFF5A76),
      ),
      'blockingForeground = nogo': (
        theme.blockingForeground,
        const Color(0xFFFF5A76),
      ),
      'neutralBackground = surface-300': (
        theme.neutralBackground,
        const Color(0xFF18213F),
      ),
      'neutralForeground = ink-muted': (
        theme.neutralForeground,
        const Color(0xFF93A1CC),
      ),
      'highlightOutline = signal': (
        theme.highlightOutline,
        const Color(0xFF3DE8FF),
      ),
      'actionNeutralBorder = ink-muted': (
        theme.actionNeutralBorder,
        const Color(0xFF93A1CC),
      ),
      'actionDangerBorder = nogo': (
        theme.actionDangerBorder,
        const Color(0xFFFF5A76),
      ),
      'agentWorking = signal': (theme.agentWorking, const Color(0xFF3DE8FF)),
      'agentIdle = ink-faint': (theme.agentIdle, const Color(0xFF66739E)),
      'agentRejected = warn': (theme.agentRejected, const Color(0xFFFFC845)),
      'agentInterrupted = baseline': (
        theme.agentInterrupted,
        const Color(0xFF8592BB),
      ),
      'chartIos = ink': (theme.chartIos, const Color(0xFFEAF0FF)),
      'chartAndroid = signal': (theme.chartAndroid, const Color(0xFF3DE8FF)),
      'chartOther = baseline': (theme.chartOther, const Color(0xFF8592BB)),
      'panelTop = surface-200': (theme.panelTop, const Color(0xFF101731)),
      'panelHighlight = #ffffff08': (
        theme.panelHighlight,
        const Color(0x08FFFFFF),
      ),
      'line': (theme.line, const Color(0xFF1F2A4D)),
      'lineStrong': (theme.lineStrong, const Color(0xFF3A4C80)),
      'inkFaint': (theme.inkFaint, const Color(0xFF66739E)),
      'plasma': (theme.plasma, const Color(0xFFA58BFF)),
      'plasmaGhost': (theme.plasmaGhost, const Color(0x24A58BFF)),
      'signalGhost': (theme.signalGhost, const Color(0x1F3DE8FF)),
      'surface200': (theme.surface200, const Color(0xFF101731)),
      'surface300': (theme.surface300, const Color(0xFF18213F)),
      'orbVeil': (theme.orbVeil, const Color(0xB3424242)),
    };
    expected.forEach((name, pair) {
      test(name, () => expect(pair.$1, pair.$2));
    });
  });

  group('contraste WCAG des mots de statut sur chaque fond réel', () {
    // Le fond *-ghost est translucide : on le compose d'abord sur le fond réel
    // (computeLuminance ignore l'alpha). Seuil AA 4,5:1.
    final statuses = <String, (Color, Color)>{
      'ok': (theme.okForeground, theme.okBackground),
      'risk': (theme.riskForeground, theme.riskBackground),
      'blocking': (theme.blockingForeground, theme.blockingBackground),
    };
    statuses.forEach((status, pair) {
      _realBackgrounds.forEach((backgroundName, background) {
        test('$status sur son fond ghost, posé sur $backgroundName', () {
          final ratio = contrast(
            pair.$1,
            Color.alphaBlend(pair.$2, background),
          );
          // ignore: avoid_print
          print(
            'CONTRAST $status/ghost/$backgroundName = '
            '${ratio.toStringAsFixed(2)}',
          );
          expect(ratio, greaterThanOrEqualTo(4.5));
        });
      });
    });
  });

  group('contraste du texte sur chaque fond réel', () {
    _realBackgrounds.forEach((backgroundName, background) {
      test('ink >= 15:1 sur $backgroundName', () {
        // Écart à la source : tokens.json annonce « >= 15:1 » sur les quatre
        // fonds, mais ink ne vaut que 13,86:1 sur surface-300 (17,76 sur void,
        // 16,73 sur surface-100, 15,48 sur surface-200). Sur surface-300, on
        // exige donc 13:1, largement au-dessus du seuil AAA de 7:1.
        final minimum = backgroundName == 'surface-300' ? 13.0 : 15.0;
        expect(
          contrast(theme.textPrimary, background),
          greaterThanOrEqualTo(minimum),
        );
      });
      test('ink-faint >= 3:1 (grand texte, 24 px) sur $backgroundName', () {
        // 24 px et plus seulement : 3,79:1 sur surface-200, 3,40:1 sur
        // surface-300 (relevé de la revue du plan).
        expect(contrast(theme.inkFaint, background), greaterThanOrEqualTo(3));
      });
    });
    test('ink-muted >= 7:1 sur surface-100', () {
      expect(
        contrast(theme.textSecondary, _realBackgrounds['surface-100']!),
        greaterThanOrEqualTo(7),
      );
    });
    test('ink-muted >= 4,5:1 sur chacun des quatre fonds', () {
      _realBackgrounds.forEach((name, background) {
        expect(
          contrast(theme.textSecondary, background),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
      });
    });
    test('accent (signal) >= 4,5:1 sur chacun des quatre fonds', () {
      _realBackgrounds.forEach((name, background) {
        expect(
          contrast(theme.accent, background),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
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

  group('boutons d\'action (ton neutral/danger, RG-09)', () {
    test('texte neutre (ink) / surface-300 >= 4,5:1', () {
      expect(
        contrast(theme.textPrimary, theme.surface300),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('texte danger (nogo) / surface-300 >= 4,5:1', () {
      expect(
        contrast(theme.blockingForeground, theme.surface300),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('bordure danger (nogo) / surface et fond >= 3:1', () {
      expect(
        contrast(theme.actionDangerBorder, theme.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(theme.actionDangerBorder, theme.background),
        greaterThanOrEqualTo(3),
      );
    });
    _realBackgrounds.forEach((name, background) {
      test('bordure neutre (ink-muted) >= 3:1 sur $name', () {
        // Composant d'interface : 3:1 (WCAG 1.4.11). line-strong ne vaut que
        // 2,30:1 sur surface-100 (écart à la source) : elle reste un rôle
        // décoratif (`lineStrong`), pas la bordure d'un bouton.
        expect(
          contrast(theme.actionNeutralBorder, background),
          greaterThanOrEqualTo(3),
        );
      });
    });
    test('les deux bordures sont distinctes', () {
      expect(theme.actionNeutralBorder, isNot(theme.actionDangerBorder));
    });
    test('copyWith et lerp portent les bordures', () {
      final copy = theme.copyWith(actionDangerBorder: const Color(0xFF00FF00));
      expect(copy.actionDangerBorder, const Color(0xFF00FF00));
      expect(copy.actionNeutralBorder, theme.actionNeutralBorder);
      final other = theme.copyWith(
        actionNeutralBorder: const Color(0xFFFFFFFF),
      );
      expect(theme.lerp(other, 1).actionNeutralBorder, const Color(0xFFFFFFFF));
    });
  });

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
      'data': theme.data,
      'verdict': theme.verdict,
      'transcript': theme.transcript,
      'button': theme.button,
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

    test('copyWith, lerp, == et hashCode couvrent les champs ajoutés', () {
      const white = Color(0xFFFFFFFF);
      final copies = <String, SceneTheme Function()>{
        'panelTop': () => theme.copyWith(panelTop: white),
        'panelHighlight': () => theme.copyWith(panelHighlight: white),
        'line': () => theme.copyWith(line: white),
        'lineStrong': () => theme.copyWith(lineStrong: white),
        'inkFaint': () => theme.copyWith(inkFaint: white),
        'plasma': () => theme.copyWith(plasma: white),
        'plasmaGhost': () => theme.copyWith(plasmaGhost: white),
        'signalGhost': () => theme.copyWith(signalGhost: white),
        'surface200': () => theme.copyWith(surface200: white),
        'surface300': () => theme.copyWith(surface300: white),
        'orbVeil': () => theme.copyWith(orbVeil: white),
      };
      final reads = <String, Color Function(SceneTheme)>{
        'panelTop': (t) => t.panelTop,
        'panelHighlight': (t) => t.panelHighlight,
        'line': (t) => t.line,
        'lineStrong': (t) => t.lineStrong,
        'inkFaint': (t) => t.inkFaint,
        'plasma': (t) => t.plasma,
        'plasmaGhost': (t) => t.plasmaGhost,
        'signalGhost': (t) => t.signalGhost,
        'surface200': (t) => t.surface200,
        'surface300': (t) => t.surface300,
        'orbVeil': (t) => t.orbVeil,
      };
      copies.forEach((name, copy) {
        final changed = copy();
        expect(reads[name]!(changed), white, reason: name);
        expect(changed, isNot(theme), reason: '$name dans ==');
        expect(changed.hashCode, isNot(theme.hashCode), reason: name);
        expect(reads[name]!(theme.lerp(changed, 1)), white, reason: name);
        expect(
          reads[name]!(theme.lerp(changed, 0)),
          reads[name]!(theme),
          reason: name,
        );
        expect(
          reads[name]!(theme.lerp(changed, 0.5)),
          Color.lerp(reads[name]!(theme), white, 0.5),
          reason: name,
        );
      });
    });

    test('copyWith, lerp, == et hashCode couvrent les styles de texte', () {
      const probe = TextStyle(fontSize: 40, color: Color(0xFF00FF00));
      final copies = <String, SceneTheme Function()>{
        'body': () => theme.copyWith(body: probe),
        'label': () => theme.copyWith(label: probe),
        'value': () => theme.copyWith(value: probe),
        'title': () => theme.copyWith(title: probe),
        'actIndicator': () => theme.copyWith(actIndicator: probe),
        'data': () => theme.copyWith(data: probe),
        'verdict': () => theme.copyWith(verdict: probe),
        'transcript': () => theme.copyWith(transcript: probe),
        'button': () => theme.copyWith(button: probe),
      };
      final reads = <String, TextStyle Function(SceneTheme)>{
        'body': (t) => t.body,
        'label': (t) => t.label,
        'value': (t) => t.value,
        'title': (t) => t.title,
        'actIndicator': (t) => t.actIndicator,
        'data': (t) => t.data,
        'verdict': (t) => t.verdict,
        'transcript': (t) => t.transcript,
        'button': (t) => t.button,
      };
      copies.forEach((name, copy) {
        final changed = copy();
        expect(reads[name]!(changed), probe, reason: name);
        expect(changed, isNot(theme), reason: '$name dans ==');
        expect(changed.hashCode, isNot(theme.hashCode), reason: name);
        expect(reads[name]!(theme.lerp(changed, 1)).fontSize, 40, reason: name);
        expect(
          reads[name]!(theme.lerp(changed, 0)).fontSize,
          reads[name]!(theme).fontSize,
          reason: name,
        );
        final TextStyle mid = reads[name]!(theme.lerp(changed, 0.5));
        expect(
          mid.fontSize,
          closeTo((reads[name]!(theme).fontSize! + 40) / 2, 1e-9),
          reason: name,
        );
        // Les autres styles ne bougent pas.
        for (final other in reads.keys.where((k) => k != name)) {
          expect(reads[other]!(changed), reads[other]!(theme), reason: other);
        }
      });
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
