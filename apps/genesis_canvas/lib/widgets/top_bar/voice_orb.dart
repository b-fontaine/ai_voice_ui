import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Orbe vocal (FR-01) : repos (pulsation lente), parole (le rayon suit le
/// niveau) et réflexion (un arc tourne).
///
/// Le niveau audio arrive par [level] (`ValueListenable`, hors Bloc) : le
/// `CustomPainter` se repeint par `repaint:` sans `build` ni `layout`
/// ([perf-audio-visualizer-60hz]), isolé par un `RepaintBoundary`
/// ([perf-repaint-boundary]). Seul le franchissement de [speakingThreshold]
/// met à jour le libellé d'accessibilité.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key = const Key('voice-orb'),
    required this.level,
    this.thinking = false,
    this.speakingThreshold = 0.03,
  });

  static const double diameter = 64;

  /// Niveau lissé de la voix de l'IA, entre 0 et 1.
  final ValueListenable<double> level;

  /// Vrai quand les agents travaillent pendant une session active.
  final bool thinking;

  /// Niveau au-dessus duquel l'orbe est en parole.
  final double speakingThreshold;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  /// Période de la pulsation (repos) et d'un tour (réflexion).
  static const Duration _period = Duration(seconds: 2);

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: _period,
  )..repeat();

  // Alloués une fois : `paint()` ne crée aucun objet de style.
  final Paint _bodyPaint = Paint()..color = const Color(0xFF7C4DFF);
  final Paint _arcPaint = Paint()
    ..color = const Color(0xFFB39DFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  late final ValueNotifier<bool> _speaking = ValueNotifier<bool>(_isSpeaking);

  bool get _isSpeaking => widget.level.value > widget.speakingThreshold;

  void _syncSpeaking() => _speaking.value = _isSpeaking;

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_syncSpeaking);
  }

  @override
  void didUpdateWidget(VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      oldWidget.level.removeListener(_syncSpeaking);
      widget.level.addListener(_syncSpeaking);
    }
    _syncSpeaking();
  }

  @override
  void dispose() {
    widget.level.removeListener(_syncSpeaking);
    _speaking.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _speaking,
    builder: (context, speaking, child) => Semantics(
      label: 'Orbe vocal',
      value: speaking
          ? 'parole'
          : widget.thinking
          ? 'réflexion'
          : 'repos',
      child: child,
    ),
    child: SizedBox.square(
      dimension: VoiceOrb.diameter,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _OrbPainter(
            level: widget.level,
            animation: _animation,
            thinking: widget.thinking,
            speakingThreshold: widget.speakingThreshold,
            bodyPaint: _bodyPaint,
            arcPaint: _arcPaint,
          ),
        ),
      ),
    ),
  );
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.level,
    required this.animation,
    required this.thinking,
    required this.speakingThreshold,
    required this.bodyPaint,
    required this.arcPaint,
  }) : super(repaint: Listenable.merge(<Listenable>[level, animation]));

  final ValueListenable<double> level;
  final Animation<double> animation;
  final bool thinking;
  final double speakingThreshold;
  final Paint bodyPaint;
  final Paint arcPaint;

  static const double _restRadius = 0.62;
  static const double _pulseAmplitude = 0.08;
  static const double _thinkingRadius = 0.55;
  static const double _arcSweep = math.pi * 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final half = size.shortestSide / 2;
    final value = level.value;

    if (value > speakingThreshold) {
      // Parole : le rayon suit le niveau.
      final radius =
          half * (_restRadius + (1 - _restRadius) * value.clamp(0, 1));
      canvas.drawCircle(center, radius, bodyPaint);
    } else if (thinking) {
      // Réflexion : corps stable et arc qui tourne.
      canvas.drawCircle(center, half * _thinkingRadius, bodyPaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: half - arcPaint.strokeWidth),
        animation.value * 2 * math.pi,
        _arcSweep,
        false,
        arcPaint,
      );
    } else {
      // Repos : pulsation lente.
      final pulse = math.sin(animation.value * 2 * math.pi);
      canvas.drawCircle(
        center,
        half * (_restRadius + _pulseAmplitude * pulse),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.level != level ||
      old.animation != animation ||
      old.thinking != thinking ||
      old.speakingThreshold != speakingThreshold;
}
