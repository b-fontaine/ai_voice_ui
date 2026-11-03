import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ds_caps.dart';
import 'scene_motion.dart';
import 'scene_radius.dart';
import 'scene_shadow.dart';
import 'scene_theme.dart';

/// Cadre de génération (`gc-gen`, pdr-0088 F11) : il signale qu'un agent écrit
/// ce panneau.
///
/// Le cadre couvre toute la cellule de son parent et peint dans le rectangle
/// réduit de [inset] (comme le contour de surbrillance), avec le rayon `lg` :
/// - une **bordure de 2 px** en arc (`SweepGradient` tournant, transparent puis
///   `signal`, `ink`, `signal`) qui fait un tour en 2,8 s (`gc-spin`) ;
/// - un **balayage** de 40 % de la hauteur, de transparent à `signal` à 25 %,
///   qui descend en 2,2 s (`gc-scan`) ;
/// - une **étiquette** « `Agent` · génère » (« génère » seul sans [agent]) en
///   haut à droite, **dans** la cellule (le `top: -11px` de la source déborde).
///
/// **Un seul contrôleur** donne les deux phases : sa période est le plus petit
/// multiple commun des deux durées, dont on tire la rotation et le balayage.
/// Un seul `RepaintBoundary` (clé `generation-frame-{surfaceId}`) isole la
/// peinture ; le fondu est un widget d'opacité **au-dessus** de cette clé et
/// l'étiquette, statique, est hors de la zone repeinte.
///
/// Avec [done] (l'agent a fini), le tour en cours s'achève (2,8 s) puis le
/// cadre s'estompe (0,6 s) ; [onFinished] est alors appelé une fois, après la
/// dernière image : l'appelant retire le cadre, plus aucune boucle ne reste.
///
/// Sous `SceneMotionScope.disabled` (scénario, capture, « réduire les
/// animations ») : cadre **statique** (arc au repos, pas de balayage) et, dès
/// [done], retiré **sans fondu** ([onFinished] aussitôt).
class DsGenFrame extends StatefulWidget {
  const DsGenFrame({
    super.key,
    required this.surfaceId,
    this.agent,
    this.done = false,
    this.onFinished,
    this.inset = 0,
  });

  /// Épaisseur de la bordure (`padding: 2px`).
  static const double borderWidth = 2;

  /// Hauteur de l'étiquette (`.gc-gen__tag`).
  static const double tagHeight = 22;

  /// Distance de l'étiquette au bord droit du cadre peint.
  static const double tagRight = 20;

  /// Remplissage horizontal de l'étiquette.
  static const double tagPadding = 10;

  /// Côté du losange de l'étiquette.
  static const double diamond = 6;

  /// Écart entre le losange et le texte.
  static const double tagGap = 6;

  /// Part de la hauteur occupée par la bande du balayage.
  static const double scanHeight = 0.4;

  /// Opacité du bord clair du balayage (`#3de8ff40`).
  static const double scanAlpha = 0.25;

  /// Opacité du milieu du balayage (`#3de8ff14`).
  static const double scanMidAlpha = 0.08;

  /// Identifiant de la surface cadrée : il fait les clés
  /// `generation-frame-{surfaceId}` (cadre) et `…-tag` (étiquette).
  final String surfaceId;

  /// Nom de l'agent qui génère, ou `null` (scénarios, rejeu).
  final String? agent;

  /// L'agent a fini : dernier tour puis fondu.
  final bool done;

  /// Appelé une fois quand le cadre est terminé et peut être retiré.
  final VoidCallback? onFinished;

  /// Marge entre le bord de la cellule et le rectangle peint.
  final double inset;

  /// Phases à l'instant [value] (0 à 1) du contrôleur unique.
  ///
  /// En boucle, [value] couvre [loopPeriod] : la rotation fait
  /// `loopPeriod / spin` tours et le balayage `loopPeriod / scan` passages.
  /// Avec [done], [value] couvre [doneDuration] : un tour, un passage du
  /// balayage (qui disparaît ensuite : `scan` est `null`), puis le fondu.
  @visibleForTesting
  static ({double spin, double? scan, double opacity}) phasesAt(
    double value, {
    required bool done,
  }) {
    if (!done) {
      return (
        spin: (value * _spinTurns) % 1.0,
        scan: (value * _scanPasses) % 1.0,
        opacity: 1,
      );
    }
    final double elapsed = value * doneDuration.inMicroseconds;
    final double spinUs = SceneMotion.spin.inMicroseconds.toDouble();
    final double scanUs = SceneMotion.scan.inMicroseconds.toDouble();
    final double fadeUs = SceneMotion.fade.inMicroseconds.toDouble();
    final double fade = ((elapsed - spinUs) / fadeUs).clamp(0.0, 1.0);
    return (
      spin: math.min(1.0, elapsed / spinUs),
      scan: elapsed < scanUs ? elapsed / scanUs : null,
      opacity: 1 - Curves.ease.transform(fade),
    );
  }

  /// Période de la boucle : plus petit multiple commun de la rotation et du
  /// balayage.
  static Duration get loopPeriod => Duration(microseconds: _loopMicros);

  /// Durée de la fin : le dernier tour, puis le fondu.
  static Duration get doneDuration => SceneMotion.spin + SceneMotion.fade;

  static final int _loopMicros = _lcm(
    SceneMotion.spin.inMicroseconds,
    SceneMotion.scan.inMicroseconds,
  );
  static final int _spinTurns = _loopMicros ~/ SceneMotion.spin.inMicroseconds;
  static final int _scanPasses = _loopMicros ~/ SceneMotion.scan.inMicroseconds;

