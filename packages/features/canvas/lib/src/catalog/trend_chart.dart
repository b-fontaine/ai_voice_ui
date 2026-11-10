import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart' show ComponentImplementation;
import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../ui/surface_restored.dart';
import 'bound_item.dart';
import 'text_metrics.dart';
import 'trend_chart_painter.dart';
import 'trend_geometry.dart';
import 'trend_head.dart';
import 'trend_legend.dart';

/// `TrendChart` : courbes par série (3.3 / 3.4), seuil, jours, légende.
///
/// Habillage du design system (spec 019, pdr-0088 F4) : légende à traits, grille,
/// axe des valeurs, zone sous la série courante, zone de franchissement du
/// seuil, point de tête avec sa valeur et annotation « ▲ seuil franchi dès Jn ».
/// Toutes ces valeurs sont dérivées de la donnée (`trend_geometry.dart`) ; le
/// tracé se dévoile de gauche à droite (`gc-wipe`).
final ComponentImplementation trendChartItem = boundCatalogItem<_Trend>(
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
    required this.focus,
    required this.area,
    required this.breach,
    required this.breachX,
    required this.callout,
    required this.headValue,
  });

  final String title;
  final double thresholdPct;
  final double yMaxPct;
  final List<String> days;
  final List<_RawSeries> series;

  /// Dérivations de la série suivie (`trend_geometry.dart`), faites une fois à
  /// l'analyse : jamais de calcul de donnée dans `build`.
  final TrendFocus? focus;
  final List<TrendPoint> area;
  final List<TrendPoint> breach;

  /// Abscisse (indice fractionnaire de jour) du croisement du seuil.
  final double? breachX;

  /// « ▲ seuil franchi dès J5 » ; `null` sans franchissement.
  final String? callout;

  /// « 0,84 % » : dernier point de la série suivie.
  final String? headValue;

  /// Mêmes séries (noms et points) ? Un titre qui change ne rejoue pas le tracé.
  bool sameSeries(_Trend other) {
    if (other.series.length != series.length) return false;
    for (int i = 0; i < series.length; i++) {
      final _RawSeries a = series[i];
      final _RawSeries b = other.series[i];
      if (a.name != b.name || a.points.length != b.points.length) return false;
      for (int k = 0; k < a.points.length; k++) {
        if (a.points[k] != b.points[k]) return false;
      }
    }
    return true;
  }

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
    final TrendFocus? focus = trendFocus(<({String name, List<double> points})>[
      for (final _RawSeries s in series) (name: s.name, points: s.points),
    ], threshold);
    final List<double>? followed = focus == null
        ? null
        : series[focus.seriesIndex].points;
    return _Trend(
      title: title,
      thresholdPct: threshold,
      yMaxPct: yMax,
      days: days,
      series: series,
      focus: focus,
      area: followed == null ? const <TrendPoint>[] : areaPolygon(followed),
      breach: followed == null
          ? const <TrendPoint>[]
          : breachPolygon(followed, threshold),
      breachX: followed == null ? null : breachCrossingX(followed, threshold),
      callout: followed == null
          ? null
          : breachCallout(days, followed, threshold),
      headValue: followed == null || followed.isEmpty
          ? null
          : formatPct(followed.last),
    );
  }
}

Color _platformColor(SceneTheme theme, String name) {
  final String lower = name.toLowerCase();
  if (lower.startsWith('ios')) return theme.chartIos;
  if (lower.startsWith('android')) return theme.chartAndroid;
  return theme.chartOther;
}

/// Début du point de tête dans la lecture (`gc-rise .4s 1.5s`) : il apparaît
/// quand le tracé s'achève.

/// Durée de la lecture : le dévoilement (1,6 s), puis la fin de l'apparition de
/// la tête. Une seule horloge ; chaque phase en prend une tranche.
final Duration _total =
    SceneMotion.headDelay + SceneMotion.headRise > SceneMotion.wipe
    ? SceneMotion.headDelay + SceneMotion.headRise
    : SceneMotion.wipe;

