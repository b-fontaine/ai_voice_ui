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
  build: (BuildContext context, _Trend trend, String _) =>
      _TrendView(trend: trend),
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

Color _platformColor(SceneTheme theme, String name) {
  final String lower = name.toLowerCase();
  if (lower.startsWith('ios')) return theme.chartIos;
  if (lower.startsWith('android')) return theme.chartAndroid;
  return theme.chartOther;
}

class _TrendView extends StatelessWidget {
  const _TrendView({required this.trend});

  final _Trend trend;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    // Couleur par plateforme (préfixe du nom), jamais une couleur de statut ;
    // la série « 3.3 » se distingue par le trait pointillé. Le seuil prend la
    // couleur « bloquant ».
    final List<TrendSeries> series = <TrendSeries>[
      for (final _RawSeries raw in trend.series)
        TrendSeries(
          name: raw.name,
          points: raw.points,
          color: _platformColor(theme, raw.name),
          dashed: raw.name.endsWith('3.3'),
        ),
    ];
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TrendHeader(
            title: trend.title,
            legend: <_LegendEntry>[
              for (final TrendSeries s in series)
                _LegendEntry(
                  key: Key('trend-series-${s.name}'),
                  color: s.color,
                  text: s.name,
                ),
              _LegendEntry(
                color: theme.blockingForeground,
                text: 'Seuil ${_pct(trend.thresholdPct)}',
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
                  labelStyle: sceneTextStyle(
                    context,
                    theme.body.copyWith(color: theme.textSecondary),
                  ),
                  textScaler: MediaQuery.textScalerOf(context),
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
  const _LegendEntry({super.key, required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        // Une entrée passe à la ligne du `Wrap` plutôt que d'être coupée ; seul
        // un nom plus large que la cellule entière prend l'ellipse (garde
        // contre un débordement du tracé).
        Flexible(
          child: Text(
            text,
            style: theme.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// En-tête : le titre sur sa propre ligne (il passe à la ligne s'il est long,
/// jamais tronqué), la légende dessous dans un `Wrap`, le tracé sur le reste.
class _TrendHeader extends StatelessWidget {
  const _TrendHeader({required this.title, required this.legend});

  static const double _gap = 20;

  final String title;
  final List<_LegendEntry> legend;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.label.copyWith(color: theme.textPrimary)),
        Wrap(spacing: _gap, children: legend),
      ],
    );
  }
}
