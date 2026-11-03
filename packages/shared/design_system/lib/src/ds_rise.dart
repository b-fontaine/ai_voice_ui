import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'scene_motion.dart';
import 'scene_one_shot.dart';

/// Apparition d'une surface (`gc-rise`, pdr-0087 / pdr-0088 F5) : fondu, flou
/// de départ (σ 4 vers 0), glissement de 10 px vers sa place et échelle
/// .985 vers 1, en 480 ms sur la courbe du design system.
///
/// L'arbre est **constant** : `Opacity` > `Transform` > `ImageFiltered` sont
/// toujours présents, et [child] est passé à l'`AnimatedBuilder` comme `child`.
/// Le `State` de l'enfant n'est donc jamais recréé (D-07) et seul l'habillage
/// suit l'image. Le flou n'est actif que pendant la lecture. L'échelle est
/// centrée en haut : le bord supérieur ne bouge que de la translation de
/// 10 px, ce que mesure l'acceptation A-01.
///
/// La lecture part au montage, sauf si [settled] (contenu déjà en place).
/// Durée divisée par la vitesse de rejeu ; immédiate sous
/// `SceneMotionScope.disabled`.
class DsRise extends StatefulWidget {
  const DsRise({super.key, required this.child, this.settled = false});

  /// Contenu qui apparaît.
  final Widget child;

  /// Vrai : le contenu est déjà en place, aucune apparition.
  final bool settled;

  @override
  State<DsRise> createState() => _DsRiseState();
}

class _DsRiseState extends State<DsRise>
    with SingleTickerProviderStateMixin<DsRise>, SceneOneShot<DsRise> {
  bool _started = false;

  @override
  Duration get oneShotBase => SceneMotion.appear;

  @override
  double get oneShotInitialValue => widget.settled ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.settled) playOneShot();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: oneShot,
    child: widget.child,
    builder: (BuildContext context, Widget? child) {
      final double t = SceneMotion.curve.transform(oneShot.value);
      final double sigma = SceneMotion.blur * (1 - t);
      final double scale = SceneMotion.scale + (1 - SceneMotion.scale) * t;
      return Opacity(
        opacity: t,
        child: Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.translationValues(
            0,
            SceneMotion.translation * (1 - t),
            0,
          )..scaleByDouble(scale, scale, 1, 1),
          child: ImageFiltered(
            enabled: t < 1,
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          ),
        ),
      );
    },
  );
}
