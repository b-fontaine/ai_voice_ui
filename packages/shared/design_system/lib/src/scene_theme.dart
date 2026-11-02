import 'package:flutter/material.dart';

import 'generated/scene_tokens.g.dart';
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
    required this.actionNeutralBorder,
    required this.actionDangerBorder,
    required this.agentWorking,
    required this.agentIdle,
    required this.agentRejected,
    required this.agentInterrupted,
    required this.chartIos,
    required this.chartAndroid,
    required this.chartOther,
    required this.panelTop,
    required this.panelHighlight,
    required this.line,
    required this.lineStrong,
    required this.inkFaint,
    required this.plasma,
    required this.plasmaGhost,
    required this.signalGhost,
    required this.surface200,
    required this.surface300,
    required this.orbVeil,
    required this.body,
    required this.label,
    required this.value,
    required this.title,
    required this.actIndicator,
  });

  /// Thème sombre de la démo, construit depuis les constantes `SceneTokens`
  /// générées (tokens DTCG : `tokens/*.tokens.json`, fond `void`).
  const SceneTheme.dark()
    : background = SceneTokens.colorBackground,
      surface = SceneTokens.colorSurface,
      textPrimary = SceneTokens.colorTextPrimary,
      textSecondary = SceneTokens.colorTextSecondary,
      accent = SceneTokens.colorAccent,
      okBackground = SceneTokens.colorOkBackground,
      okForeground = SceneTokens.colorOkForeground,
      riskBackground = SceneTokens.colorRiskBackground,
      riskForeground = SceneTokens.colorRiskForeground,
      blockingBackground = SceneTokens.colorBlockingBackground,
      blockingForeground = SceneTokens.colorBlockingForeground,
      neutralBackground = SceneTokens.colorNeutralBackground,
      neutralForeground = SceneTokens.colorNeutralForeground,
      highlightOutline = SceneTokens.colorHighlightOutline,
      actionNeutralBorder = SceneTokens.colorActionNeutralBorder,
      actionDangerBorder = SceneTokens.colorActionDangerBorder,
      agentWorking = SceneTokens.colorAgentWorking,
      agentIdle = SceneTokens.colorAgentIdle,
      agentRejected = SceneTokens.colorAgentRejected,
      agentInterrupted = SceneTokens.colorAgentInterrupted,
      chartIos = SceneTokens.colorChartIos,
      chartAndroid = SceneTokens.colorChartAndroid,
      chartOther = SceneTokens.colorChartOther,
      panelTop = SceneTokens.colorPanelTop,
      panelHighlight = SceneTokens.colorPanelHighlight,
      line = SceneTokens.colorLine,
      lineStrong = SceneTokens.colorLineStrong,
      inkFaint = SceneTokens.colorInkFaint,
      plasma = SceneTokens.colorPlasma,
      plasmaGhost = SceneTokens.colorPlasmaGhost,
      signalGhost = SceneTokens.colorSignalGhost,
      surface200 = SceneTokens.colorSurface200,
      surface300 = SceneTokens.colorSurface300,
      orbVeil = SceneTokens.colorOrbVeil,
      body = const TextStyle(
        fontSize: SceneTokens.textBodyFontSize,
        height: SceneTokens.textBodyHeight,
        color: SceneTokens.textBodyColor,
      ),
      label = const TextStyle(
        fontSize: SceneTokens.textLabelFontSize,
        height: SceneTokens.textLabelHeight,
        fontWeight: SceneTokens.textLabelFontWeight,
        color: SceneTokens.textLabelColor,
      ),
      value = const TextStyle(
        fontSize: SceneTokens.textValueFontSize,
        height: SceneTokens.textValueHeight,
        fontWeight: SceneTokens.textValueFontWeight,
        color: SceneTokens.textValueColor,
      ),
      title = const TextStyle(
        fontSize: SceneTokens.textTitleFontSize,
        height: SceneTokens.textTitleHeight,
        fontWeight: SceneTokens.textTitleFontWeight,
        color: SceneTokens.textTitleColor,
      ),
      actIndicator = const TextStyle(
        fontSize: SceneTokens.textActIndicatorFontSize,
        height: SceneTokens.textActIndicatorHeight,
        fontWeight: SceneTokens.textActIndicatorFontWeight,
        color: SceneTokens.textActIndicatorColor,
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

  /// Bordures des boutons de la Barre d'actions, par ton (`neutral`/`danger`).
  /// Le texte reprend `textPrimary` (neutre) ou `blockingForeground` (danger).
  final Color actionNeutralBorder;
  final Color actionDangerBorder;

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

  // Rôles ajoutés par le design system du 2026-11-02 (pdr-0084).
  /// Haut du dégradé vertical des panneaux (`surface-200`).
  final Color panelTop;

  /// Filet de 1 px en haut des panneaux (partie `inset` de l'ombre `panel`).
  final Color panelHighlight;

  /// Bordure de 1 px des panneaux et séparateurs (décoratif, jamais de texte).
  final Color line;

  /// Coins HUD et bordure des contrôles (2,30:1 sur `surface-100`, pas 3:1).
  final Color lineStrong;

  /// Graduations d'axe et état « en veille » (grand texte, 24 px et plus).
  final Color inkFaint;

  /// Identité de l'orchestrateur et de la voix IA (jamais une donnée).
  final Color plasma;

  /// Halo de l'orbe et fond du segment d'acte actif.
  final Color plasmaGhost;

  /// Halo et fond de chip « utilisé » du catalogue.
  final Color signalGhost;

  /// Lignes survolées et pistes de jauge.
  final Color surface200;

  /// Contrôles au repos et piste du curseur de rejeu.
  final Color surface300;

  /// Voile de l'orbe vocal.
  final Color orbVeil;

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
    Color? actionNeutralBorder,
    Color? actionDangerBorder,
    Color? agentWorking,
    Color? agentIdle,
    Color? agentRejected,
    Color? agentInterrupted,
    Color? chartIos,
    Color? chartAndroid,
    Color? chartOther,
    Color? panelTop,
    Color? panelHighlight,
    Color? line,
    Color? lineStrong,
    Color? inkFaint,
    Color? plasma,
    Color? plasmaGhost,
    Color? signalGhost,
    Color? surface200,
    Color? surface300,
    Color? orbVeil,
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
      actionNeutralBorder: actionNeutralBorder ?? this.actionNeutralBorder,
      actionDangerBorder: actionDangerBorder ?? this.actionDangerBorder,
      agentWorking: agentWorking ?? this.agentWorking,
      agentIdle: agentIdle ?? this.agentIdle,
      agentRejected: agentRejected ?? this.agentRejected,
      agentInterrupted: agentInterrupted ?? this.agentInterrupted,
      chartIos: chartIos ?? this.chartIos,
      chartAndroid: chartAndroid ?? this.chartAndroid,
      chartOther: chartOther ?? this.chartOther,
      panelTop: panelTop ?? this.panelTop,
      panelHighlight: panelHighlight ?? this.panelHighlight,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      inkFaint: inkFaint ?? this.inkFaint,
      plasma: plasma ?? this.plasma,
      plasmaGhost: plasmaGhost ?? this.plasmaGhost,
      signalGhost: signalGhost ?? this.signalGhost,
      surface200: surface200 ?? this.surface200,
      surface300: surface300 ?? this.surface300,
      orbVeil: orbVeil ?? this.orbVeil,
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
      actionNeutralBorder: c(actionNeutralBorder, other.actionNeutralBorder),
      actionDangerBorder: c(actionDangerBorder, other.actionDangerBorder),
      agentWorking: c(agentWorking, other.agentWorking),
      agentIdle: c(agentIdle, other.agentIdle),
      agentRejected: c(agentRejected, other.agentRejected),
      agentInterrupted: c(agentInterrupted, other.agentInterrupted),
      chartIos: c(chartIos, other.chartIos),
      chartAndroid: c(chartAndroid, other.chartAndroid),
      chartOther: c(chartOther, other.chartOther),
      panelTop: c(panelTop, other.panelTop),
      panelHighlight: c(panelHighlight, other.panelHighlight),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      inkFaint: c(inkFaint, other.inkFaint),
      plasma: c(plasma, other.plasma),
      plasmaGhost: c(plasmaGhost, other.plasmaGhost),
      signalGhost: c(signalGhost, other.signalGhost),
      surface200: c(surface200, other.surface200),
      surface300: c(surface300, other.surface300),
      orbVeil: c(orbVeil, other.orbVeil),
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
      other.actionNeutralBorder == actionNeutralBorder &&
      other.actionDangerBorder == actionDangerBorder &&
      other.agentWorking == agentWorking &&
      other.agentIdle == agentIdle &&
      other.agentRejected == agentRejected &&
      other.agentInterrupted == agentInterrupted &&
      other.chartIos == chartIos &&
      other.chartAndroid == chartAndroid &&
      other.chartOther == chartOther &&
      other.panelTop == panelTop &&
      other.panelHighlight == panelHighlight &&
      other.line == line &&
      other.lineStrong == lineStrong &&
      other.inkFaint == inkFaint &&
      other.plasma == plasma &&
      other.plasmaGhost == plasmaGhost &&
      other.signalGhost == signalGhost &&
      other.surface200 == surface200 &&
      other.surface300 == surface300 &&
      other.orbVeil == orbVeil &&
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
    actionNeutralBorder,
    actionDangerBorder,
    agentWorking,
    agentIdle,
    agentRejected,
    agentInterrupted,
    chartIos,
    chartAndroid,
    chartOther,
    panelTop,
    panelHighlight,
    line,
    lineStrong,
    inkFaint,
    plasma,
    plasmaGhost,
    signalGhost,
    surface200,
    surface300,
    orbVeil,
    body,
    label,
    value,
    title,
    actIndicator,
  ]);
}
