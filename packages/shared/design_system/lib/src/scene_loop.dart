import 'package:flutter/widgets.dart';

import 'scene_motion.dart';

/// Animation en boucle d'un composant : un seul `AnimationController` qui
/// tourne sans fin (clignotement, battement, anneaux, barre indéterminée).
///
/// Le mixin réunit ce que chaque boucle doit faire pareil :
/// - la période [loopBase] est mise à l'échelle par la vitesse de rejeu par
///   [SceneMotionScope.loop] (une seule source de vérité) ;
/// - sous « réduire les animations » (ou en mode scénario), la boucle est
///   arrêtée sur la phase de repos [loopRestValue], sans `Ticker` actif ;
/// - [syncLoop] ne relance jamais un `repeat` qui tourne déjà sur la bonne
///   période : une reconstruction du parent ne redémarre pas la boucle ;
/// - le contrôleur est libéré à `dispose`.
///
/// À utiliser avec un `TickerProvider` (`SingleTickerProviderStateMixin`,
/// ou `TickerProviderStateMixin` si l'état porte d'autres contrôleurs), et à
/// appeler [syncLoop] dans `didChangeDependencies` et `didUpdateWidget`.
mixin SceneLoop<T extends StatefulWidget> on State<T>, TickerProvider {
  /// Période de base de la boucle, avant adaptation au réglage de la scène.
  Duration get loopBase;

  /// Valeur du contrôleur quand la boucle est arrêtée : animations coupées,
  /// ou [loopActive] faux.
  double get loopRestValue => 0;

  /// Faux : la boucle est arrêtée à [loopRestValue] (par exemple tant qu'un
  /// tracé n'est pas fini).
  bool get loopActive => true;

  /// Vrai : la phase va et vient entre 0 et 1 au lieu de repartir de 0.
  bool get loopReverse => false;

  /// Le contrôleur de la boucle, créé à la première utilisation.
  late final AnimationController loop = AnimationController(
    vsync: this,
    duration: loopBase,
  );

  Duration? _appliedPeriod;
  bool? _appliedReverse;

  /// (Re)démarre ou fige la boucle selon [loopActive] et le réglage de
  /// mouvement. Sans effet si elle tourne déjà sur la même période.
  void syncLoop() {
    final SceneMotionScope scope = SceneMotionScope.of(context);
    if (!loopActive || scope.disabled) {
      loop.stop();
      loop.value = loopRestValue;
      _appliedPeriod = null;
      return;
    }
    final Duration period = scope.durationFor(loopBase);
    if (loop.isAnimating &&
        _appliedPeriod == period &&
        _appliedReverse == loopReverse) {
      return;
    }
    SceneMotionScope.loop(context, loop, loopBase, reverse: loopReverse);
    _appliedPeriod = period;
    _appliedReverse = loopReverse;
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}
