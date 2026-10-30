import 'package:flutter/material.dart';

import 'scene_status.dart';

/// Thème de la scène Genesis Canvas (fond sombre, texte lisible à distance).
///
/// Toutes les tailles de texte sont >= 24 px (RG-09, NFR-05) et les paires
/// texte/fond respectent le contraste WCAG AA (vérifié par `scene_theme_test`).
@immutable
class SceneTheme extends ThemeExtension<SceneTheme> {
  const SceneTheme({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.okBackground,
    required this.okForeground,
    required this.riskBackground,
    required this.riskForeground,
    required this.blockingBackground,
    required this.blockingForeground,
    required this.neutralBackground,
    required this.neutralForeground,
    required this.highlightOutline,
    required this.agentWorking,
    required this.agentIdle,
    required this.agentRejected,
    required this.agentInterrupted,
    required this.chartIos,
    required this.chartAndroid,
    required this.chartOther,
    required this.body,
    required this.label,
    required this.value,
    required this.title,
    required this.actIndicator,
  });

  /// Thème sombre de la démo (fond aligné sur la page : 0xFF0B0B14).
  const SceneTheme.dark()
    : background = const Color(0xFF0B0B14),
      surface = const Color(0xFF181830),
      textPrimary = const Color(0xFFF2F2F8),
      textSecondary = const Color(0xFFB9B9CC),
      accent = const Color(0xFFB39DFF),
      okBackground = const Color(0xFF0F3D26),
      okForeground = const Color(0xFF8FF0B5),
      riskBackground = const Color(0xFF4A3300),
      riskForeground = const Color(0xFFFFD27A),
      blockingBackground = const Color(0xFF4D1117),
      blockingForeground = const Color(0xFFFFB3B8),
      neutralBackground = const Color(0xFF2A2A40),
      neutralForeground = const Color(0xFFD8D8E6),
      highlightOutline = const Color(0xFFB39DFF),
      agentWorking = const Color(0xFFFFC107),
      agentIdle = const Color(0xFF90A4AE),
      agentRejected = const Color(0xFFFFAB40),
      agentInterrupted = const Color(0xFFB0B0BC),
      chartIos = const Color(0xFFB39DFF),
      chartAndroid = const Color(0xFF6CB6FF),
      chartOther = const Color(0xFF5EEAD4),
      body = const TextStyle(
        fontSize: 24,
        height: 1.3,
        color: Color(0xFFF2F2F8),
      ),
      label = const TextStyle(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: Color(0xFFB9B9CC),
      ),
      value = const TextStyle(
        fontSize: 56,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: Color(0xFFF2F2F8),
      ),
      title = const TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: Color(0xFFF2F2F8),
      ),
      actIndicator = const TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: Color(0xFFF2F2F8),
      );

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color okBackground;
  final Color okForeground;
  final Color riskBackground;
  final Color riskForeground;
  final Color blockingBackground;
  final Color blockingForeground;
  final Color neutralBackground;
  final Color neutralForeground;

  /// Contour pointillé de mise en évidence d'une surface.
  final Color highlightOutline;

  /// Couleurs d'état d'agent (renfort du libellé, jamais seules). Les autres
  /// états empruntent `accent`, `riskForeground`, `okForeground` et
  /// `blockingForeground`.
  final Color agentWorking;
  final Color agentIdle;
  final Color agentRejected;
  final Color agentInterrupted;

  /// Palette des séries de graphique, par plateforme (jamais une couleur de
  /// statut `ok/risk/blocking`) : stable d'un acte à l'autre.
  final Color chartIos;
  final Color chartAndroid;
  final Color chartOther;

  final TextStyle body;
  final TextStyle label;

  /// Grande valeur d'indicateur.
  final TextStyle value;
  final TextStyle title;

  /// Indicateur d'acte de la régie (>= 24 px).
  final TextStyle actIndicator;

  /// Lit l'extension dans le thème courant ; repli sur le thème sombre.
  static SceneTheme of(BuildContext context) =>
      Theme.of(context).extension<SceneTheme>() ?? const SceneTheme.dark();

  /// Fond d'un chip ; `null` (statut inconnu) donne le style neutre.
  Color statusBackground(SceneStatus? status) => switch (status) {
    SceneStatus.ok => okBackground,
    SceneStatus.risk => riskBackground,
    SceneStatus.blocking => blockingBackground,
    null => neutralBackground,
  };

  /// Premier plan d'un chip ; `null` (statut inconnu) donne le style neutre.
  Color statusForeground(SceneStatus? status) => switch (status) {
    SceneStatus.ok => okForeground,
    SceneStatus.risk => riskForeground,
    SceneStatus.blocking => blockingForeground,
    null => neutralForeground,
  };

  @override
  SceneTheme copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? okBackground,
    Color? okForeground,
    Color? riskBackground,
    Color? riskForeground,
    Color? blockingBackground,
    Color? blockingForeground,
    Color? neutralBackground,
    Color? neutralForeground,
    Color? highlightOutline,
    Color? agentWorking,
    Color? agentIdle,
    Color? agentRejected,
    Color? agentInterrupted,
    Color? chartIos,
    Color? chartAndroid,
    Color? chartOther,
    TextStyle? body,
    TextStyle? label,
    TextStyle? value,
    TextStyle? title,
    TextStyle? actIndicator,
  }) {
    return SceneTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      okBackground: okBackground ?? this.okBackground,
      okForeground: okForeground ?? this.okForeground,
      riskBackground: riskBackground ?? this.riskBackground,
      riskForeground: riskForeground ?? this.riskForeground,
      blockingBackground: blockingBackground ?? this.blockingBackground,
      blockingForeground: blockingForeground ?? this.blockingForeground,
      neutralBackground: neutralBackground ?? this.neutralBackground,
      neutralForeground: neutralForeground ?? this.neutralForeground,
      highlightOutline: highlightOutline ?? this.highlightOutline,
      agentWorking: agentWorking ?? this.agentWorking,
      agentIdle: agentIdle ?? this.agentIdle,
      agentRejected: agentRejected ?? this.agentRejected,
      agentInterrupted: agentInterrupted ?? this.agentInterrupted,
      chartIos: chartIos ?? this.chartIos,
      chartAndroid: chartAndroid ?? this.chartAndroid,
      chartOther: chartOther ?? this.chartOther,
      body: body ?? this.body,
      label: label ?? this.label,
      value: value ?? this.value,
      title: title ?? this.title,
      actIndicator: actIndicator ?? this.actIndicator,
    );
  }

  @override
  SceneTheme lerp(ThemeExtension<SceneTheme>? other, double t) {
    if (other is! SceneTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return SceneTheme(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      accent: c(accent, other.accent),
      okBackground: c(okBackground, other.okBackground),
      okForeground: c(okForeground, other.okForeground),
      riskBackground: c(riskBackground, other.riskBackground),
      riskForeground: c(riskForeground, other.riskForeground),
      blockingBackground: c(blockingBackground, other.blockingBackground),
      blockingForeground: c(blockingForeground, other.blockingForeground),
      neutralBackground: c(neutralBackground, other.neutralBackground),
      neutralForeground: c(neutralForeground, other.neutralForeground),
      highlightOutline: c(highlightOutline, other.highlightOutline),
      agentWorking: c(agentWorking, other.agentWorking),
      agentIdle: c(agentIdle, other.agentIdle),
      agentRejected: c(agentRejected, other.agentRejected),
      agentInterrupted: c(agentInterrupted, other.agentInterrupted),
      chartIos: c(chartIos, other.chartIos),
      chartAndroid: c(chartAndroid, other.chartAndroid),
      chartOther: c(chartOther, other.chartOther),
      body: s(body, other.body),
      label: s(label, other.label),
      value: s(value, other.value),
      title: s(title, other.title),
      actIndicator: s(actIndicator, other.actIndicator),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SceneTheme &&
      other.background == background &&
      other.surface == surface &&
      other.textPrimary == textPrimary &&
      other.textSecondary == textSecondary &&
      other.accent == accent &&
      other.okBackground == okBackground &&
      other.okForeground == okForeground &&
      other.riskBackground == riskBackground &&
      other.riskForeground == riskForeground &&
      other.blockingBackground == blockingBackground &&
      other.blockingForeground == blockingForeground &&
      other.neutralBackground == neutralBackground &&
      other.neutralForeground == neutralForeground &&
      other.highlightOutline == highlightOutline &&
      other.agentWorking == agentWorking &&
      other.agentIdle == agentIdle &&
      other.agentRejected == agentRejected &&
      other.agentInterrupted == agentInterrupted &&
      other.chartIos == chartIos &&
      other.chartAndroid == chartAndroid &&
      other.chartOther == chartOther &&
      other.body == body &&
      other.label == label &&
      other.value == value &&
      other.title == title &&
      other.actIndicator == actIndicator;

  @override
  int get hashCode => Object.hashAll(<Object>[
    background,
    surface,
    textPrimary,
    textSecondary,
    accent,
    okBackground,
    okForeground,
    riskBackground,
    riskForeground,
    blockingBackground,
    blockingForeground,
    neutralBackground,
    neutralForeground,
    highlightOutline,
    agentWorking,
    agentIdle,
    agentRejected,
    agentInterrupted,
    chartIos,
    chartAndroid,
    chartOther,
    body,
    label,
    value,
    title,
    actIndicator,
  ]);
}
