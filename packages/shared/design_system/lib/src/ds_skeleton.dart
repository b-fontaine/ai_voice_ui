import 'package:flutter/material.dart';

import 'scene_motion.dart';
import 'scene_radius.dart';
import 'scene_space.dart';
import 'scene_theme.dart';

/// État squelette (RG-02) : bloc grisé en attendant les données.
///
/// Il ne peint pas le fond du panneau (la décoration du canevas, pdr-0084 U9) :
/// seul le bloc grisé qui pulse est dessiné, à 16 px du bord de la cellule
/// (la marge des cellules), avec le rayon `SceneRadius.md`.
///
/// Statique par défaut, pour que `pumpAndSettle` termine. Avec
/// `animate: true`, une pulsation douce tourne sur la période du jeton
/// `motion.skeleton`, pilotée par `SceneMotionScope.loop` : elle suit la vitesse
/// de rejeu et s'arrête quand les animations sont coupées.
class DsSkeleton extends StatefulWidget {
  const DsSkeleton({super.key, this.animate = false});

  final bool animate;

  @override
  State<DsSkeleton> createState() => _DsSkeletonState();
}

class _DsSkeletonState extends State<DsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SceneMotion.skeleton,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DsSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  // Pulsation selon le réglage d'animation de la scène ; immobile sinon.
  void _sync() {
    if (widget.animate) {
      SceneMotionScope.loop(
        context,
        _controller,
        SceneMotion.skeleton,
        reverse: true,
      );
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SceneTheme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(
          theme.neutralBackground,
          theme.surface,
          _controller.value * 0.6,
        )!;
        return SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(SceneSpace.space4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: SceneRadius.borderMd,
              ),
            ),
          ),
        );
      },
    );
  }
}
