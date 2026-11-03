import 'package:flutter/widgets.dart';

import 'generated/scene_tokens.g.dart';

/// Durées et courbe des animations de la scène (pdr-0075 D3).
///
/// Valeurs issues des tokens `motion.*` (pdr-0084 U2). Pas d'`Easing.emphasized`
/// : il n'existe pas en Flutter ; la courbe est la `Cubic(.2, .8, .2, 1)` du
/// design system. L'apparition d'une surface porte un flou de départ
/// ([blur], pdr-0087 / pdr-0088 F5).
abstract final class SceneMotion {
  /// Fondu squelette vers composants d'une surface.
  static const Duration appear = SceneTokens.motionAppear;

  /// Fondu d'une valeur qui passe de « sans données » à « données ».
  static const Duration value = SceneTokens.motionValue;

  /// Changement de la pastille de statut de décision.
  static const Duration status = SceneTokens.motionStatus;

  /// Plancher d'une durée non nulle, quelle que soit la vitesse de rejeu.
  static const Duration floor = SceneTokens.motionFloor;

  /// Translation verticale d'apparition, en pixels logiques.
  static const double translation = SceneTokens.motionTranslation;

  /// Période d'une boucle de la liaison de délégation du rail (défilement des
  /// pointillés), avant adaptation à la vitesse de rejeu.
  static const Duration link = SceneTokens.motionLink;

  /// Période du battement du statut « Bloquant ».
  static const Duration beacon = SceneTokens.motionBeacon;

  /// Durée d'un sens de la pulsation du squelette.
  static const Duration skeleton = SceneTokens.motionSkeleton;

  /// Période de la respiration de l'orbe vocal.
  static const Duration orb = SceneTokens.motionOrb;

  /// Apparition d'une ligne (`gc-row`).
  static const Duration row = SceneTokens.motionRow;

  /// Décalage entre deux lignes d'une cascade.
  static const Duration stagger = SceneTokens.motionStagger;

  /// Tracé d'une série (`gc-wipe`).
  static const Duration wipe = SceneTokens.motionWipe;

  /// Compteur d'un indicateur clé.
  static const Duration count = SceneTokens.motionCount;

  /// Remplissage d'une jauge.
  static const Duration gauge = SceneTokens.motionGauge;

  /// Rotation de l'arc du cadre de génération (`gc-spin`).
  static const Duration spin = SceneTokens.motionSpin;

  /// Balayage du cadre de génération (`gc-scan`).
  static const Duration scan = SceneTokens.motionScan;

  /// Fondu lent (`gc-fade`).
  static const Duration fade = SceneTokens.motionFade;

  /// Éclat d'une puce nouvelle (`gc-flash`).
  static const Duration flash = SceneTokens.motionFlash;

  /// Période de l'onde de l'orbe (`gc-wave`).
  static const Duration wave = SceneTokens.motionWave;

  /// Période des anneaux de l'orbe (`gc-orbring`).
  static const Duration orbRing = SceneTokens.motionOrbRing;

  /// Barre indéterminée (`gc-indet`).
  static const Duration indet = SceneTokens.motionIndet;

  /// Anneau de tête d'une série (`gc-ring`).
  static const Duration ring = SceneTokens.motionRing;

  /// Période du clignotement en créneaux (`gc-blink`).
  static const Duration blink = SceneTokens.motionBlink;

  /// Écart type du flou de départ d'une apparition, en pixels logiques.
  static const double blur = SceneTokens.motionBlur;

  /// Échelle de départ d'une apparition (1 à l'arrivée).
  static const double scale = SceneTokens.motionScale;

  /// Courbe commune à toutes les transitions de la scène.
  static const Curve curve = SceneTokens.motionCurve;

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

  /// Joue [controller] depuis le début sur [base] adaptée au réglage en vigueur.
  ///
  /// Durée nulle (animations coupées) : le contrôleur passe aussitôt à 1, sans
  /// animation. Sinon, il repart de 0 sur la durée mise à l'échelle.
  static void play(
    BuildContext context,
    AnimationController controller,
    Duration base,
  ) {
    final Duration duration = of(context).durationFor(base);
    controller.duration = duration;
    if (duration == Duration.zero) {
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  /// Termine aussitôt une lecture en cours de [controller] si les animations
  /// viennent d'être coupées (valeur 1, aucun `Ticker` actif).
  ///
  /// À appeler dans `didChangeDependencies` d'un état qui joue [play] : une
  /// animation d'apparition en vol ne doit pas survivre au réglage « réduire
  /// les animations ».
  static void completeIfDisabled(
    BuildContext context,
    AnimationController controller,
  ) {
    if (of(context).disabled && controller.isAnimating) {
      controller.value = 1;
    }
  }

  /// Fait tourner [controller] en boucle sur [base] adaptée au réglage en
  /// vigueur (animation sans fin, comme les pointillés de la liaison).
  ///
  /// Période nulle (animations coupées) : le contrôleur s'arrête et garde sa
  /// phase, sans jamais boucler sur une durée nulle. À rappeler quand le
  /// réglage change (`didChangeDependencies`). Avec [reverse], la phase va et
  /// vient entre 0 et 1 au lieu de repartir de 0.
  static void loop(
    BuildContext context,
    AnimationController controller,
    Duration base, {
    bool reverse = false,
  }) {
    final Duration period = of(context).durationFor(base);
    controller.duration = period;
    if (period == Duration.zero) {
      controller.stop();
    } else {
      controller.repeat(period: period, reverse: reverse);
    }
  }

  @override
  bool updateShouldNotify(SceneMotionScope oldWidget) =>
      disabled != oldWidget.disabled || speed != oldWidget.speed;
}
