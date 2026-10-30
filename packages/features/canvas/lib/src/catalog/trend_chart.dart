import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'bound_item.dart';
import 'trend_chart_painter.dart';

/// `TrendChart` : courbes par série (3.3 / 3.4), seuil, jours, légende.
final CatalogItem trendChartItem = boundCatalogItem<_Trend>(
  name: 'TrendChart',
  description: 'Courbe de tendance liée à /trend.',
  parse: _Trend.tryParse,
  build: (BuildContext context, _Trend trend) => _TrendView(trend: trend),
);

class _RawSeries {
  const _RawSeries(this.name, this.points);

  final String name;
  final List<double> points;
}

/// Objet `/trend` validé : un point par jour dans chaque série.
class _Trend {
  const _Trend({
    required this.title,
    required this.thresholdPct,
    required this.yMaxPct,
    required this.days,
    required this.series,
  });

  final String title;
  final double thresholdPct;
  final double yMaxPct;
  final List<String> days;
  final List<_RawSeries> series;

  static _Trend? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? title = readString(raw, 'title');
    final double? threshold = readNumber(raw, 'thresholdPct');
    final double? yMax = readNumber(raw, 'yMaxPct');
    final Object? rawDays = raw['days'];
    final List<Map<Object?, Object?>>? rawSeries = readMaps(raw, 'series');
    if (title == null ||
        threshold == null ||
        yMax == null ||
        yMax <= 0 ||
        rawDays is! List ||
        rawDays.isEmpty ||
        rawSeries == null ||
        rawSeries.isEmpty) {
      return null;
    }
    final List<String> days = <String>[];
    for (final Object? d in rawDays) {
      if (d is! String) return null;
      days.add(d);
    }
    final List<_RawSeries> series = <_RawSeries>[];
    for (final Map<Object?, Object?> s in rawSeries) {
      final String? name = readString(s, 'name');
      final Object? rawPoints = s['points'];
      if (name == null ||
          rawPoints is! List ||
          rawPoints.length != days.length) {
        return null;
      }
      final List<double> points = <double>[];
      for (final Object? p in rawPoints) {
        if (p is! num || !p.isFinite) return null;
        points.add(p.toDouble());
      }
      series.add(_RawSeries(name, points));
    }
    return _Trend(
      title: title,
      thresholdPct: threshold,
      yMaxPct: yMax,
      days: days,
      series: series,
    );
  }
}

/// « 0.5 » donne « 0,50 % » (format français de la fiche).
String _pct(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} %';

class _TrendView extends StatelessWidget {
  const _TrendView({required this.trend});

  final _Trend trend;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    // Couleurs de séries prises dans le thème, par rang ; le seuil prend la
    // couleur « bloquant ».
    final List<Color> palette = <Color>[
      theme.accent,
      theme.okForeground,
      theme.riskForeground,
    ];
    final List<TrendSeries> series = <TrendSeries>[
      for (int i = 0; i < trend.series.length; i++)
        TrendSeries(
          name: trend.series[i].name,
          points: trend.series[i].points,
          color: palette[i % palette.length],
        ),
    ];
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  trend.title,
                  style: theme.label.copyWith(color: theme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final TrendSeries s in series)
                Flexible(
                  child: _LegendEntry(color: s.color, text: s.name),
                ),
              Flexible(
                child: _LegendEntry(
                  color: theme.blockingForeground,
                  text: 'Seuil ${_pct(trend.thresholdPct)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const Key('trend-chart-paint'),
                size: Size.infinite,
                painter: TrendChartPainter(
                  days: trend.days,
                  series: series,
                  thresholdPct: trend.thresholdPct,
                  yMaxPct: trend.yMaxPct,
                  thresholdColor: theme.blockingForeground,
                  axisColor: theme.textSecondary,
                  labelStyle: theme.body.copyWith(color: theme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
