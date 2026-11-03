import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import 'generated/scene_tokens.g.dart';

/// Micro-styles de texte du design system (`bundle.css`, pdr-0088 F1).
///
/// Objet valeur imbriqué dans `SceneTheme` (`theme.micro.badge`) : ce n'est pas
/// une seconde `ThemeExtension` (RG-09), `SceneTheme` lui délègue `copyWith`,
/// `lerp`, `==` et `hashCode`. Les styles ne portent pas de couleur : elle vient
/// du rôle du composant (règle F12 : jamais `inkFaint` ni `agentIdle` sous
/// 24 px).
@immutable
class SceneMicroStyles {
  const SceneMicroStyles({
    required this.badge,
    required this.badgeLg,
    required this.kpiUnit,
    required this.delta,
    required this.tick,
    required this.legend,
    required this.chip,
    required this.speed,
    required this.quote,
    required this.quoteMeta,
    required this.agentName,
    required this.agentState,
    required this.callout,
    required this.segment,
    required this.segmentNo,
  });

  /// Micro-styles issus des jetons générés (`scene.micro.*`).
  const SceneMicroStyles.dark()
    : badge = const TextStyle(
        fontFamily: SceneTokens.microBadgeFontFamily,
        fontFamilyFallback: SceneTokens.microBadgeFontFamilyFallback,
        fontSize: SceneTokens.microBadgeFontSize,
        height: SceneTokens.microBadgeHeight,
        fontWeight: SceneTokens.microBadgeFontWeight,
        fontVariations: SceneTokens.microBadgeFontVariations,
        letterSpacing: SceneTokens.microBadgeLetterSpacing,
      ),
      badgeLg = const TextStyle(
        fontFamily: SceneTokens.microBadgeLgFontFamily,
        fontFamilyFallback: SceneTokens.microBadgeLgFontFamilyFallback,
        fontSize: SceneTokens.microBadgeLgFontSize,
        height: SceneTokens.microBadgeLgHeight,
        fontWeight: SceneTokens.microBadgeLgFontWeight,
        fontVariations: SceneTokens.microBadgeLgFontVariations,
        letterSpacing: SceneTokens.microBadgeLgLetterSpacing,
      ),
      kpiUnit = const TextStyle(
        fontFamily: SceneTokens.microKpiUnitFontFamily,
        fontFamilyFallback: SceneTokens.microKpiUnitFontFamilyFallback,
        fontSize: SceneTokens.microKpiUnitFontSize,
        height: SceneTokens.microKpiUnitHeight,
        fontWeight: SceneTokens.microKpiUnitFontWeight,
        fontVariations: SceneTokens.microKpiUnitFontVariations,
        letterSpacing: SceneTokens.microKpiUnitLetterSpacing,
      ),
      delta = const TextStyle(
        fontFamily: SceneTokens.microDeltaFontFamily,
        fontFamilyFallback: SceneTokens.microDeltaFontFamilyFallback,
        fontSize: SceneTokens.microDeltaFontSize,
        height: SceneTokens.microDeltaHeight,
        fontWeight: SceneTokens.microDeltaFontWeight,
        fontVariations: SceneTokens.microDeltaFontVariations,
      ),
      tick = const TextStyle(
        fontFamily: SceneTokens.microTickFontFamily,
        fontFamilyFallback: SceneTokens.microTickFontFamilyFallback,
        fontSize: SceneTokens.microTickFontSize,
        height: SceneTokens.microTickHeight,
        fontWeight: SceneTokens.microTickFontWeight,
        fontVariations: SceneTokens.microTickFontVariations,
      ),
      legend = const TextStyle(
        fontFamily: SceneTokens.microLegendFontFamily,
        fontFamilyFallback: SceneTokens.microLegendFontFamilyFallback,
        fontSize: SceneTokens.microLegendFontSize,
        height: SceneTokens.microLegendHeight,
        fontWeight: SceneTokens.microLegendFontWeight,
        fontVariations: SceneTokens.microLegendFontVariations,
      ),
      chip = const TextStyle(
        fontFamily: SceneTokens.microChipFontFamily,
        fontFamilyFallback: SceneTokens.microChipFontFamilyFallback,
        fontSize: SceneTokens.microChipFontSize,
        height: SceneTokens.microChipHeight,
        fontWeight: SceneTokens.microChipFontWeight,
        fontVariations: SceneTokens.microChipFontVariations,
      ),
      speed = const TextStyle(
        fontFamily: SceneTokens.microSpeedFontFamily,
        fontFamilyFallback: SceneTokens.microSpeedFontFamilyFallback,
        fontSize: SceneTokens.microSpeedFontSize,
        height: SceneTokens.microSpeedHeight,
        fontWeight: SceneTokens.microSpeedFontWeight,
        fontVariations: SceneTokens.microSpeedFontVariations,
      ),
      quote = const TextStyle(
        fontFamily: SceneTokens.microQuoteFontFamily,
        fontFamilyFallback: SceneTokens.microQuoteFontFamilyFallback,
        fontSize: SceneTokens.microQuoteFontSize,
        height: SceneTokens.microQuoteHeight,
        fontWeight: SceneTokens.microQuoteFontWeight,
        fontVariations: SceneTokens.microQuoteFontVariations,
      ),
      quoteMeta = const TextStyle(
        fontFamily: SceneTokens.microQuoteMetaFontFamily,
        fontFamilyFallback: SceneTokens.microQuoteMetaFontFamilyFallback,
        fontSize: SceneTokens.microQuoteMetaFontSize,
        height: SceneTokens.microQuoteMetaHeight,
        fontWeight: SceneTokens.microQuoteMetaFontWeight,
        fontVariations: SceneTokens.microQuoteMetaFontVariations,
      ),
      agentName = const TextStyle(
        fontFamily: SceneTokens.microAgentNameFontFamily,
        fontFamilyFallback: SceneTokens.microAgentNameFontFamilyFallback,
        fontSize: SceneTokens.microAgentNameFontSize,
        height: SceneTokens.microAgentNameHeight,
        fontWeight: SceneTokens.microAgentNameFontWeight,
        fontVariations: SceneTokens.microAgentNameFontVariations,
      ),
      agentState = const TextStyle(
        fontFamily: SceneTokens.microAgentStateFontFamily,
        fontFamilyFallback: SceneTokens.microAgentStateFontFamilyFallback,
        fontSize: SceneTokens.microAgentStateFontSize,
        height: SceneTokens.microAgentStateHeight,
        fontWeight: SceneTokens.microAgentStateFontWeight,
        fontVariations: SceneTokens.microAgentStateFontVariations,
      ),
      callout = const TextStyle(
        fontFamily: SceneTokens.microCalloutFontFamily,
        fontFamilyFallback: SceneTokens.microCalloutFontFamilyFallback,
        fontSize: SceneTokens.microCalloutFontSize,
        height: SceneTokens.microCalloutHeight,
        fontWeight: SceneTokens.microCalloutFontWeight,
        fontVariations: SceneTokens.microCalloutFontVariations,
      ),
      segment = const TextStyle(
        fontFamily: SceneTokens.microSegmentFontFamily,
        fontFamilyFallback: SceneTokens.microSegmentFontFamilyFallback,
        fontSize: SceneTokens.microSegmentFontSize,
        height: SceneTokens.microSegmentHeight,
        fontWeight: SceneTokens.microSegmentFontWeight,
        fontVariations: SceneTokens.microSegmentFontVariations,
      ),
      segmentNo = const TextStyle(
        fontFamily: SceneTokens.microSegmentNoFontFamily,
        fontFamilyFallback: SceneTokens.microSegmentNoFontFamilyFallback,
        fontSize: SceneTokens.microSegmentNoFontSize,
        height: SceneTokens.microSegmentNoHeight,
        fontWeight: SceneTokens.microSegmentNoFontWeight,
        fontVariations: SceneTokens.microSegmentNoFontVariations,
      );

