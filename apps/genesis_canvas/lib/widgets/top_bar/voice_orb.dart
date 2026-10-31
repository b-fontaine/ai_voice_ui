import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Orbe vocal (FR-01) : repos (pulsation lente), parole (le rayon suit le
/// niveau), réflexion (un arc tourne) et, après une coupure de parole
/// (FR-19, RG-17), « Interrompue » (arrêt net, flash) puis « Écoute ».
///
/// Le niveau audio arrive par [level] (`ValueListenable`, hors Bloc) : le
/// `CustomPainter` se repeint par `repaint:` sans `build` ni `layout`
/// ([perf-audio-visualizer-60hz]), isolé par un `RepaintBoundary`
/// ([perf-repaint-boundary]). Le micro coupé n'est pas une phase : [micMuted]
/// ajoute un voile par-dessus. Seul le franchissement de [speakingThreshold]
/// met à jour le libellé d'accessibilité.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key = const Key('voice-orb'),
    required this.level,
    this.thinking = false,
    this.interrupted = false,
    this.listening = false,
    this.micMuted = false,
    this.speakingThreshold = 0.03,
  });

  static const double diameter = 64;

  /// Niveau lissé de la voix de l'IA, entre 0 et 1.
  final ValueListenable<double> level;

  /// Vrai quand les agents travaillent pendant une session active.
  final bool thinking;

  /// Vrai quand le speaker vient de couper l'IA : prime sur tous les autres
  /// états (le niveau est alors maintenu à 0 par la page).
  final bool interrupted;

  /// Vrai quand la session est active et que l'IA se tait : l'orbe se lit
  /// « Écoute » au lieu de « repos ».
  final bool listening;

  /// Vrai quand le micro est coupé : un voile « Micro coupé » (grisé, barré)
  /// se pose par-dessus la phase réelle, qui reste lisible dessous.
  final bool micMuted;

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
  final Paint _flashPaint = Paint()..color = const Color(0xFFFFFFFF);
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
      value: widget.interrupted
          ? 'Interrompue'
          : speaking
          ? 'parole'
          : widget.thinking
          ? 'réflexion'
          : widget.listening
          ? 'Écoute'
          : 'repos',
      child: child,
    ),
    child: SizedBox.square(
      dimension: VoiceOrb.diameter,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: CustomPaint(
              painter: _OrbPainter(
                level: widget.level,
                animation: _animation,
                thinking: widget.thinking,
                interrupted: widget.interrupted,
                speakingThreshold: widget.speakingThreshold,
                bodyPaint: _bodyPaint,
                flashPaint: _flashPaint,
                arcPaint: _arcPaint,
              ),
            ),
          ),
          if (widget.micMuted) const _MicMutedVeil(),
        ],
      ),
    ),
  );
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.level,
    required this.animation,
    required this.thinking,
    required this.interrupted,
    required this.speakingThreshold,
    required this.bodyPaint,
    required this.flashPaint,
    required this.arcPaint,
  }) : super(repaint: Listenable.merge(<Listenable>[level, animation]));

  final ValueListenable<double> level;
  final Animation<double> animation;
  final bool thinking;
  final bool interrupted;
  final double speakingThreshold;
  final Paint bodyPaint;
  final Paint flashPaint;
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

    if (interrupted) {
      // Interrompue : arrêt net, flash au rayon de repos, sans pulsation.
      canvas.drawCircle(center, half * _restRadius, flashPaint);
    } else if (value > speakingThreshold) {
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
      old.interrupted != interrupted ||
      old.speakingThreshold != speakingThreshold;
}

/// Voile « Micro coupé » : disque grisé, barre oblique et libellé, sur toute
/// la surface de l'orbe (le libellé tient sur deux lignes).
class _MicMutedVeil extends StatelessWidget {
  const _MicMutedVeil();

  static const String label = 'Micro coupé';

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    key: Key('mic-muted-veil'),
    decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xB3424242)),
    child: CustomPaint(
      painter: _StrikePainter(),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Barre oblique du voile, du coin haut gauche au coin bas droit du disque.
class _StrikePainter extends CustomPainter {
  const _StrikePainter();

  static final Paint _paint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = size.shortestSide * 0.15;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) => false;
}
