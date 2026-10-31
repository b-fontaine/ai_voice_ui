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

void main() {
  const theme = SceneTheme.dark();
  final tokens = _loadTokens();
  final checked = <String>{};

  void expectToken<T>(String path, T actual, T Function(Object?) parse) {
    checked.add(path);
    expect(tokens, contains(path));
    expect(actual, parse(tokens[path]), reason: path);
  }

  test('couleurs : chaque token de scène égale le champ de SceneTheme', () {
    final colors = <String, Color>{
      'background': theme.background,
      'surface': theme.surface,
      'textPrimary': theme.textPrimary,
      'textSecondary': theme.textSecondary,
      'accent': theme.accent,
      'okBackground': theme.okBackground,
      'okForeground': theme.okForeground,
      'riskBackground': theme.riskBackground,
      'riskForeground': theme.riskForeground,
      'blockingBackground': theme.blockingBackground,
      'blockingForeground': theme.blockingForeground,
      'neutralBackground': theme.neutralBackground,
      'neutralForeground': theme.neutralForeground,
      'highlightOutline': theme.highlightOutline,
      'actionNeutralBorder': theme.actionNeutralBorder,
      'actionDangerBorder': theme.actionDangerBorder,
      'agentWorking': theme.agentWorking,
      'agentIdle': theme.agentIdle,
      'agentRejected': theme.agentRejected,
      'agentInterrupted': theme.agentInterrupted,
      'chartIos': theme.chartIos,
      'chartAndroid': theme.chartAndroid,
      'chartOther': theme.chartOther,
    };
    colors.forEach((name, color) {
      expectToken('scene.color.$name', color, _color);
    });
  });

  test('typographie : taille, hauteur, graisse et couleur de chaque style', () {
    final styles = <String, TextStyle>{
      'body': theme.body,
      'label': theme.label,
      'value': theme.value,
      'title': theme.title,
      'actIndicator': theme.actIndicator,
    };
    styles.forEach((name, style) {
      final base = 'scene.text.$name';
      expectToken('$base.fontSize', style.fontSize, (v) => _px(v));
      expectToken('$base.height', style.height, (v) => (v! as num).toDouble());
      expectToken('$base.color', style.color, _color);
      if (style.fontWeight == null) {
        expect(tokens, isNot(contains('$base.fontWeight')), reason: name);
      } else {
        expectToken('$base.fontWeight', style.fontWeight, _weight);
      }
    });
  });

  test('mouvement : durées et plancher de SceneMotion', () {
    expectToken('scene.motion.appear', SceneMotion.appear, _ms);
    expectToken('scene.motion.value', SceneMotion.value, _ms);
    expectToken('scene.motion.status', SceneMotion.status, _ms);
    expectToken('scene.motion.floor', SceneMotion.floor, _ms);
  });

  test('aucun token de scène sans contrepartie dans le code', () {
    final scene = tokens.keys.where((p) => p.startsWith('scene.')).toSet();
    // Les tests ci-dessus s'exécutent avant : `checked` est alors complet.
    expect(scene.difference(checked), isEmpty);
  });
}
