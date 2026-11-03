import 'package:flutter/material.dart';

import 'scene_motion.dart';
import 'scene_one_shot.dart';
import 'scene_theme.dart';

/// Clés posées sur les parties d'une [DsGauge] (les scénarios et les tests
/// observent chaque partie par sa clé).
class DsGaugeKeys {
  const DsGaugeKeys({
    this.track,
    this.fill,
    this.mark,
    this.markLabel,
    this.reference,
    this.referenceLabel,
  });

  /// La piste (largeur de référence des positions).
  final Key? track;

  /// Le remplissage (sa largeur est celle de la valeur courante).
  final Key? fill;

  /// La marque de seuil.
  final Key? mark;

  /// L'étiquette de la marque de seuil (un `Text`).
  final Key? markLabel;

  /// Le repère de comparaison.
  final Key? reference;

  /// L'étiquette du repère de comparaison (un `Text`).
  final Key? referenceLabel;
}

/// Jauge d'un indicateur clé (`.gc-gauge`, pdr-0088 F3) : piste de [trackHeight]
/// px en `surface-300` (rayon 4), remplissage de la couleur donnée, marque de
/// seuil et repère de comparaison.
///
/// Toutes les positions sont des **fractions** (0 à 1) de la largeur de la
/// piste, déjà calculées par l'appelant sur le domaine de la jauge : la brique
/// ne connaît ni pourcentage ni donnée.
/// - la marque de seuil (2 px en `ink`) dépasse la piste de 6 px ; son
///   étiquette (style `tick`, `ink-muted`) est au-dessus ;
/// - le repère de comparaison (2 px en `baseline`) dépasse de 3 px ; son
///   étiquette est dessous ;
/// - une étiquette reste dans la largeur de la piste (elle se décale au lieu
///   de déborder).
///
/// Le remplissage se joue en [SceneMotion.gauge] (`SceneOneShot`) au montage
/// puis à chaque changement de [fill] ; immédiat sous `SceneMotionScope`
/// `disabled`, et absent de l'animation si [settled] (surface restaurée). La
/// jauge porte son propre `RepaintBoundary`.
class DsGauge extends StatefulWidget {
  const DsGauge({
    super.key,
    required this.fill,
    required this.fillColor,
    this.mark,
    this.markLabel,
    this.reference,
    this.referenceLabel,
    this.settled = false,
    this.keys = const DsGaugeKeys(),
  });

  /// Hauteur de la piste.
  static const double trackHeight = 8;

  /// Largeur de la marque et du repère.
  static const double tickWidth = 2;

  /// Dépassement de la marque de seuil au-dessus et au-dessous de la piste.
  static const double markOverhang = 6;

  /// Dépassement du repère de comparaison.
  static const double referenceOverhang = 3;

  /// Écart entre une graduation et son étiquette.
  static const double labelGap = 4;

  /// Part du remplissage (0 à 1) de la piste.
  final double fill;

  /// Couleur du remplissage, donnée par l'appelant (rôle de statut).
  final Color fillColor;

  /// Position (0 à 1) de la marque de seuil ; `null` : pas de marque.
  final double? mark;

  /// Étiquette de la marque ; sans [mark], elle n'est pas affichée.
  final String? markLabel;

  /// Position (0 à 1) du repère de comparaison ; `null` : pas de repère.
  final double? reference;

  /// Étiquette du repère ; sans [reference], elle n'est pas affichée.
  final String? referenceLabel;

  /// Vrai : le remplissage est déjà en place, sans animation au montage.
  final bool settled;

  /// Clés des parties.
  final DsGaugeKeys keys;

  @override
  State<DsGauge> createState() => _DsGaugeState();
}