double _share(Duration d) => d.inMicroseconds / _total.inMicroseconds;

/// Marge autour du tracé que le dévoilement ne rogne pas (lueur, points).
const double _bleed = 8;

class _TrendView extends StatefulWidget {
  const _TrendView({required this.trend});

  final _Trend trend;

  @override
  State<_TrendView> createState() => _TrendViewState();
}

class _TrendViewState extends State<_TrendView>
    with SingleTickerProviderStateMixin<_TrendView>, SceneOneShot<_TrendView> {
  late final bool _restored = SurfaceRestored.of(context);
  bool _started = false;

  late final Animation<double> _wipe = CurveTween(
    curve: Interval(0, _share(SceneMotion.wipe), curve: SceneMotion.curve),
  ).animate(oneShot);

  late final Animation<double> _rise = CurveTween(
    curve: Interval(_share(SceneMotion.headDelay), 1, curve: SceneMotion.curve),
  ).animate(oneShot);

  @override
  Duration get oneShotBase => _total;

  // Surface restaurée : l'état final, sans rejouer le tracé (pdr-0088 F13).
  @override
  double get oneShotInitialValue => _restored ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_restored) playOneShot();
  }

  // Le tracé rejoue à chaque changement de série (mutation de l'acte 2), jamais
  // à une mise à jour qui laisse les séries inchangées.
  @override
  void didUpdateWidget(_TrendView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.trend.sameSeries(widget.trend)) playOneShot();
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final _Trend trend = widget.trend;
    // Couleur par plateforme (préfixe du nom), jamais une couleur de statut ;
    // la série comparée « 3.3 » se distingue par le pointillé. Le seuil prend
    // la couleur « bloquant ».
    final List<TrendSeries> series = <TrendSeries>[
      for (final _RawSeries raw in trend.series)
        TrendSeries(
          name: raw.name,
          points: raw.points,
          color: _platformColor(theme, raw.name),
          dashed: isComparedSeries(raw.name),
        ),
    ];
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DsPanelHead.title(title: trend.title, wrap: true),
          TrendLegend(series: series, thresholdPct: trend.thresholdPct),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  _chart(context, theme, series, constraints.biggest),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chart(
    BuildContext context,
    SceneTheme theme,
    List<TrendSeries> series,
    Size size,
  ) {
    final _Trend trend = widget.trend;
    final TextStyle tickStyle = theme.micro.tick.copyWith(
      color: theme.textSecondary,
    );
    final List<double> ticks = trendTicks(trend.yMaxPct);
    double axisWidth = 0;
    for (final double tick in ticks) {
      final double w = measureTextWidth(context, formatTick(tick), tickStyle);
      if (w > axisWidth) axisWidth = w;
    }
    final double tickHeight = measureTextHeight(
      context,
      '0',
      tickStyle,
      double.infinity,
    );
    final List<double> dayWidths = <double>[
      for (final String day in trend.days)
        measureTextWidth(context, day, tickStyle).ceilToDouble() + 1,
    ];
    final Rect? plot = trendPlotRect(
      size: size,
      axisLabelWidth: axisWidth.ceilToDouble() + 1,
      firstDayWidth: dayWidths.first,
      lastDayWidth: dayWidths.last,
      tickHeight: tickHeight,
      dayHeight: tickHeight,
    );
    if (plot == null) return const SizedBox.shrink();

    final int count = trend.days.length;
    Offset project(TrendPoint p) => Offset(
      trendX(p.x, count, plot.width),
      trendY(p.y, trend.yMaxPct, plot.height),
    );
    final TrendFocus? focus = trend.focus;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Statique : grille et valeurs de l'axe, hors du dévoilement.
        Positioned.fromRect(
          rect: plot,
          child: KeyedSubtree(
            key: const Key('trend-plot'),
            child: CustomPaint(
              key: const Key('trend-grid'),
              painter: TrendGridPainter(
                ticks: ticks,
                yMaxPct: trend.yMaxPct,
                color: theme.line,
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: Rect.fromLTRB(
            0,
            plot.top - tickHeight / 2,
            plot.left - trendAxisGap,
            plot.bottom + tickHeight / 2,
          ),
          child: Stack(
            key: const Key('trend-axis'),
            clipBehavior: Clip.none,
            children: <Widget>[
              for (final double tick in ticks)
                Positioned(
                  left: 0,
                  right: 0,
                  top:
                      plot.top +
                      trendY(tick, trend.yMaxPct, plot.height) -
                      tickHeight / 2 -
                      (plot.top - tickHeight / 2),
                  child: Text(
                    formatTick(tick),
                    style: tickStyle,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
            ],
          ),
        ),
        for (int i = 0; i < count; i++)
          Positioned(
            left:
                plot.left +
                trendX(i.toDouble(), count, plot.width) -
                dayWidths[i] / 2,
            top: plot.bottom + trendDayGap,
            width: dayWidths[i],
            child: Text(
              trend.days[i],
              style: tickStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        // Séries et zones : dévoilées de gauche à droite par un `ClipRect` à
        // `reclip`, au-dessus d'un `RepaintBoundary` qui garde leur image.
        Positioned.fromRect(
          rect: plot.inflate(_bleed),
          child: ClipRect(
            key: const Key('trend-reveal'),
            clipper: _Wipe(_wipe),
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(_bleed),
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    if (trend.area.isNotEmpty)
                      _zone(
                        const Key('trend-area'),
                        trend.area.map(project).toList(),
                        theme.signalGhost,
                      ),
                    if (trend.breach.isNotEmpty)
                      _zone(
                        const Key('trend-breach'),
                        trend.breach.map(project).toList(),
                        theme.blockingBackground,
                      ),
                    CustomPaint(
                      key: const Key('trend-chart-paint'),
                      painter: TrendChartPainter(
                        series: series,
                        thresholdPct: trend.thresholdPct,
                        yMaxPct: trend.yMaxPct,
                        thresholdColor: theme.blockingForeground,
                        dotFill: theme.background,
                        headSeries: focus?.seriesIndex,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (focus != null && trend.headValue != null)
          Positioned.fill(
            child: TrendHeadLayer(
              animation: _rise,
              reveal: oneShot,
              plot: plot,
              head: plot.topLeft + project(_headPoint(focus, trend)),
              color: series[focus.seriesIndex].color,
              value: trend.headValue!,
              aboveThreshold:
                  trend.series[focus.seriesIndex].points.last >
                  trend.thresholdPct,
              callout: trend.callout,
              calloutAt: trend.breachX == null
                  ? null
                  : plot.topLeft +
                        project(TrendPoint(trend.breachX!, trend.thresholdPct)),
            ),
          ),
      ],
    );
  }

  TrendPoint _headPoint(TrendFocus focus, _Trend trend) {
    final List<double> points = trend.series[focus.seriesIndex].points;
    return TrendPoint((points.length - 1).toDouble(), points.last);
  }

  /// Zone pleine posée par sa boîte englobante : un widget de la géométrie
  /// exacte du polygone.
  Widget _zone(Key key, List<Offset> points, Color color) {
    double minX = points.first.dx, maxX = minX;
    double minY = points.first.dy, maxY = minY;
    for (final Offset p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final Rect box = Rect.fromLTRB(minX, minY, maxX, maxY);
    return Positioned.fromRect(
      rect: box,
      child: CustomPaint(
        key: key,
        painter: TrendPolygonPainter(
          points: <Offset>[for (final Offset p in points) p - box.topLeft],
          color: color,
        ),
      ),
    );
  }
}

/// Rognage du dévoilement : la fraction de la largeur déjà découverte.
class _Wipe extends CustomClipper<Rect> {
  _Wipe(this.progress) : super(reclip: progress);

  final Animation<double> progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.value, size.height);

  @override
  bool shouldReclip(_Wipe oldClipper) => oldClipper.progress != progress;
}
