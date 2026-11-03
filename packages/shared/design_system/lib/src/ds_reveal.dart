import 'package:flutter/widgets.dart';

import 'ds_shift.dart';

/// Apparition d'un élément : fondu et glissement depuis [from], sans flou
/// (le flou de `gc-rise` est réservé à `DsRise`, pour les surfaces).
///
/// C'est un `FadeTransition` et un `DsShift` : l'avancement est suivi au
/// niveau du rendu, sans reconstruction ni remise en page par image (sous un
/// `LayoutBuilder`, un `AnimatedBuilder` remettrait en page tout le
/// sous-arbre à chaque image). Avec [interval], l'apparition n'occupe que cette
/// part de [animation] (cascade commune décalée par rang) ; la courbe est
/// alors celle de l'`Interval`. Sans [interval], [animation] est prise telle
/// quelle (déjà adoucie par l'appelant si besoin).
class DsReveal extends StatelessWidget {
  const DsReveal({
    super.key,
    required this.animation,
    required this.from,
    this.interval,
    required this.child,
  });

  /// Avancement commun : 0 (invisible, décalé de [from]) à 1 (en place).
  final Animation<double> animation;

  /// Décalage de départ, en points logiques.
  final Offset from;

  /// Part de [animation] occupée par cette apparition, avec sa courbe.
  final Interval? interval;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Interval? part = interval;
    final Animation<double> progress = part == null
        ? animation
        : animation.drive(CurveTween(curve: part));
    return FadeTransition(
      opacity: progress,
      child: DsShift(progress: progress, offset: from, child: child),
    );
  }
}