class _DsGaugeState extends State<DsGauge>
    with SingleTickerProviderStateMixin<DsGauge>, SceneOneShot<DsGauge> {
  bool _started = false;

  @override
  Duration get oneShotBase => SceneMotion.gauge;

  @override
  double get oneShotInitialValue => widget.settled ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.settled) playOneShot();
  }

  @override
  void didUpdateWidget(DsGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fill != widget.fill) playOneShot();
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final TextStyle labelStyle = theme.micro.tick.copyWith(
      color: theme.textSecondary,
    );
    final double labelHeight =
        (labelStyle.fontSize ?? 12) * (labelStyle.height ?? 1);
    final bool hasMark = widget.mark != null;
    final bool hasMarkLabel = hasMark && widget.markLabel != null;
    final bool hasRef = widget.reference != null;
    final bool hasRefLabel = hasRef && widget.referenceLabel != null;

    // Zone au-dessus de la piste : dépassement de la marque, puis étiquette.
    final double top = hasMarkLabel
        ? DsGauge.markOverhang + DsGauge.labelGap + labelHeight
        : DsGauge.markOverhang;
    // Zone au-dessous : dépassement de la marque, puis étiquette du repère.
    final double bottom = hasRefLabel
        ? DsGauge.markOverhang + DsGauge.labelGap + labelHeight
        : DsGauge.markOverhang;

    return RepaintBoundary(
      child: SizedBox(
        height: top + DsGauge.trackHeight + bottom,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  height: DsGauge.trackHeight,
                  child: DecoratedBox(
                    key: widget.keys.track,
                    decoration: BoxDecoration(
                      color: theme.surface300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedBuilder(
                      animation: oneShot,
                      builder: (BuildContext context, Widget? _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor:
                              widget.fill.clamp(0.0, 1.0) *
                              SceneMotion.curve.transform(oneShot.value),
                          heightFactor: 1,
                          child: DecoratedBox(
                            key: widget.keys.fill,
                            decoration: BoxDecoration(
                              color: widget.fillColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasMark)
                  _tick(
                    key: widget.keys.mark,
                    x: widget.mark!.clamp(0.0, 1.0) * width,
                    top: top - DsGauge.markOverhang,
                    overhang: DsGauge.markOverhang,
                    color: theme.textPrimary,
                  ),
                if (hasMarkLabel)
                  _label(
                    key: widget.keys.markLabel,
                    text: widget.markLabel!,
                    style: labelStyle,
                    center: widget.mark!.clamp(0.0, 1.0) * width,
                    top: 0,
                    height: labelHeight,
                  ),
                if (hasRef)
                  _tick(
                    key: widget.keys.reference,
                    x: widget.reference!.clamp(0.0, 1.0) * width,
                    top: top - DsGauge.referenceOverhang,
                    overhang: DsGauge.referenceOverhang,
                    // `baseline` du design system (8592BB).
                    color: theme.chartOther,
                  ),
                if (hasRefLabel)
                  _label(
                    key: widget.keys.referenceLabel,
                    text: widget.referenceLabel!,
                    style: labelStyle,
                    center: widget.reference!.clamp(0.0, 1.0) * width,
                    top:
                        top +
                        DsGauge.trackHeight +
                        DsGauge.markOverhang +
                        DsGauge.labelGap,
                    height: labelHeight,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tick({
    required Key? key,
    required double x,
    required double top,
    required double overhang,
    required Color color,
  }) => Positioned(
    left: x - DsGauge.tickWidth / 2,
    top: top,
    width: DsGauge.tickWidth,
    height: DsGauge.trackHeight + 2 * overhang,
    child: DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );

  Widget _label({
    required Key? key,
    required String text,
    required TextStyle style,
    required double center,
    required double top,
    required double height,
  }) => Positioned(
    left: 0,
    right: 0,
    top: top,
    height: height,
    child: CustomSingleChildLayout(
      delegate: _CenteredOn(center),
      child: Text(
        text,
        key: key,
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    ),
  );
}

/// Centre l'enfant sur [center] sans le laisser sortir de la largeur offerte.
class _CenteredOn extends SingleChildLayoutDelegate {
  const _CenteredOn(this.center);

  final double center;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double maxLeft = size.width - childSize.width;
    final double left = (center - childSize.width / 2).clamp(
      0.0,
      maxLeft < 0 ? 0.0 : maxLeft,
    );
    return Offset(left, 0);
  }

  @override
  bool shouldRelayout(_CenteredOn oldDelegate) => oldDelegate.center != center;
}
