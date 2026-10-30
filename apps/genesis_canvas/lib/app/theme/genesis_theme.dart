import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Taille minimale de texte de la scène (px logiques, RG-09).
const double _minFontSize = 24;

/// Thème de l'app : sombre, avec le [SceneTheme] installé comme extension
/// (RG-09, D6) et un plancher de 24 px sur tous les styles de texte de Material
/// (NFR-05 : lisible à distance), pour que même un `Text` sans style explicite
/// respecte la taille minimale. Les styles de Material sans taille propre
/// (avant localisation) prennent ce plancher.
ThemeData genesisThemeData() {
  const scene = SceneTheme.dark();
  final base = ThemeData(
    brightness: Brightness.dark,
    extensions: const <ThemeExtension<dynamic>>[scene],
  );
  return base.copyWith(
    scaffoldBackgroundColor: scene.background,
    textTheme: _withMinimumSize(base.textTheme, _minFontSize),
  );
}

TextTheme _withMinimumSize(TextTheme theme, double minimum) {
  TextStyle? floor(TextStyle? style) {
    if (style == null) return null;
    final size = style.fontSize;
    return size == null || size < minimum
        ? style.copyWith(fontSize: minimum)
        : style;
  }

  return theme.copyWith(
    displayLarge: floor(theme.displayLarge),
    displayMedium: floor(theme.displayMedium),
    displaySmall: floor(theme.displaySmall),
    headlineLarge: floor(theme.headlineLarge),
    headlineMedium: floor(theme.headlineMedium),
    headlineSmall: floor(theme.headlineSmall),
    titleLarge: floor(theme.titleLarge),
    titleMedium: floor(theme.titleMedium),
    titleSmall: floor(theme.titleSmall),
    bodyLarge: floor(theme.bodyLarge),
    bodyMedium: floor(theme.bodyMedium),
    bodySmall: floor(theme.bodySmall),
    labelLarge: floor(theme.labelLarge),
    labelMedium: floor(theme.labelMedium),
    labelSmall: floor(theme.labelSmall),
  );
}