  static int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;
  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  @override
  State<DsGenFrame> createState() => _DsGenFrameState();
}

class _DsGenFrameState extends State<DsGenFrame>
    with SingleTickerProviderStateMixin<DsGenFrame> {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DsGenFrame.loopPeriod,
  );

  bool _doneStarted = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((AnimationStatus status) {
      // Fin du fondu : on est dans l'image qui le termine (hors construction),
      // le parent peut retirer le cadre dans cette même image.
      if (status == AnimationStatus.completed && widget.done && !_finished) {
        _finished = true;
        widget.onFinished?.call();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DsGenFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  // Boucle, fin ou repos selon le réglage d'animation de la scène.
  void _sync() {
    final SceneMotionScope scope = SceneMotionScope.of(context);
    if (!widget.done) {
      _doneStarted = false;
      _finished = false;
      SceneMotionScope.loop(context, _controller, DsGenFrame.loopPeriod);
      if (scope.disabled) _controller.value = 0;
      return;
    }
    if (scope.disabled) {
      _controller.stop();
      _finish();
    } else if (!_doneStarted) {
      _doneStarted = true;
      _controller.duration = scope.durationFor(DsGenFrame.doneDuration);
      _controller.forward(from: 0);
    }
  }

  // Animations coupées : on est pendant une construction, l'appelant retire le
  // cadre après cette image.
  void _finish() {
    if (_finished) return;
    _finished = true;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final String label = widget.agent == null
        ? _generates
        : '${widget.agent} · $_generates';
    final double tagTop = math.max(0, widget.inset - DsGenFrame.tagHeight / 2);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        // Peinture et étiquette sont construites une fois : seule l'opacité
        // suit l'image, au-dessus de la clé du cadre.
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              key: ValueKey<String>('generation-frame-${widget.surfaceId}'),
              child: SizedBox.expand(
                child: CustomPaint(
                  painter: _GenFramePainter(
                    animation: _controller,
                    done: widget.done,
                    signal: theme.accent,
                    ink: theme.textPrimary,
                    inset: widget.inset,
                  ),
                ),
              ),
            ),
            Positioned(
              top: tagTop,
              right: DsGenFrame.tagRight + widget.inset,
              child: _GenTag(
                key: ValueKey<String>(
                  'generation-frame-${widget.surfaceId}-tag',
                ),
                label: label,
                theme: theme,
              ),
            ),
          ],
        ),
        builder: (BuildContext context, Widget? child) {
          final double opacity = DsGenFrame.phasesAt(
            _controller.value,
            done: widget.done,
          ).opacity;
          return Opacity(opacity: opacity, child: child);
        },
      ),
    );
  }

  static const String _generates = 'génère';
}

/// Pastille « `Agent` · génère » : fond `void`, bordure et texte `signal`,
/// capitales, lueur `signal`. Le losange est statique ici (le clignotement
/// `gc-blink` est de niveau B).
class _GenTag extends StatelessWidget {
  const _GenTag({super.key, required this.label, required this.theme});

  final String label;
  final SceneTheme theme;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: theme.background,
      borderRadius: SceneRadius.borderPill,
      border: Border.all(color: theme.accent),
      boxShadow: SceneShadow.glowSignal,
    ),
    child: SizedBox(
      height: DsGenFrame.tagHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsGenFrame.tagPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Transform.rotate(
                angle: math.pi / 4,
                child: SizedBox.square(
                  dimension: DsGenFrame.diamond,
                  child: ColoredBox(color: theme.accent),
                ),
              ),
            ),
            const SizedBox(width: DsGenFrame.tagGap),
            DsCaps(
              label,
              maxLines: 1,
              style: theme.micro.badge.copyWith(color: theme.accent),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Peint le balayage puis la bordure en arc ; se repeint à chaque image du
/// contrôleur, dans le seul `RepaintBoundary` du cadre.
class _GenFramePainter extends CustomPainter {
  _GenFramePainter({
    required this.animation,
    required this.done,
    required this.signal,
    required this.ink,
    required this.inset,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final bool done;
  final Color signal;
  final Color ink;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(inset);
    if (rect.isEmpty) return;
    final RRect rrect = SceneRadius.borderLg.toRRect(rect);
    final phases = DsGenFrame.phasesAt(animation.value, done: done);

    final double? scan = phases.scan;
    if (scan != null) {
      final double band = rect.height * DsGenFrame.scanHeight;
      final double top =
          rect.top -
          band +
          (rect.height + band) * SceneMotion.curve.transform(scan);
      final Rect bandRect = Rect.fromLTWH(rect.left, top, rect.width, band);
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawRect(
          bandRect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                signal.withValues(alpha: 0),
                signal.withValues(alpha: DsGenFrame.scanMidAlpha),
                signal.withValues(alpha: DsGenFrame.scanAlpha),
              ],
              stops: const <double>[0, 0.7, 1],
            ).createShader(bandRect),
        )
        ..restore();
    }

    final Color clear = signal.withValues(alpha: 0);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = DsGenFrame.borderWidth
        ..shader = SweepGradient(
          // `conic-gradient` part de midi, `SweepGradient` de trois heures.
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          transform: GradientRotation(2 * math.pi * phases.spin),
          colors: <Color>[clear, clear, signal, ink, signal, clear, clear],
          stops: const <double>[0, 0.62, 0.8, 0.84, 0.88, 0.96, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GenFramePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.done != done ||
      oldDelegate.signal != signal ||
      oldDelegate.ink != ink ||
      oldDelegate.inset != inset;
}
