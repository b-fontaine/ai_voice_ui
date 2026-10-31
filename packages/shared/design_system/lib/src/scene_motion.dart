import 'package:flutter/widgets.dart';

/// Durées et courbe des animations de la scène (pdr-0075 D3).
///
/// Pas d'`Easing.emphasized` : il n'existe pas en Flutter ; la courbe retenue
/// est `Curves.easeOutCubic`.
abstract final class SceneMotion {
  /// Fondu squelette vers composants d'une surface.
  static const Duration appear = Duration(milliseconds: 200);

  /// Fondu d'une valeur qui passe de « sans données » à « données ».
  static const Duration value = Duration(milliseconds: 150);

  /// Changement de la pastille de statut de décision.
  static const Duration status = Duration(milliseconds: 400);

  /// Plancher d'une durée non nulle, quelle que soit la vitesse de rejeu.
  static const Duration floor = Duration(milliseconds: 60);

  /// Translation verticale d'apparition, en pixels logiques.
  static const double translation = 8;

  /// Courbe commune à toutes les transitions de la scène.
  static const Curve curve = Curves.easeOutCubic;

  /// [base] divisée par la vitesse de rejeu [speed], bornée au plancher.
  ///
  /// Une durée nulle reste nulle. Une vitesse nulle, négative ou non finie
  /// laisse la durée inchangée.
  static Duration scaled(Duration base, {required double speed}) {
    if (base == Duration.zero) return Duration.zero;
    if (!speed.isFinite || speed <= 0) return base;
    final Duration scaled = Duration(
      microseconds: (base.inMicroseconds / speed).round(),
    );
    return scaled < floor ? floor : scaled;
  }
}

/// Réglage d'animation de la scène, posé par la page au-dessus du canevas.
///
/// [disabled] donne des durées nulles (réglage d'accessibilité, scénario,
/// capture) ; [speed] est la vitesse du rejeu en cours (1 sinon). Le canevas
/// ne dépend d'aucune autre slice : la page traduit son état en ces deux
/// valeurs.
class SceneMotionScope extends InheritedWidget {
  const SceneMotionScope({
    super.key,
    this.disabled = false,
    this.speed = 1,
    required super.child,
  });

  /// Réglage par défaut hors scope : animations actives, vitesse 1.
  static const SceneMotionScope _fallback = SceneMotionScope(
    child: SizedBox.shrink(),
  );

  /// Animations coupées : toutes les durées sont nulles.
  final bool disabled;

  /// Vitesse de rejeu appliquée aux durées.
  final double speed;

  /// Réglage en vigueur, ou les valeurs par défaut sans scope.
  static SceneMotionScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SceneMotionScope>() ??
      _fallback;

  /// Durée effective d'une animation de base [base].
  Duration durationFor(Duration base) =>
      disabled ? Duration.zero : SceneMotion.scaled(base, speed: speed);

  @override
  bool updateShouldNotify(SceneMotionScope oldWidget) =>
      disabled != oldWidget.disabled || speed != oldWidget.speed;
}
