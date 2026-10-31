import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'delegation_link_geometry.dart';

/// Peint les liaisons de délégation en pointillés qui défilent de
/// l'orchestrateur vers les agents.
///
/// [phase] (0 à 1) est une période de pointillé : le peintre s'abonne à
/// l'animation (`repaint`), sans reconstruire de widget à chaque image. Le
/// filtre par état des agents n'est pas ici : [links] ne contient que les
/// liens à dessiner. [color] vient du thème de scène.
class DelegationLinkPainter extends CustomPainter {
  DelegationLinkPainter({
    required this.links,
    required this.color,
    required this.phase,
  }) : super(repaint: phase);

  /// Longueur d'un trait.
  static const double dashLength = 14;

  /// Longueur d'un vide.
  static const double gapLength = 10;

  static const double _period = dashLength + gapLength;

  final List<DelegationLinkGeometry> links;
  final Color color;
  final Animation<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (links.isEmpty) return;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = DelegationLinkGeometry.strokeWidth;
    // Les traits avancent le long du chemin, donc vers l'agent.
    final double shift = (phase.value % 1) * _period;
    for (final DelegationLinkGeometry link in links) {
      final PathMetric metric = link.metric;
      final Path dashes = Path();
      for (double d = shift - _period; d < metric.length; d += _period) {
        final double from = math.max(0, d);
        final double to = math.min(metric.length, d + dashLength);
        if (to > from) {
          dashes.addPath(metric.extractPath(from, to), Offset.zero);
        }
      }
      canvas.drawPath(dashes, paint);
    }
  }

  @override
  bool shouldRepaint(DelegationLinkPainter oldDelegate) =>
      color != oldDelegate.color ||
      !identical(phase, oldDelegate.phase) ||
      !listEquals(links, oldDelegate.links);
}
