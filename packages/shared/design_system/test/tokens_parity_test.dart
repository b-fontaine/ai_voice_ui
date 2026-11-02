import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Parité des tokens DTCG (alias résolus) avec `SceneTheme.dark()` et
/// `SceneMotion` : chaque token doit valoir exactement la valeur du code.
Map<String, Object?> _loadTokens() {
  final flat = <String, Map<String, Object?>>{};
  void walk(String path, Object? node) {
    if (node is! Map<String, Object?>) return;
    if (node.containsKey(r'$value')) {
      flat[path] = node;
      return;
    }
    node.forEach((key, child) {
      if (key.startsWith(r'$')) return;
      walk(path.isEmpty ? key : '$path.$key', child);
    });
  }

  final files = Directory('tokens')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.tokens.json'));
  for (final file in files) {
    walk('', jsonDecode(file.readAsStringSync()));
  }

  Object? resolve(String path, Set<String> seen) {
    final token = flat[path];
    if (token == null) fail('token introuvable : $path');
    if (!seen.add(path)) fail('alias circulaire : $path');
    final value = token[r'$value'];
    if (value is String && value.startsWith('{') && value.endsWith('}')) {
      return resolve(value.substring(1, value.length - 1), seen);
    }
    return value;
  }

  return {for (final path in flat.keys) path: resolve(path, <String>{})};
}

