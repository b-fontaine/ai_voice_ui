import 'dart:math' as math;
import 'dart:ui';

import 'package:feature_canvas/src/catalog/trend_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Harnais en polices réelles : Ahem ne permet de juger ni les largeurs ni le
/// retour à la ligne.
CatalogHarness _realFontsHarness({required Size size}) => CatalogHarness(
  'trend',
  'trend',
  size: size,
  fontFamily: realFontFamily,
  fontFamilyFallback: realFontFallback,
);

final Finder _cell = find.byKey(const Key('surface-trend'));

void main() {
  setUpAll(loadRealFonts);

  testWidgets('les jours de l\'axe X prennent le style `tick` du thème '
      '(JetBrains Mono, repli DejaVu Sans), en ink-muted', (tester) async {
    final h = _realFontsHarness(size: const Size(624, 302));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    final Text day = tester.widget(h.inCell(find.text('J1')));
    const theme = SceneTheme.dark();
    expect(day.style?.fontFamily, theme.micro.tick.fontFamily);
    expect(day.style?.fontFamily, SceneFonts.mono);
    expect(day.style?.fontFamilyFallback, SceneFonts.fallbackList);
    expect(day.style?.fontSize, theme.micro.tick.fontSize);
    expect(day.style?.color, theme.textSecondary);
  });

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
    for (var i = 1; i <= 7; i++) {
      expect(h.inCell(find.text('J$i')), findsOneWidget);
    }
    expect(painter.series, hasLength(2));
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('légende de 4 séries aux noms longs : sans débordement', (
    tester,
  ) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    data['series'] = <Map<String, dynamic>>[
      for (var i = 1; i <= 4; i++)
        <String, dynamic>{
          'name': 'Plateforme numéro $i avec un nom vraiment très long',
          'points': <double>[0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
        },
    ];
    await h.sendData(tester, data);

    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
    expect(
      h.inCell(find.byKey(const Key('trend-chart-paint'))),
      findsOneWidget,
    );
    h.expectTextAtLeastScaleMinimum(tester);
  });

  group('en-tête : titre sur sa ligne, légende dessous (D2)', () {
    for (final (String name, Size cell) in <(String, Size)>[
      ('3 x 2 (624 x 302)', Size(624, 302)),
      ('2 x 2 (936 x 302)', Size(936, 302)),
      (
        'cellule très large (1800 x 302) : jamais sur la même ligne',
        Size(1800, 302),
      ),
    ]) {
      testWidgets('$name : titre entier, légende sous le titre, tracé sous '
          'la légende', (tester) async {
        tester.view.physicalSize = Size(cell.width, cell.height + 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = _realFontsHarness(size: cell);
        await h.pump(tester);
        await h.sendFixtureTo(tester, 2);
        await h.sendVariant(tester, 'act2');

        final Finder title = h.inCell(find.text('Taux de crash du jour'));
        expect(title, findsOneWidget);
        expect(paragraphsTruncated(tester, root: _cell), isEmpty);
        final Rect titleRect = tester.getRect(title);
        final Finder entries = h.inCell(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                '${(w.key as ValueKey).value}'.startsWith('trend-series-'),
          ),
        );
        expect(entries, findsNWidgets(2));
        for (final Element e in entries.evaluate()) {
          final Rect entry = tester.getRect(find.byWidget(e.widget));
          expect(entry.top, greaterThanOrEqualTo(titleRect.bottom - 0.5));
        }
        expect(
          tester.getRect(h.inCell(find.textContaining('Seuil'))).top,
          greaterThanOrEqualTo(titleRect.bottom - 0.5),
        );
        final Rect paint = tester.getRect(
          h.inCell(find.byKey(const Key('trend-chart-paint'))),
        );
        for (final Element e in entries.evaluate()) {
          expect(
            paint.top,
            greaterThanOrEqualTo(
              tester.getRect(find.byWidget(e.widget)).bottom,
            ),
          );
        }
        expect(paint.height, greaterThan(100));
        h.expectTextAtLeastScaleMinimum(tester);
        expect(tester.takeException(), isNull);
        expect(h.engineErrors, isEmpty);
      });
    }

    testWidgets('titre très long : retour à la ligne, jamais tronqué, tracé '
        'conservé', (tester) async {
      final h = _realFontsHarness(size: const Size(624, 302));
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      final data = cloneJson(h.data);
      // pdr-0087 / pdr-0088 F1 : à 18 px, un titre ne passe à la ligne qu'à
      // partir d'environ 65 caractères.
      const title =
          'Taux de crash du jour sur Android pour la version 3.4 de la release, '
          'comparé aux trois versions précédentes sur quatorze jours';
      data['title'] = title;
      await h.sendData(tester, data);

      final Finder text = h.inCell(find.text(title));
      expect(text, findsOneWidget);
      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      expect(tester.getSize(text).height, greaterThan(titleLineHeight() * 1.5));
      expect(
        tester
            .getSize(h.inCell(find.byKey(const Key('trend-chart-paint'))))
            .height,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('quatre séries aux noms moyens : les entrées passent à la '
        'ligne du Wrap, rien n\'est tronqué', (tester) async {
      final h = _realFontsHarness(size: const Size(624, 302));
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      final data = cloneJson(h.data);
      data['series'] = <Map<String, dynamic>>[
        for (var i = 1; i <= 4; i++)
          <String, dynamic>{
            'name': 'Android 3.$i production',
            'points': <double>[0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
          },
      ];
      await h.sendData(tester, data);

      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('TrendChartPainter', () {
    TrendChartPainter build({
      double yMax = 1.0,
      double threshold = 0.5,
      List<TrendSeries>? series,
    }) => TrendChartPainter(
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
      dotFill: const Color(0xFF000000),
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

    test(
      'chaque point de la série courante a son disque (deux cercles : '
      'fond et bord) ; le dernier de la série suivie est laissé à la tête',
      () {
        int circles(int? headSeries) {
          final recorder = TestRecordingCanvas();
          TrendChartPainter(
            series: const <TrendSeries>[
              TrendSeries(
                name: 'A',
                points: <double>[0.1, 0.5, 0.9],
                color: Color(0xFFFFFFFF),
              ),
              TrendSeries(
                name: 'A 3.3',
                points: <double>[0.1, 0.2, 0.3],
                color: Color(0xFFFFFFFF),
                dashed: true,
              ),
            ],
            thresholdPct: 0.5,
            yMaxPct: 1,
            thresholdColor: const Color(0xFFFF0000),
            dotFill: const Color(0xFF000000),
            headSeries: headSeries,
          ).paint(recorder, const Size(300, 150));
          return recorder.invocations
              .where((r) => r.invocation.memberName == #drawCircle)
              .length;
        }

        expect(
          circles(null),
          6,
          reason: '3 points x 2 cercles, 3.3 sans point',
        );
        expect(circles(0), 4, reason: 'le point de tête remplace le dernier');
      },
    );

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
      theme.chartIos,
      theme.chartAndroid,
      theme.chartOther,
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
  });

  testWidgets('acte 2 : le titre et la légende s affichent en entier', (
    tester,
  ) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    final RenderParagraph title = tester.renderObject<RenderParagraph>(
      h.inCell(find.text('Taux de crash du jour')),
    );
    expect(title.didExceedMaxLines, isFalse, reason: 'titre coupé');
    for (final String name in <String>['Android 3.4', 'Android 3.3']) {
      final RenderParagraph p = tester.renderObject<RenderParagraph>(
        h.inCell(find.text(name)),
      );
      expect(p.didExceedMaxLines, isFalse, reason: 'légende coupée : $name');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('acte 2 : une entrée de légende par série, couleurs stables', (
    tester,
  ) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    final first = find.byKey(const Key('trend-series-Android 3.4'));
    final second = find.byKey(const Key('trend-series-Android 3.3'));
    expect(h.inCell(first), findsOneWidget);
    expect(h.inCell(second), findsOneWidget);
    expect(
      tester.getTopLeft(first).dx,
      lessThan(tester.getTopLeft(second).dx),
      reason: 'ordre du data model',
    );
    expect(
      find.descendant(of: first, matching: find.text('Android 3.4')),
      findsOneWidget,
    );

    TrendChartPainter painter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('trend-chart-paint')))
                .painter!
            as TrendChartPainter;
    final theme = const SceneTheme.dark();
    expect(painter().series.map((s) => s.name), <String>[
      'Android 3.4',
      'Android 3.3',
    ]);
    expect(painter().series.map((s) => s.color), <Color>[
      theme.chartAndroid,
      theme.chartAndroid,
    ], reason: 'même plateforme, même teinte');
    expect(painter().series.map((s) => s.dashed), <bool>[
      false,
      true,
    ], reason: 'la 3.3 se distingue par le trait pointillé');
    h.expectTextAtLeastScaleMinimum(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  testWidgets('couleur par plateforme : iOS et Android, jamais de statut', (
    tester,
  ) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    final theme = const SceneTheme.dark();
    TrendChartPainter painter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('trend-chart-paint')))
                .painter!
            as TrendChartPainter;
    // Acte 1 : iOS puis Android.
    expect(painter().series.map((s) => s.name), <String>['iOS', 'Android']);
    final act1 = painter().series.map((s) => s.color).toList();
    expect(act1, <Color>[theme.chartIos, theme.chartAndroid]);
    expect(painter().series.map((s) => s.dashed), <bool>[false, false]);

    // Acte 2 : Android garde la couleur qu'il avait à l'acte 1.
    await h.sendVariant(tester, 'act2');
    expect(painter().series.first.color, act1[1]);
    for (final s in painter().series) {
      expect(s.color, isNot(theme.okForeground));
      expect(s.color, isNot(theme.riskForeground));
      expect(s.color, isNot(theme.blockingForeground));
    }
  });

  testWidgets('plateforme inconnue : couleur « autre » sans statut', (
    tester,
  ) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    final data = cloneJson(h.data);
    data['series'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Web',
        'points': <double>[0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
      },
    ];
    await h.sendData(tester, data);
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('trend-chart-paint')))
                .painter!
            as TrendChartPainter;
    expect(painter.series.single.color, const SceneTheme.dark().chartOther);
  });

  testWidgets('correction iOS : une seule série, la couleur d iOS', (
    tester,
  ) async {
    final h = CatalogHarness('trend', 'trend');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');
    await h.sendVariant(tester, 'correction-ios');

    expect(find.byKey(const Key('trend-series-iOS 3.4')), findsOneWidget);
    expect(find.byKey(const Key('trend-series-Android 3.4')), findsNothing);
    expect(find.byKey(const Key('trend-series-Android 3.3')), findsNothing);
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('trend-chart-paint')))
                .painter!
            as TrendChartPainter;
    expect(painter.series.single.color, const SceneTheme.dark().chartIos);
    expect(painter.series.single.dashed, isFalse);
    expect(tester.takeException(), isNull);
  });

  group('design system (U3, U6)', () {
    const SceneTheme theme = SceneTheme.dark();

    double luminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double contrast(Color a, Color b) {
      final double la = luminance(a);
      final double lb = luminance(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    Future<TrendChartPainter> act2Painter(WidgetTester tester) async {
      final h = CatalogHarness('trend', 'trend');
      await h.pump(tester);
      await h.sendFixtureTo(tester, 3);
      await h.sendVariant(tester, 'act2');
      return tester
              .widget<CustomPaint>(find.byKey(const Key('trend-chart-paint')))
              .painter!
          as TrendChartPainter;
    }

    testWidgets('acte 2 : « 3.3 » en pointillés, « 3.4 » plein, même couleur '
        'de plateforme', (tester) async {
      final TrendChartPainter painter = await act2Painter(tester);
      final byName = {for (final s in painter.series) s.name: s};
      expect(byName['Android 3.3']!.dashed, isTrue);
      expect(byName['Android 3.4']!.dashed, isFalse);
      expect(byName['Android 3.3']!.color, theme.chartAndroid);
      expect(byName['Android 3.4']!.color, theme.chartAndroid);
    });

    testWidgets('seuil nogo en tirets : plusieurs segments de la couleur du '
        'seuil', (tester) async {
      final TrendChartPainter painter = await act2Painter(tester);
      expect(painter.thresholdColor, theme.blockingForeground);
      await tester.pump();
      final Finder chart = find.byKey(const Key('trend-chart-paint'));
      expect(
        tester.renderObject(chart),
        paints
          ..line(color: theme.blockingForeground)
          ..line(color: theme.blockingForeground)
          ..line(color: theme.blockingForeground),
        reason: 'une suite de tirets, jamais un trait continu',
      );
    });

    testWidgets(
      'grille en `line` (décorative), graduations et jours de 12 px en '
      'ink-muted à 4,5:1 au moins',
      (tester) async {
        await act2Painter(tester);
        // pdr-0088 F12 : un texte de moins de 24 px n\'est jamais en
        // ink-faint ; seule la grille, décorative, prend la couleur `line`.
        final Finder grid = find.descendant(
          of: find.byKey(const Key('trend-grid')),
          matching: find.byType(CustomPaint),
          matchRoot: true,
        );
        expect(
          tester.renderObject(grid.first),
          paints..line(color: theme.line),
        );
        final Text day = tester.widget(find.text('J1'));
        expect(day.style?.color, theme.textSecondary);
        expect(day.style?.fontSize, theme.micro.tick.fontSize);
        expect(
          contrast(day.style!.color!, theme.panelTop),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(day.style!.color!, theme.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  });
}
