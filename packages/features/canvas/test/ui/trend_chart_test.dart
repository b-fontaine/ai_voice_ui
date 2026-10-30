import 'dart:ui';

import 'package:feature_canvas/src/catalog/trend_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

void main() {
  defineCommonStateTests(
    component: 'TrendChart',
    surface: 'trend',
    fixtureName: 'trend',
    completeText: 'Taux de crash du jour',
    badValues: <String, Object?>{
      'séries de longueurs incohérentes': <String, Object>{
        'title': 'T',
        'thresholdPct': 0.5,
        'yMaxPct': 1.0,
        'days': <String>['J1', 'J2'],
        'series': <Object>[
          <String, Object>{
            'name': 'iOS',
            'points': <double>[0.2],
          },
        ],
      },
      'points non numériques': <String, Object>{
        'title': 'T',
        'thresholdPct': 0.5,
        'yMaxPct': 1.0,
        'days': <String>['J1'],
        'series': <Object>[
          <String, Object>{
            'name': 'iOS',
            'points': <String>['x'],
          },
        ],
      },
      'séries absentes (liste vide)': <String, Object>{
        'title': 'T',
        'thresholdPct': 0.5,
        'yMaxPct': 1.0,
        'days': <String>['J1'],
        'series': <Object>[],
      },
      'yMaxPct nul': <String, Object>{
        'title': 'T',
        'thresholdPct': 0.5,
        'yMaxPct': 0,
        'days': <String>['J1'],
        'series': <Object>[
          <String, Object>{
            'name': 'iOS',
            'points': <double>[0.2],
          },
        ],
      },
      'seuil de mauvais type': <String, Object>{
        'title': 'T',
        'thresholdPct': 'haut',
        'yMaxPct': 1.0,
        'days': <String>['J1'],
        'series': <Object>[
          <String, Object>{
            'name': 'iOS',
            'points': <double>[0.2],
          },
        ],
      },
    },
  );

  testWidgets('courbe peinte : légende, jours et seuil de l acte 1', (
    tester,
  ) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(h.inCell(find.text('Taux de crash du jour')), findsOneWidget);
    expect(h.inCell(find.text('iOS')), findsOneWidget);
    expect(h.inCell(find.text('Android')), findsOneWidget);
    expect(h.inCell(find.textContaining('0,50 %')), findsOneWidget);
    expect(
      h.inCell(find.byKey(const Key('trend-chart-paint'))),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('trend-chart-paint')),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    final paint = tester.widget<CustomPaint>(
      find.byKey(const Key('trend-chart-paint')),
    );
    final painter = paint.painter! as TrendChartPainter;
    expect(painter.days, hasLength(7));
    expect(painter.series, hasLength(2));
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  group('TrendChartPainter', () {
    TrendChartPainter build({
      double yMax = 1.0,
      double threshold = 0.5,
      List<TrendSeries>? series,
      List<String> days = const <String>['J1', 'J2', 'J3'],
    }) => TrendChartPainter(
      days: days,
      series:
          series ??
          const <TrendSeries>[
            TrendSeries(
              name: 'A',
              points: <double>[0.1, 0.5, 0.9],
              color: Color(0xFFFFFFFF),
            ),
          ],
      thresholdPct: threshold,
      yMaxPct: yMax,
      thresholdColor: const Color(0xFFFF0000),
      axisColor: const Color(0xFF888888),
      labelStyle: const TextStyle(fontSize: 24, color: Color(0xFFFFFFFF)),
    );

    test('yFor convertit une valeur en ordonnée bornée par yMaxPct', () {
      final p = build();
      expect(p.yFor(0, 100), 100);
      expect(p.yFor(1.0, 100), 0);
      expect(p.yFor(0.5, 100), 50);
      expect(p.yFor(2.0, 100), 0, reason: 'au-dessus de yMax : borné en haut');
      expect(p.yFor(-1, 100), 100, reason: 'négatif : borné en bas');
      expect(build(yMax: 2.0).yFor(0.5, 100), 75);
    });

    test('xFor répartit les jours, un seul jour au centre', () {
      final p = build();
      expect(p.xFor(0, 3, 200), 0);
      expect(p.xFor(1, 3, 200), 100);
      expect(p.xFor(2, 3, 200), 200);
      expect(p.xFor(0, 1, 200), 100);
    });

    test('shouldRepaint détecte un changement de données ou de seuil', () {
      final p = build();
      expect(p.shouldRepaint(build()), isFalse);
      expect(p.shouldRepaint(build(threshold: 0.6)), isTrue);
      expect(p.shouldRepaint(build(yMax: 2)), isTrue);
      expect(
        p.shouldRepaint(
          build(
            series: const <TrendSeries>[
              TrendSeries(
                name: 'A',
                points: <double>[0.1, 0.5, 0.8],
                color: Color(0xFFFFFFFF),
              ),
            ],
          ),
        ),
        isTrue,
      );
    });

    testWidgets('paint ne lève pas, y compris hors bornes', (tester) async {
      final p = build(
        series: const <TrendSeries>[
          TrendSeries(
            name: 'A',
            points: <double>[-3, 5, 0.2],
            color: Color(0xFFFFFFFF),
          ),
        ],
      );
      final recorder = PictureRecorder();
      p.paint(Canvas(recorder), const Size(300, 150));
      recorder.endRecording();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('couleurs issues de SceneTheme', (tester) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    final theme = const SceneTheme.dark();
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('trend-chart-paint')))
                .painter!
            as TrendChartPainter;
    final allowed = <Color>{
      theme.accent,
      theme.okForeground,
      theme.riskForeground,
      theme.blockingForeground,
      theme.textSecondary,
      theme.textPrimary,
    };
    for (final s in painter.series) {
      expect(allowed, contains(s.color));
    }
    expect(allowed, contains(painter.thresholdColor));
    expect(allowed, contains(painter.axisColor));
  });
}
