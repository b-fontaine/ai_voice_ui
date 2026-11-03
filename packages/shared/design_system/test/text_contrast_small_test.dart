import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Contraste des textes de moins de 24 px (18,66 px en gras) : pdr-0088 F12.
///
/// Depuis pdr-0087, des textes de 11 à 20 px existent. Le seuil de 3:1 du
/// « grand texte » ne s'applique plus : toute paire couleur de texte × fond réel
/// doit atteindre 4,5:1 (WCAG 1.4.3, AA). `ink-faint` (et `agentIdle`, de même
/// valeur) reste réservé au décoratif et aux composants inactifs.

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const SceneTheme theme = SceneTheme.dark();
  // Fonds réels sur lesquels un texte est posé (void, surface-100/200/300).
  final Map<String, Color> backgrounds = <String, Color>{
    'void': theme.background,
    'surface-100': theme.surface,
    'surface-200': theme.surface200,
    'surface-300': theme.surface300,
  };
  // Couleurs que les composants emploient pour du texte de moins de 24 px.
  final Map<String, Color> smallTextColors = <String, Color>{
    'ink': theme.textPrimary,
    'ink-muted': theme.textSecondary,
    'signal (accent)': theme.accent,
    'go': theme.okForeground,
    'warn': theme.riskForeground,
    'nogo': theme.blockingForeground,
  };

  group('texte de moins de 24 px : 4,5:1 sur chaque fond réel', () {
    smallTextColors.forEach((colorName, color) {
      backgrounds.forEach((backgroundName, background) {
        test('$colorName sur $backgroundName', () {
          expect(_contrast(color, background), greaterThanOrEqualTo(4.5));
        });
      });
    });
  });

  group('mot de statut sur son fond ghost, posé sur chaque fond réel', () {
    final Map<String, (Color, Color)> statuses = <String, (Color, Color)>{
      'ok': (theme.okForeground, theme.okBackground),
      'risk': (theme.riskForeground, theme.riskBackground),
      'blocking': (theme.blockingForeground, theme.blockingBackground),
      'neutral': (theme.neutralForeground, theme.neutralBackground),
    };
    statuses.forEach((status, pair) {
      backgrounds.forEach((backgroundName, background) {
        test('$status sur $backgroundName', () {
          final Color ghost = Color.alphaBlend(pair.$2, background);
          expect(_contrast(pair.$1, ghost), greaterThanOrEqualTo(4.5));
        });
      });
    });
  });

  group('ink-faint et agentIdle sont exclus des petits textes', () {
    test('agentIdle a la valeur de ink-faint', () {
      expect(theme.agentIdle, theme.inkFaint);
    });
    backgrounds.forEach((backgroundName, background) {
      test('ink-faint reste sous 4,5:1 sur $backgroundName', () {
        // Raison de l'exclusion (pdr-0088 F12) : 4,35 / 4,10 / 3,79 / 3,40:1.
        expect(_contrast(theme.inkFaint, background), lessThan(4.5));
      });
    });
  });
}
