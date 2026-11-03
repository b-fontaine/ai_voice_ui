import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotion, SceneMotionScope, SceneTheme;

import 'speaking_gate.dart';

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
///
/// Trois anneaux (`gc-orbring`, clés `voice-orb-ring-0` à `-2`) s'étendent
/// autour du corps (`voice-orb-core`) **seulement quand l'IA parle**. Leur
/// boucle (période [SceneMotion.orbRing], anneaux décalés d'un tiers de
/// période) tourne en continu et n'est jamais relancée quand le niveau
/// franchit le seuil ; une hystérésis ([SpeakingGate]) évite qu'ils
/// clignotent autour du seuil. Hors parole, ou animations coupées, ils sont
/// invisibles et ne se repeignent pas.
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

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  /// Période de la pulsation (repos) et d'un tour (réflexion).
  static const Duration _period = SceneMotion.orb;

  // La boucle est lancée par `SceneMotionScope.loop` : elle suit la vitesse de
  // rejeu et reste à l'arrêt quand les animations sont coupées.
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: _period,
  );

  // Boucle des anneaux : une période propre (`gc-orbring`, 2,4 s), lancée une
  // fois par `SceneMotionScope.loop`, jamais au franchissement du seuil.
  late final AnimationController _ringsAnimation = AnimationController(
    vsync: this,
    duration: SceneMotion.orbRing,
  );

  late final ValueNotifier<bool> _speaking = ValueNotifier<bool>(_isSpeaking);

  late SpeakingGate _ringsGate = _newRingsGate();

  SpeakingGate _newRingsGate() =>
      SpeakingGate(level: widget.level, threshold: widget.speakingThreshold);

  bool get _isSpeaking => widget.level.value > widget.speakingThreshold;

  void _syncSpeaking() => _speaking.value = _isSpeaking;

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_syncSpeaking);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SceneMotionScope.loop(context, _animation, _period);
    SceneMotionScope.loop(context, _ringsAnimation, SceneMotion.orbRing);
  }

  @override
  void didUpdateWidget(VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      oldWidget.level.removeListener(_syncSpeaking);
      widget.level.addListener(_syncSpeaking);
    }
    if (oldWidget.level != widget.level ||
        oldWidget.speakingThreshold != widget.speakingThreshold) {
      _ringsGate.dispose();
      _ringsGate = _newRingsGate();
    }
    _syncSpeaking();
  }

  @override
  void dispose() {
    widget.level.removeListener(_syncSpeaking);
    _speaking.dispose();
    _ringsGate.dispose();
    _animation.dispose();
    _ringsAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final bool still = SceneMotionScope.of(context).disabled;
    return ValueListenableBuilder<bool>(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: VoiceOrb.diameter,
            child: Stack(
              fit: StackFit.expand,
              // Les anneaux débordent du disque (échelle jusqu'à 1,25).
              clipBehavior: Clip.none,
              children: <Widget>[
                RepaintBoundary(
                  key: const Key('voice-orb-core'),
                  child: CustomPaint(
                    painter: _OrbPainter(
                      level: widget.level,
                      animation: _animation,
                      thinking: widget.thinking,
                      interrupted: widget.interrupted,
                      speakingThreshold: widget.speakingThreshold,
                      bodyColor: theme.plasma,
                      flashColor: theme.textPrimary,
                      arcColor: theme.plasma,
                      haloColor: theme.plasmaGhost,
                    ),
                  ),
                ),
                for (var i = 0; i < _RingsPainter.count; i++)
                  ValueListenableBuilder<bool>(
                    valueListenable: _ringsGate,
                    builder: (context, speaking, child) => RepaintBoundary(
                      key: Key('voice-orb-ring-$i'),
                      child: CustomPaint(
                        painter: _RingsPainter(
                          index: i,
                          // Hors parole ou animations coupées : aucun
                          // abonnement, donc aucune peinture.
                          animation: speaking && !still
                              ? _ringsAnimation
                              : null,
                          color: theme.plasma,
                        ),
                      ),
                    ),
                  ),
                if (widget.micMuted) _MicMutedVeil(color: theme.orbVeil),
              ],
            ),
          ),
          // Le libellé (24 px au moins, RG-09) ne tient pas dans les 64 points
          // du disque : il se pose dessous, et la colonne s'élargit d'autant.
          if (widget.micMuted) const _MicMutedLabel(),
        ],
      ),
    );
  }
}

