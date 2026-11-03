import 'package:flutter/widgets.dart';

import 'scene_loop.dart';
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

class _DsBlinkState extends State<DsBlink>
    with SingleTickerProviderStateMixin, SceneLoop<DsBlink> {
  @override
  Duration get loopBase => widget.period;

  // Animations coupées : enfant plein (phase 0), jamais figé en demi-teinte.
  @override
  double get loopRestValue => 0;

  late final Animation<double> _opacity = loop.drive(const _Steps());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncLoop();
  }

  @override
  void didUpdateWidget(DsBlink oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seul un changement de période relance la boucle.
    syncLoop();
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
