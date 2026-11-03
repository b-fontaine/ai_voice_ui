import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotion, SceneMotionScope, SceneTheme;

import 'speaking_gate.dart';

/// Onde de la voix de l'IA (`.gc-wave` du design system) : douze barres de
/// 3 points, `plasma`, dont la hauteur oscille entre 30 % et 100 % sur 1 s,
/// chacune avec son retard.
///
/// Elle n'existe que quand l'IA parle ([level] au-dessus de
/// [speakingThreshold], avec hystérésis, [SpeakingGate]) : sinon elle réserve
/// sa place de 28 points sans rien peindre ni se repeindre (A-06). La boucle
/// (`SceneMotionScope.loop`) tourne en continu et n'est jamais relancée au
/// franchissement du seuil ; animations coupées, elle s'arrête et reste
/// invisible. Isolée par un `RepaintBoundary` (NFR-04).
class VoiceWave extends StatefulWidget {
  const VoiceWave({
    super.key = const Key('voice-wave'),
    required this.level,
    this.speakingThreshold = 0.03,
  });

  /// Hauteur de l'onde, en points.
  static const double height = 28;

  /// Niveau lissé de la voix de l'IA, entre 0 et 1.
  final ValueListenable<double> level;

  final double speakingThreshold;

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: SceneMotion.wave,
  );

  late SpeakingGate _gate = _newGate();

  SpeakingGate _newGate() =>
      SpeakingGate(level: widget.level, threshold: widget.speakingThreshold);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SceneMotionScope.loop(context, _animation, SceneMotion.wave);
  }

  @override
  void didUpdateWidget(VoiceWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level ||
        oldWidget.speakingThreshold != widget.speakingThreshold) {
      _gate.dispose();
      _gate = _newGate();
    }
  }

  @override
  void dispose() {
    _gate.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = SceneTheme.of(context).plasma;
    final bool still = SceneMotionScope.of(context).disabled;
    return SizedBox(
      height: VoiceWave.height,
      child: ValueListenableBuilder<bool>(
        valueListenable: _gate,
        builder: (BuildContext context, bool speaking, Widget? child) {
          final bool active = speaking && !still;
          return RepaintBoundary(
            child: CustomPaint(
              painter: _WavePainter(
                // Hors parole, aucun abonnement : le tableau ne se repeint pas.
                animation: active ? _animation : null,
                color: color,
              ),
              size: const Size(_WavePainter.width, VoiceWave.height),
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.animation, required this.color})
    : _paint = Paint()..color = color,
      super(repaint: animation);

  /// Retards de chaque barre (`animation-delay` du CSS), en secondes.
  static const List<double> _delays = <double>[
    0, 0.1, 0.25, 0.05, 0.3, 0.15, 0.4, 0.2, 0.35, 0.1, 0.45, 0.05, //
  ];
  static const double _barWidth = 3;
  static const double _gap = 3;
  static const double _minFraction = 0.3;

  /// Largeur de l'onde : douze barres et onze écarts.
  static const double width = 12 * _barWidth + 11 * _gap;

  final Animation<double>? animation;
  final Color color;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final Animation<double>? phase = animation;
    if (phase == null) return;
    for (var i = 0; i < _delays.length; i++) {
      // Aller-retour de 30 % à 100 % puis retour, adouci (`ease-in-out`).
      final double local = (phase.value - _delays[i]) % 1;
      final double eased = Curves.easeInOut.transform(
        1 - (2 * local - 1).abs(),
      );
      final double h =
          size.height * (_minFraction + (1 - _minFraction) * eased);
      final double left = i * (_barWidth + _gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, (size.height - h) / 2, _barWidth, h),
          const Radius.circular(_barWidth / 2),
        ),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.animation != animation || old.color != color;
}
