import 'package:flutter/material.dart';

import 'ds_beacon.dart' show DsBeacon;
import 'ds_caps.dart';
import 'scene_radius.dart';
import 'scene_shadow.dart';
import 'scene_status.dart';
import 'scene_text_style.dart';
import 'scene_theme.dart';

/// Pastille de statut : la couleur vient du [SceneStatus], le libellé
/// (fourni par le backend) est affiché tel quel dans la donnée, en capitales
/// à l'affichage (`DsCaps`, le `Semantics` garde la casse d'origine). Statut
/// `null` : style neutre (`gc-badge--idle`).
///
/// Selon le design system (`gc-badge`, pdr-0088 F1, pdr-0084 U6) :
/// - pilule de [height] (26) px, grande puce [large] de [largeHeight] (40) px
///   pour le verdict, avec la lueur `glow-nogo` si le statut est bloquant ;
/// - bordure de 1 px à la couleur du mot (`currentColor`) ; statut inconnu :
///   bordure `line-strong` ;
/// - `ok` porte un glyphe ✓ de la couleur `go`, séparé du mot ;
/// - `blocking` porte un point de [dotSize] px `nogo` qui bat (`gc-beacon`,
///   seule animation en boucle des statuts) ;
/// - `risk` et le statut inconnu n'ont ni glyphe ni point.
///
/// Le glyphe et le point sont décoratifs : ils sont exclus de la sémantique,
/// seul le mot est annoncé.
class DsStatusChip extends StatelessWidget {
  const DsStatusChip({
    super.key,
    required this.status,
    required this.label,
    this.large = false,
  });

  /// Hauteur d'une puce (`.gc-badge`).
  static const double height = 26;

  /// Hauteur de la grande puce du verdict (`.gc-badge--lg`).
  static const double largeHeight = 40;

  /// Remplissage horizontal de chaque côté du contenu (bordure non comprise).
  static const double horizontalPadding = 11;

  /// Remplissage horizontal de la grande puce.
  static const double largeHorizontalPadding = 18;

  /// Épaisseur de la bordure.
  static const double borderWidth = 1;

  /// Diamètre du point de Bloquant.
  static const double dotSize = 6;

  /// Espace entre le glyphe ou le point et le mot.
  static const double leadingGap = 7;

  /// Corps du glyphe ✓.
  static const double glyphFontSize = 12;

  /// Glyphe du statut `ok`.
  static const String okGlyph = '✓';

  final SceneStatus? status;
  final String label;

  /// Grande puce du verdict (40 px, texte `badgeLg`).
  final bool large;

  static TextStyle _wordStyle(SceneTheme theme, bool large) =>
      large ? theme.micro.badgeLg : theme.micro.badge;

  static TextStyle _glyphStyle(SceneTheme theme) =>
      theme.micro.badge.copyWith(fontSize: glyphFontSize);

  /// Géométrie réelle d'une puce de [status] portant [label], avec les polices
  /// du thème de [context] (capitales, glyphe et point compris).
  ///
  /// C'est la source unique de la taille : la puce s'en sert pour son rendu,
  /// et les mises en page qui réservent sa place (colonne des puces de la
  /// checklist) l'appellent au lieu de recalculer les remplissages.
  static Size measure(
    BuildContext context,
    SceneStatus? status,
    String label, {
    bool large = false,
  }) {
    final SceneTheme theme = SceneTheme.of(context);
    final Size word = _textSize(
      context,
      label.toUpperCase(),
      _wordStyle(theme, large),
    );
    final double leading = switch (status) {
      SceneStatus.ok =>
        _textSize(context, okGlyph, _glyphStyle(theme)).width + leadingGap,
      SceneStatus.blocking => dotSize + leadingGap,
      SceneStatus.risk || null => 0,
    };
    final double padding = large ? largeHorizontalPadding : horizontalPadding;
    return Size(
      2 * (borderWidth + padding) + leading + word.width,
      large ? largeHeight : height,
    );
  }

  static Size _textSize(BuildContext context, String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: sceneTextStyle(context, style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final Size size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final Color color = theme.statusForeground(status);
    final Widget? leading = switch (status) {
      SceneStatus.ok => ExcludeSemantics(
        child: Text(
          okGlyph,
          style: _glyphStyle(theme).copyWith(color: color),
          maxLines: 1,
        ),
      ),
      SceneStatus.blocking => ExcludeSemantics(
        child: DsBeacon(color: color, size: dotSize),
      ),
      SceneStatus.risk || null => null,
    };
    return Container(
      height: large ? largeHeight : height,
      padding: EdgeInsets.symmetric(
        horizontal: large ? largeHorizontalPadding : horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: theme.statusBackground(status),
        borderRadius: SceneRadius.borderPill,
        border: Border.all(
          color: status == null ? theme.lineStrong : color,
          width: borderWidth,
        ),
        boxShadow: large && status == SceneStatus.blocking
            ? SceneShadow.glowNogo
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading,
            const SizedBox(width: leadingGap),
          ],
          Flexible(
            child: DsCaps(
              label,
              style: _wordStyle(theme, large).copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
