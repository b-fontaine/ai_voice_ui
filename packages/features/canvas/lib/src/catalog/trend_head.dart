import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart';

import 'text_metrics.dart';

/// Distance de la valeur de tête au disque et de l'annotation au seuil.
const double trendHeadGap = 12;
const double trendCalloutGap = 8;

/// Rayon du disque de tête (`.head`, r = 5).
const double trendHeadRadius = 5;

/// Point de tête, sa valeur et l'annotation : apparaissent après le tracé
/// (`gc-rise`, sans flou), en widgets `Text` posés par la géométrie.
class TrendHeadLayer extends StatelessWidget {
  const TrendHeadLayer({
    super.key,
    required this.animation,
    required this.reveal,
    required this.plot,
    required this.head,
    required this.color,
    required this.value,
    required this.aboveThreshold,
    required this.callout,
    required this.calloutAt,
  });

  final Animation<double> animation;

  /// Lecture complète du tracé (1 à la fin) : l'anneau de tête attend sa fin.
  final Animation<double> reveal;
  final Rect plot;

  /// Centre du disque de tête, dans la région du graphique.
  final Offset head;
  final Color color;
  final String value;
  final bool aboveThreshold;
  final String? callout;

  /// Croisement du seuil, dans la région du graphique.
  final Offset? calloutAt;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final TextStyle calloutStyle = theme.micro.callout.copyWith(
      color: theme.blockingForeground,
    );
    final double textHeight = lineHeightOf(theme.micro.callout);
    return DsReveal(
      animation: animation,
      from: const Offset(0, SceneMotion.translation),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: head.dx - trendHeadRadius,
              top: head.dy - trendHeadRadius,
              width: 2 * trendHeadRadius,
              height: 2 * trendHeadRadius,
              child: TrendHeadRing(
                key: const Key('trend-head-ring'),
                reveal: reveal,
                color: SceneTheme.of(context).accent,
              ),
            ),
            Positioned(
              left: head.dx - trendHeadRadius,
              top: head.dy - trendHeadRadius,
              width: 2 * trendHeadRadius,
              height: 2 * trendHeadRadius,
              child: DecoratedBox(
                key: const Key('trend-head'),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: box.maxWidth - (head.dx - trendHeadGap),
              bottom:
                  box.maxHeight - math.max(head.dy - 4, plot.top + textHeight),
              child: Text(
                value,
                key: const Key('trend-head-value'),
                style: aboveThreshold
                    ? calloutStyle
                    : calloutStyle.copyWith(color: theme.textSecondary),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            if (callout != null && calloutAt != null)
              Positioned(
                left: calloutAt!.dx + trendHeadGap,
                top: calloutAt!.dy + trendCalloutGap,
                child: Text(
                  callout!,
                  key: const Key('trend-callout'),
                  style: calloutStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Anneau de tête (`gc-ring`, 1,8 s, pdr-0088 F9) : un cercle `signal` de
/// trait 2 qui grossit de 1 à 3 en s'estompant de .9 à 0, en boucle, **une fois
/// le tracé fini** ([reveal] à 1). Il s'éteint quand le tracé rejoue.
///
/// Un contrôleur propre, lancé une fois par `SceneMotionScope.loop` à la fin du
/// tracé, dans son propre `RepaintBoundary` ; le painter écoute le contrôleur
/// (pas de reconstruction par image : le graphique est sous des
/// `LayoutBuilder`). **Phase de repos** (animations coupées) : invisible, aucun
/// `Ticker`.
class TrendHeadRing extends StatefulWidget {
  const TrendHeadRing({super.key, required this.reveal, required this.color});

  final Animation<double> reveal;
  final Color color;

  @override
  State<TrendHeadRing> createState() => _TrendHeadRingState();
}

class _TrendHeadRingState extends State<TrendHeadRing>
    with SingleTickerProviderStateMixin, SceneLoop<TrendHeadRing> {
  @override
  Duration get loopBase => SceneMotion.ring;

  // Boucle à la fin du tracé, repos (invisible, phase 0) pendant le tracé et
  // sous `disabled`.
  @override
  bool get loopActive =>
      widget.reveal.isCompleted && !SceneMotionScope.of(context).disabled;

  @override
  void initState() {
    super.initState();
    widget.reveal.addStatusListener(_onRevealStatus);
  }

  @override
  void didUpdateWidget(TrendHeadRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reveal != widget.reveal) {
      oldWidget.reveal.removeStatusListener(_onRevealStatus);
      widget.reveal.addStatusListener(_onRevealStatus);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _onRevealStatus(AnimationStatus status) => _sync();

  void _sync() {
    syncLoop();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.reveal.removeStatusListener(_onRevealStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TrendHeadRingPainter(
            phase: loop,
            color: widget.color,
            visible: loopActive,
          ),
        ),
      ),
    );
  }
}

class _TrendHeadRingPainter extends CustomPainter {
  _TrendHeadRingPainter({
    required this.phase,
    required this.color,
    required this.visible,
  }) : super(repaint: phase);

  /// Échelle finale de l'anneau (`scale(3)`) et opacité de départ (.9).
  static const double _endScale = 3;
  static const double _startOpacity = 0.9;

  /// Épaisseur du trait au départ (`stroke-width: 2`, mise à l'échelle avec
  /// le cercle).
  static const double _stroke = 2;

  final Animation<double> phase;
  final Color color;

  /// Faux pendant le tracé et sous animations coupées : rien n'est peint.
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final double t = Curves.easeOut.transform(phase.value);
    final double scale = 1 + (_endScale - 1) * t;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke * scale
        ..color = color.withValues(alpha: _startOpacity * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_TrendHeadRingPainter old) =>
      old.phase != phase || old.color != color || old.visible != visible;
}