  /// Pastille de statut (`.gc-badge`) : mono 600 12 px, 0,08 em, capitales.
  final TextStyle badge;

  /// Grande pastille du verdict (`.gc-badge--lg`) : mono 600 18 px, 0,1 em.
  final TextStyle badgeLg;

  /// Unité du chiffre héros (`.gc-kpi__value small`) : mono 600 36 px, sans interlettrage.
  final TextStyle kpiUnit;

  /// Deltas du KeyIndicator (`.gc-kpi__deltas`) : mono 500 14/20.
  final TextStyle delta;

  /// Graduations des axes (`.gc-chart .tick`) : mono 500 12.
  final TextStyle tick;

  /// Légende de graphique (`.gc-legend`) : mono 500 13/18.
  final TextStyle legend;

  /// Puce du catalogue (`.gc-chip`) : mono 500 13.
  final TextStyle chip;

  /// Bouton de vitesse du rejeu (`.gc-speed`) : mono 500 12.
  final TextStyle speed;

  /// Verbatim d'avis (`.gc-quote p`) : sans 400 15/22.
  final TextStyle quote;

  /// Note et plateforme d'un verbatim (`.gc-quote__meta`) : mono 600 12/18.
  final TextStyle quoteMeta;

  /// Nom d'agent (`.gc-agent__name`) : sans 600 15/20.
  final TextStyle agentName;

