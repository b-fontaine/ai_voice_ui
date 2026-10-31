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
  return Color(0xFF000000 | rgb);
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

  add('scene.motion.appear', SceneMotion.appear, _ms);
  add('scene.motion.value', SceneMotion.value, _ms);
  add('scene.motion.status', SceneMotion.status, _ms);
  add('scene.motion.floor', SceneMotion.floor, _ms);
  add('scene.motion.translation', SceneMotion.translation, _px);
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

  test('mouvement : durées, plancher et translation de SceneMotion', () {
    expectGroup('scene.motion.');
  });

  test('aucun token de scène sans contrepartie dans le code', () {
    final scene = tokens.keys.where((p) => p.startsWith('scene.')).toSet();
    expect(scene.difference(_sceneReadings.keys.toSet()), isEmpty);
    expect(_sceneReadings.keys.toSet().difference(scene), isEmpty);
  });
}
