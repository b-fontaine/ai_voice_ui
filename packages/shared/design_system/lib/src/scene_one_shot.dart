import 'package:flutter/widgets.dart';

import 'scene_motion.dart';

/// Animation ponctuelle d'un composant : un seul `AnimationController` joué
/// une fois, de 0 à 1 (compteur, jauge, barre de répartition, cascade, tracé).
///
/// Le mixin réunit ce que chaque animation ponctuelle doit faire pareil :
/// - la durée [oneShotBase] est divisée par la vitesse de rejeu, avec
///   plancher, par [SceneMotionScope.play] ;
/// - sous « réduire les animations » (ou en mode scénario), la valeur passe
///   aussitôt à 1, sans `Ticker` actif ;
/// - une lecture en cours est terminée dès que les animations sont coupées
///   ([SceneMotionScope.completeIfDisabled], dans `didChangeDependencies`) ;
/// - le contrôleur est libéré à `dispose`.
///
/// À utiliser avec `SingleTickerProviderStateMixin`, jamais avec un
/// `TweenAnimationBuilder` (un contrôleur par composant, pdr-0088 F9).
mixin SceneOneShot<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  /// Durée de base de la lecture, avant adaptation au réglage de la scène.
  Duration get oneShotBase;

  /// Valeur du contrôleur au montage : 0 (à jouer), ou 1 (déjà en place).
  double get oneShotInitialValue => 0;

  /// Le contrôleur de l'animation, créé à la première utilisation.
  late final AnimationController oneShot = AnimationController(
    vsync: this,
    duration: oneShotBase,
    value: oneShotInitialValue,
  );

  /// Joue l'animation depuis le début (état final immédiat si coupée).
  void playOneShot() => SceneMotionScope.play(context, oneShot, oneShotBase);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SceneMotionScope.completeIfDisabled(context, oneShot);
  }

  @override
  void dispose() {
    oneShot.dispose();
    super.dispose();
  }
}
