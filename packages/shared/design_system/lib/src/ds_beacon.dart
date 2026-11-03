import 'package:flutter/widgets.dart';

import 'scene_motion.dart';

/// Point qui bat (`gc-beacon`) : un point plein de [size] px et un halo qui
/// s'étend de 7 px en s'estompant, période [period] (par défaut
/// [SceneMotion.beacon]).
///
/// Sans [child], le widget dessine lui-même le point plein. Avec [child] (un
/// point que l'appelant veut garder identifiable, par exemple par une clé), il
/// ne dessine que le halo, derrière l'enfant.
///
/// Isolé dans son `RepaintBoundary` : son battement ne repeint pas la cellule
/// voisine. **Phase de repos** (animations coupées) : le point seul, sans
/// halo figé. Un seul contrôleur, lancé une fois par `SceneMotionScope.loop` :
/// une reconstruction ne le redémarre pas.
class DsBeacon extends StatefulWidget {
  const DsBeacon({
    super.key,
    required this.color,
    required this.size,
    this.period = SceneMotion.beacon,
    this.child,
  });

  final Color color;

  /// Diamètre du point.
  final double size;

  /// Période du battement avant mise à l'échelle par le rejeu : 1,6 s pour
  /// la puce Bloquant, 1,2 s pour le point d'un agent au travail.
  final Duration period;

  /// Point dessiné par l'appelant (de [size] px) : le widget ne trace alors
  /// que le halo.
  final Widget? child;

  @override
  State<DsBeacon> createState() => _DsBeaconState();
}

class _DsBeaconState extends State<DsBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DsBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seul un changement de période relance la boucle.
    if (oldWidget.period != widget.period) _sync();
  }

  void _sync() {
    SceneMotionScope.loop(context, _controller, widget.period);
    // Animations coupées en plein battement : le point seul, sans halo figé.
    if (SceneMotionScope.of(context).disabled) {
      _controller.value = BeaconPainter.expandEnd;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Le painter écoute le contrôleur : aucune reconstruction par image (un
    // `AnimatedBuilder` reconstruirait un `LayoutBuilder` ancêtre).
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: BeaconPainter(
        color: widget.color,
        phase: _controller,
        drawDot: widget.child == null,
      ),
      child: widget.child,
    ),
  );
}

/// Peintre du halo (et du point plein si [drawDot]) d'un point qui bat. Il
/// écoute [phase] : le battement ne reconstruit aucun widget. Partagé avec la
/// puce de statut (`ds_status_chip.dart`), hors de l'API publique.
class BeaconPainter extends CustomPainter {
  const BeaconPainter({
    required this.color,
    required this.phase,
    required this.drawDot,
  }) : super(repaint: phase);

  /// Étendue maximale du halo, en pixels.
  static const double _spread = 7;

  /// Part de la période où le halo s'étend avant de disparaître.
  static const double expandEnd = 0.7;

  final Color color;
  final Animation<double> phase;
  final bool drawDot;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;
    final double value = phase.value;
    if (value < expandEnd) {
      final double t = value / expandEnd;
      final double spread = _spread * t;
      if (spread >= 0.5) {
        canvas.drawCircle(
          center,
          radius + spread / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = spread
            ..color = color.withValues(alpha: color.a * (1 - t)),
        );
      }
    }
    if (drawDot) canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BeaconPainter old) =>
      old.color != color || old.phase != phase || old.drawDot != drawDot;
}