  /// État d'agent (`.gc-agent__state`) : mono 500 12/18.
  final TextStyle agentState;

  /// Annotation de graphique (`.gc-chart .callout`) : mono 600 12.
  final TextStyle callout;

  /// Texte d'un segment d'acte (`.gc-act`) : sans 600 13.
  final TextStyle segment;

  /// Numéro d'un segment d'acte (`.gc-act b`) : mono 600 11.
  final TextStyle segmentNo;

  SceneMicroStyles copyWith({
    TextStyle? badge,
    TextStyle? badgeLg,
    TextStyle? kpiUnit,
    TextStyle? delta,
    TextStyle? tick,
    TextStyle? legend,
    TextStyle? chip,
    TextStyle? speed,
    TextStyle? quote,
    TextStyle? quoteMeta,
    TextStyle? agentName,
    TextStyle? agentState,
    TextStyle? callout,
    TextStyle? segment,
    TextStyle? segmentNo,
  }) {
    return SceneMicroStyles(
      badge: badge ?? this.badge,
      badgeLg: badgeLg ?? this.badgeLg,
      kpiUnit: kpiUnit ?? this.kpiUnit,
      delta: delta ?? this.delta,
      tick: tick ?? this.tick,
      legend: legend ?? this.legend,
      chip: chip ?? this.chip,
      speed: speed ?? this.speed,
      quote: quote ?? this.quote,
      quoteMeta: quoteMeta ?? this.quoteMeta,
      agentName: agentName ?? this.agentName,
      agentState: agentState ?? this.agentState,
      callout: callout ?? this.callout,
      segment: segment ?? this.segment,
      segmentNo: segmentNo ?? this.segmentNo,
    );
  }

  /// Interpolation style par style.
  SceneMicroStyles lerp(SceneMicroStyles other, double t) {
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return SceneMicroStyles(
      badge: s(badge, other.badge),
      badgeLg: s(badgeLg, other.badgeLg),
      kpiUnit: s(kpiUnit, other.kpiUnit),
      delta: s(delta, other.delta),
      tick: s(tick, other.tick),
      legend: s(legend, other.legend),
      chip: s(chip, other.chip),
      speed: s(speed, other.speed),
      quote: s(quote, other.quote),
      quoteMeta: s(quoteMeta, other.quoteMeta),
      agentName: s(agentName, other.agentName),
      agentState: s(agentState, other.agentState),
      callout: s(callout, other.callout),
      segment: s(segment, other.segment),
      segmentNo: s(segmentNo, other.segmentNo),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SceneMicroStyles &&
      other.badge == badge &&
      other.badgeLg == badgeLg &&
      other.kpiUnit == kpiUnit &&
      other.delta == delta &&
      other.tick == tick &&
      other.legend == legend &&
      other.chip == chip &&
      other.speed == speed &&
      other.quote == quote &&
      other.quoteMeta == quoteMeta &&
      other.agentName == agentName &&
      other.agentState == agentState &&
      other.callout == callout &&
      other.segment == segment &&
      other.segmentNo == segmentNo;

  @override
  int get hashCode => Object.hashAll(<Object>[
    badge,
    badgeLg,
    kpiUnit,
    delta,
    tick,
    legend,
    chip,
    speed,
    quote,
    quoteMeta,
    agentName,
    agentState,
    callout,
    segment,
    segmentNo,
  ]);
}
