import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  final theme = sceneMaterialTheme();

  test('le thème de scène est installé comme extension du ThemeData', () {
    expect(theme.extension<SceneTheme>(), const SceneTheme.dark());
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const SceneTheme.dark().background);
  });

  test('tous les styles de texte de Material font au moins 24 px', () {
    final text = theme.textTheme;
    final styles = <String, TextStyle?>{
      'displayLarge': text.displayLarge,
      'displayMedium': text.displayMedium,
      'displaySmall': text.displaySmall,
      'headlineLarge': text.headlineLarge,
      'headlineMedium': text.headlineMedium,
      'headlineSmall': text.headlineSmall,
      'titleLarge': text.titleLarge,
      'titleMedium': text.titleMedium,
      'titleSmall': text.titleSmall,
      'bodyLarge': text.bodyLarge,
      'bodyMedium': text.bodyMedium,
      'bodySmall': text.bodySmall,
      'labelLarge': text.labelLarge,
      'labelMedium': text.labelMedium,
      'labelSmall': text.labelSmall,
    };
    styles.forEach((name, style) {
      expect(style?.fontSize, isNotNull, reason: name);
      expect(style!.fontSize, greaterThanOrEqualTo(24), reason: name);
    });
  });
}
