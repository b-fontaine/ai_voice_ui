import 'package:flutter/widgets.dart';

import 'scene_motion.dart';

/// Clignotement en créneaux (`gc-blink`, `steps(2)`, pdr-0088 F9) : l'enfant
/// est plein pendant la première moitié de la [period], à [dimmedOpacity]
/// pendant la seconde.
///
/// La période est mise à l'échelle par `SceneMotionScope.loop` (une seule
/// source de vérité : vitesse de rejeu et `disabled`). Un seul contrôleur par
/// instance, lancé une fois : une reconstruction du parent ne le redémarre
/// pas. **Phase de repos** (animations coupées) : l'enfant reste **plein**
/// (phase 0), jamais figé à demi-teinte.
///
/// Chaque instance a son `RepaintBoundary` : le clignotement ne repeint pas
/// ses voisins (curseur, point d'enregistrement, losange de l'étiquette). Le
/// clignotement est un `FadeTransition` : l'opacité suit le contrôleur au
/// niveau du rendu, sans reconstruction. Un `AnimatedBuilder` ferait
/// reconstruire, à chaque image, un `LayoutBuilder` ancêtre (donc sa mise en
/// page et la peinture du parent).
class DsBlink extends StatefulWidget {
  const DsBlink({
    super.key,
    required this.child,
    this.period = SceneMotion.blink,
  });

  /// Opacité de la seconde moitié de la période (`gc-blink` : 50 % → .2).
  static const double dimmedOpacity = 0.2;

  final Widget child;

  /// Période du clignotement avant mise à l'échelle par le rejeu.
  final Duration period;

  @override
  State<DsBlink> createState() => _DsBlinkState();
}

class _DsBlinkState extends State<DsBlink> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  late final Animation<double> _opacity = _controller.drive(const _Steps());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DsBlink oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seul un changement de période relance la boucle.
    if (oldWidget.period != widget.period) _sync();
  }

  void _sync() {
    SceneMotionScope.loop(context, _controller, widget.period);
    // Animations coupées : enfant plein, jamais figé en demi-teinte.
    if (SceneMotionScope.of(context).disabled) _controller.value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: FadeTransition(opacity: _opacity, child: widget.child),
  );
}

/// `steps(2)` : plein pendant la première moitié, [DsBlink.dimmedOpacity]
/// pendant la seconde. Un `Animatable` direct : `CurveTween` renverrait 0 et 1
/// tels quels aux bornes, pas l'opacité.
class _Steps extends Animatable<double> {
  const _Steps();

  @override
  double transform(double t) => t < 0.5 ? 1 : DsBlink.dimmedOpacity;
}
