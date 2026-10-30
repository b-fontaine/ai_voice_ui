import 'package:flutter/material.dart';

import 'scene_theme.dart';

/// État squelette (RG-02) : bloc grisé en attendant les données.
///
/// Statique par défaut, pour que `pumpAndSettle` termine. Avec
/// `animate: true`, une pulsation douce tourne tant qu'un `TickerMode`
/// ancêtre l'autorise.
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
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(DsSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}
