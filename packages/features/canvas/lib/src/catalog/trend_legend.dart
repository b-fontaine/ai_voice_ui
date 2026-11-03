import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart';

import 'trend_chart_painter.dart';
import 'trend_geometry.dart';

/// Légende (`.gc-legend`) : un trait de 18 x 3 px par série, puis le seuil en
/// tirets. Les entrées passent à la ligne du `Wrap` plutôt que d'être coupées.
class TrendLegend extends StatelessWidget {
  const TrendLegend({
    super.key,
    required this.series,
    required this.thresholdPct,
  });

  final List<TrendSeries> series;

  /// Seuil nogo, en pourcentage.
  final double thresholdPct;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: <Widget>[
        for (final TrendSeries s in series)
          _LegendEntry(
            key: Key('trend-series-${s.name}'),
            swatchKey: Key('trend-swatch-${s.name}'),
            color: s.color,
            style: s.dashed ? TrendSwatchStyle.dotted : TrendSwatchStyle.solid,
            text: s.name,
          ),
        _LegendEntry(
          key: const Key('trend-threshold-legend'),
          swatchKey: const Key('trend-threshold-swatch'),
          color: theme.blockingForeground,
          style: TrendSwatchStyle.dashed,
          text: 'Seuil ${formatPct(thresholdPct)}',
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    super.key,
    required this.swatchKey,
    required this.color,
    required this.style,
    required this.text,
  });

  final Key swatchKey;
  final Color color;
  final TrendSwatchStyle style;
  final String text;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          key: swatchKey,
          width: 18,
          height: 3,
          child: CustomPaint(
            painter: TrendSwatchPainter(color: color, style: style),
          ),
        ),
        const SizedBox(width: 6),
        // Flexible : seul un nom plus large que la cellule entière prend
        // l'ellipse (garde contre un débordement du tracé).
        Flexible(
          child: Text(
            text,
            style: theme.micro.legend.copyWith(color: theme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