/// Peint l'orbe avec les couleurs reçues du thème (le painter ne lit pas le
/// contexte). Les `Paint` et le dégradé du halo sont créés une fois, à la
/// construction : `paint()` n'alloue aucun objet de style.
class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.level,
    required this.animation,
    required this.thinking,
    required this.interrupted,
    required this.speakingThreshold,
    required this.bodyColor,
    required this.flashColor,
    required this.arcColor,
    required this.haloColor,
  }) : _bodyPaint = Paint()..color = bodyColor,
       _flashPaint = Paint()..color = flashColor,
       _arcPaint = Paint()
         ..color = arcColor
         ..style = PaintingStyle.stroke
         ..strokeWidth = 3
         ..strokeCap = StrokeCap.round,
       // Halo `glow-plasma` : dégradé radial de rayon 1 centré à l'origine,
       // mis à l'échelle au dessin (ni flou ni couche hors écran à 60 Hz).
       _haloPaint = Paint()
         ..shader = RadialGradient(
           colors: <Color>[haloColor, haloColor.withAlpha(0)],
           stops: const <double>[0.55, 1],
         ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
       super(repaint: Listenable.merge(<Listenable>[level, animation]));

  final ValueListenable<double> level;
  final Animation<double> animation;
  final bool thinking;
  final bool interrupted;
  final double speakingThreshold;
  final Color bodyColor;
  final Color flashColor;
  final Color arcColor;
  final Color haloColor;
  final Paint _bodyPaint;
  final Paint _flashPaint;
  final Paint _arcPaint;
  final Paint _haloPaint;

  /// Le halo déborde du corps de ce facteur, borné au rayon de l'orbe.
  static const double _haloReach = 1.3;

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
      canvas.drawCircle(center, half * _restRadius, _flashPaint);
    } else if (value > speakingThreshold) {
      // Parole : le rayon suit le niveau.
      final radius =
          half * (_restRadius + (1 - _restRadius) * value.clamp(0, 1));
      final haloRadius = math.min(half, radius * _haloReach);
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..scale(haloRadius)
        ..drawCircle(Offset.zero, 1, _haloPaint)
        ..restore();
      canvas.drawCircle(center, radius, _bodyPaint);
    } else if (thinking) {
      // Réflexion : corps stable et arc qui tourne.
      canvas.drawCircle(center, half * _thinkingRadius, _bodyPaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: half - _arcPaint.strokeWidth),
        animation.value * 2 * math.pi,
        _arcSweep,
        false,
        _arcPaint,
      );
    } else {
      // Repos : pulsation lente.
      final pulse = math.sin(animation.value * 2 * math.pi);
      canvas.drawCircle(
        center,
        half * (_restRadius + _pulseAmplitude * pulse),
        _bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.level != level ||
      old.animation != animation ||
      old.thinking != thinking ||
      old.interrupted != interrupted ||
      old.speakingThreshold != speakingThreshold ||
      old.bodyColor != bodyColor ||
      old.flashColor != flashColor ||
      old.arcColor != arcColor ||
      old.haloColor != haloColor;
}

/// Un anneau de l'orbe (`.gc-orb__ring`) : bordure de 1,5 point, couleur de
/// l'orbe, échelle de 0,55 à 1,25 et opacité de 0,8 à 0 sur une période
/// (`gc-orbring`, sortie douce). Les anneaux sont décalés d'un tiers de période
/// (0,8 s sur 2,4 s). Sans [animation], rien n'est peint (repos).
class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.index,
    required this.animation,
    required this.color,
  }) : _paint = Paint()
         ..style = PaintingStyle.stroke
         ..strokeWidth = 1.5,
       super(repaint: animation);

  /// Nombre d'anneaux.
  static const int count = 3;

  static const double _fromScale = 0.55;
  static const double _toScale = 1.25;
  static const double _fromOpacity = 0.8;

  final int index;
  final Animation<double>? animation;
  final Color color;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final Animation<double>? phase = animation;
    if (phase == null) return;
    final double t = Curves.easeOut.transform(
      (phase.value - index / count) % 1,
    );
    _paint.color = color.withValues(alpha: _fromOpacity * (1 - t));
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 * (_fromScale + (_toScale - _fromScale) * t),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.index != index || old.animation != animation || old.color != color;
}

/// Voile « Micro coupé » : disque grisé et barre oblique, sur toute la
/// surface de l'orbe ; le libellé est [_MicMutedLabel].
class _MicMutedVeil extends StatelessWidget {
  const _MicMutedVeil({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('mic-muted-veil'),
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    child: CustomPaint(
      painter: _StrikePainter(SceneTheme.of(context).textPrimary),
      child: const SizedBox.expand(),
    ),
  );
}

/// Libellé « Micro coupé » au format de la scène (24 px au moins, RG-09), en
/// une ligne.
class _MicMutedLabel extends StatelessWidget {
  const _MicMutedLabel();

  static const String label = 'Micro coupé';

  @override
  Widget build(BuildContext context) => Text(
    label,
    maxLines: 1,
    softWrap: false,
    textAlign: TextAlign.center,
    style: SceneTheme.of(context).body,
  );
}

/// Barre oblique du voile, du coin haut gauche au coin bas droit du disque.
class _StrikePainter extends CustomPainter {
  _StrikePainter(this.color)
    : _paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

  final Color color;
  final Paint _paint;

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
  bool shouldRepaint(_StrikePainter old) => old.color != color;
}