/// Couleur DTCG 2025.10 : `hex` à six chiffres et `alpha` facultatif (1 par
/// défaut). L'octet d'alpha attendu est `round(alpha x 255)`.
Color _color(Object? value) {
  final map = value! as Map<String, Object?>;
  expect(map['colorSpace'], 'srgb');
  final hex = (map['hex']! as String).substring(1);
  expect(hex, matches(RegExp(r'^[0-9A-Fa-f]{6}$')));
  final components = (map['components']! as List<Object?>).cast<num>();
  final rgb = int.parse(hex, radix: 16);
  final fromHex = [(rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255];
  for (var i = 0; i < 3; i++) {
    expect((components[i] * 255).round(), fromHex[i], reason: 'composante $i');
  }
  final alpha = (map['alpha'] as num?) ?? 1;
  expect(alpha, inInclusiveRange(0, 1));
  return Color((alpha * 255).round() << 24 | rgb);
}

double _px(Object? value) {
  final map = value! as Map<String, Object?>;
  expect(map['unit'], 'px');
  return (map['value']! as num).toDouble();
}

Duration _ms(Object? value) {
  final map = value! as Map<String, Object?>;
  expect(map['unit'], 'ms');
  return Duration(milliseconds: (map['value']! as num).toInt());
}

FontWeight _weight(Object? value) =>
    FontWeight.values.firstWhere((w) => w.value == (value! as num).toInt());

/// Rayon de flou de `BoxShadow` pour un flou CSS [cssBlur] : le flou CSS `B`
/// donne un écart type de `B / 2`, et `blurRadius = r` donne
/// `sigma = 0,57735 r + 0,5` (`Shadow.convertRadiusToSigma`).
double _blurRadius(double cssBlur) {
  final radius = (cssBlur / 2 - 0.5) / 0.57735;
  return radius > 0 ? radius : 0;
}

/// Ombres DTCG (tableau ou ombre seule) vers `BoxShadow`. Une ombre `inset`
/// n'est pas exprimable : le token ne doit pas en contenir.
List<BoxShadow> _shadows(Object? value) {
  final list = value is List<Object?> ? value : <Object?>[value];
  return [
    for (final item in list)
      () {
        final map = item! as Map<String, Object?>;
        expect(map['inset'] ?? false, isFalse, reason: 'ombre inset refusée');
        return BoxShadow(
          color: _color(map['color']),
          offset: Offset(_px(map['offsetX']), _px(map['offsetY'])),
          blurRadius: _blurRadius(_px(map['blur'])),
          spreadRadius: map['spread'] == null ? 0 : _px(map['spread']),
        );
      }(),
  ];
}

/// Lecture d'un token dans le code : la valeur actuelle et la façon d'analyser
/// le token DTCG résolu pour la comparer.
typedef _Reading = ({Object? actual, Object? Function(Object?) parse});

/// Table unique `chemin de token -> lecture dans SceneTheme / SceneMotion`.
/// L'ensemble attendu des tokens `scene.*` en est déduit : les tests ne
/// dépendent donc pas de leur ordre d'exécution.
final Map<String, _Reading> _sceneReadings = _buildReadings();

const SceneTheme _theme = SceneTheme.dark();

Map<String, _Reading> _buildReadings() {
  final readings = <String, _Reading>{};
  void add(String path, Object? actual, Object? Function(Object?) parse) {
    readings[path] = (actual: actual, parse: parse);
  }

  final colors = <String, Color>{
    'background': _theme.background,
    'surface': _theme.surface,
    'textPrimary': _theme.textPrimary,
    'textSecondary': _theme.textSecondary,
    'accent': _theme.accent,
    'okBackground': _theme.okBackground,
    'okForeground': _theme.okForeground,
    'riskBackground': _theme.riskBackground,
    'riskForeground': _theme.riskForeground,
    'blockingBackground': _theme.blockingBackground,
    'blockingForeground': _theme.blockingForeground,
    'neutralBackground': _theme.neutralBackground,
    'neutralForeground': _theme.neutralForeground,
    'highlightOutline': _theme.highlightOutline,
    'actionNeutralBorder': _theme.actionNeutralBorder,
    'actionDangerBorder': _theme.actionDangerBorder,
    'agentWorking': _theme.agentWorking,
    'agentIdle': _theme.agentIdle,
    'agentRejected': _theme.agentRejected,
    'agentInterrupted': _theme.agentInterrupted,
    'chartIos': _theme.chartIos,
    'chartAndroid': _theme.chartAndroid,
    'chartOther': _theme.chartOther,
    'panelTop': _theme.panelTop,
    'panelHighlight': _theme.panelHighlight,
    'line': _theme.line,
    'lineStrong': _theme.lineStrong,
    'inkFaint': _theme.inkFaint,
    'plasma': _theme.plasma,
    'plasmaGhost': _theme.plasmaGhost,
    'signalGhost': _theme.signalGhost,
    'surface200': _theme.surface200,
    'surface300': _theme.surface300,
    'orbVeil': _theme.orbVeil,
  };
  colors.forEach((name, color) => add('scene.color.$name', color, _color));

  final styles = <String, TextStyle>{
    'body': _theme.body,
    'label': _theme.label,
    'value': _theme.value,
    'title': _theme.title,
    'actIndicator': _theme.actIndicator,
  };
  styles.forEach((name, style) {
    final base = 'scene.text.$name';
    add('$base.fontSize', style.fontSize, _px);
    add('$base.height', style.height, (v) => (v! as num).toDouble());
    add('$base.color', style.color, _color);
    // Une graisse non définie par le style n'a pas de token (voir le test).
    if (style.fontWeight != null) {
      add('$base.fontWeight', style.fontWeight, _weight);
    }
  });

  add('scene.space.1', SceneSpace.space1, _px);
  add('scene.space.2', SceneSpace.space2, _px);
  add('scene.space.3', SceneSpace.space3, _px);
  add('scene.space.4', SceneSpace.space4, _px);
  add('scene.space.6', SceneSpace.space6, _px);
  add('scene.space.8', SceneSpace.space8, _px);

  add('scene.radius.sm', SceneRadius.sm, _px);
  add('scene.radius.md', SceneRadius.md, _px);
  add('scene.radius.lg', SceneRadius.lg, _px);
  add('scene.radius.pill', SceneRadius.pill, _px);

  add('scene.shadow.panel', SceneShadow.panel, _shadows);
  add('scene.shadow.glowSignal', SceneShadow.glowSignal, _shadows);
  add('scene.shadow.glowNogo', SceneShadow.glowNogo, _shadows);
  add('scene.shadow.glowPlasma', SceneShadow.glowPlasma, _shadows);

  add('scene.motion.appear', SceneMotion.appear, _ms);
  add('scene.motion.value', SceneMotion.value, _ms);
  add('scene.motion.status', SceneMotion.status, _ms);
  add('scene.motion.floor', SceneMotion.floor, _ms);
  add('scene.motion.translation', SceneMotion.translation, _px);
  add('scene.motion.link', SceneMotion.link, _ms);
  return readings;
}

void main() {
  final tokens = _loadTokens();

  void expectGroup(String prefix) {
    final group = _sceneReadings.entries.where((e) => e.key.startsWith(prefix));
    expect(group, isNotEmpty, reason: prefix);
    for (final entry in group) {
      expect(tokens, contains(entry.key));
      expect(
        entry.value.actual,
        entry.value.parse(tokens[entry.key]),
        reason: entry.key,
      );
    }
  }

  test('couleurs : chaque token de scène égale le champ de SceneTheme', () {
    expectGroup('scene.color.');
  });

  test('typographie : taille, hauteur, graisse et couleur de chaque style', () {
    expectGroup('scene.text.');
    for (final entry in <String, TextStyle>{
      'body': _theme.body,
      'label': _theme.label,
      'value': _theme.value,
      'title': _theme.title,
      'actIndicator': _theme.actIndicator,
    }.entries) {
      if (entry.value.fontWeight == null) {
        expect(
          tokens,
          isNot(contains('scene.text.${entry.key}.fontWeight')),
          reason: entry.key,
        );
      }
    }
  });

  test('alpha : l\'octet d\'opacité vaut round(alpha x 255) de la source', () {
    // Octets d'opacité du design system (tokens.json : #RRGGBBAA).
    const sourceAlpha = <String, int>{
      'scene.color.okBackground': 0x1c,
      'scene.color.riskBackground': 0x1c,
      'scene.color.blockingBackground': 0x1f,
      'scene.color.signalGhost': 0x1f,
      'scene.color.plasmaGhost': 0x24,
      'scene.color.panelHighlight': 0x08,
      'scene.color.orbVeil': 0xB3,
    };
    sourceAlpha.forEach((path, byte) {
      final map = tokens[path]! as Map<String, Object?>;
      expect(((map['alpha']! as num) * 255).round(), byte, reason: path);
      expect(_sceneReadings[path]!.actual, isA<Color>());
      expect(((_sceneReadings[path]!.actual! as Color).a * 255).round(), byte);
    });
  });

  test('espacements : constantes de SceneSpace', () {
    expectGroup('scene.space.');
  });

  test('rayons : constantes de SceneRadius', () {
    expectGroup('scene.radius.');
  });

  test('ombres : SceneShadow, flou converti (sigma = B / 2), sans inset', () {
    expectGroup('scene.shadow.');
    for (final path in tokens.keys.where(
      (p) => p.startsWith('scene.shadow.'),
    )) {
      final shadows = _sceneReadings[path]!.actual! as List<BoxShadow>;
      final list = tokens[path]! is List
          ? tokens[path]! as List
          : [tokens[path]];
      for (var i = 0; i < shadows.length; i++) {
        final css = (list[i]! as Map<String, Object?>);
        final blur = _px(css['blur']);
        if (blur > 1) {
          expect(shadows[i].blurSigma, closeTo(blur / 2, 1e-9), reason: path);
        }
      }
    }
  });

  test('mouvement : durées, plancher et translation de SceneMotion', () {
    expectGroup('scene.motion.');
  });

  test('aucun token de scène sans contrepartie dans le code', () {
    final scene = tokens.keys.where((p) => p.startsWith('scene.')).toSet();
    expect(scene.difference(_sceneReadings.keys.toSet()), isEmpty);
    expect(_sceneReadings.keys.toSet().difference(scene), isEmpty);
  });
}
