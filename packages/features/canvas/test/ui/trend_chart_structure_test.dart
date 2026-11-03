import 'package:feature_canvas/src/catalog/trend_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Structure du graphique (pdr-0088 F4, scénario V-03) : légende à traits,
/// grille, axe des valeurs, zones, point de tête, valeur et annotation, tous
/// posés par la géométrie de la donnée.
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);
const SceneTheme _theme = SceneTheme.dark();

Finder _key(String name) => find.byKey(Key(name));

String _text(WidgetTester tester, String key) {
  final Finder finder = find.descendant(
    of: _key(key),
    matching: find.byType(Text),
    matchRoot: true,
  );
  return (tester.widget(finder.first) as Text).data!;
}

Future<CatalogHarness> _act1(WidgetTester tester) async {
  final h = CatalogHarness('trend', 'trend', size: const Size(936, 302));
  await h.pump(tester, motion: _still);
  await h.sendFixtureTo(tester, 3);
  return h;
}

Future<CatalogHarness> _act2(WidgetTester tester) async {
  final h = await _act1(tester);
  await h.sendVariant(tester, 'act2');
  return h;
}

void main() {
  testWidgets('acte 1 : toutes les parties sont là', (tester) async {
    await _act1(tester);
    for (final String key in <String>[
      'trend-plot',
      'trend-grid',
      'trend-axis',
      'trend-area',
      'trend-breach',
      'trend-head',
      'trend-head-value',
      'trend-callout',
      'trend-threshold-legend',
      'trend-swatch-iOS',
      'trend-swatch-Android',
    ]) {
      expect(_key(key), findsOneWidget, reason: key);
    }
  });

  testWidgets('annotation et valeur de tête sont des Text dérivés de la '
      'série : dès J5, 0,84 %', (tester) async {
    await _act1(tester);
    expect(_text(tester, 'trend-callout'), '▲ seuil franchi dès J5');
    expect(_text(tester, 'trend-head-value'), '0,84 %');
    final Text callout = tester.widget(_key('trend-callout'));
    expect(callout.style?.fontSize, _theme.micro.callout.fontSize);
    expect(callout.style?.fontWeight, _theme.micro.callout.fontWeight);
    expect(callout.style?.color, _theme.blockingForeground);
  });

  testWidgets('la zone sous la série couvre le tracé ; la zone de '
      'franchissement commence à 50 % (J4, seuil) et va au bord droit', (
    tester,
  ) async {
    await _act1(tester);
    final Rect plot = tester.getRect(_key('trend-plot'));
    final Rect area = tester.getRect(_key('trend-area'));
    final Rect breach = tester.getRect(_key('trend-breach'));
    expect(area.left, closeTo(plot.left, 0.5));
    expect(area.right, closeTo(plot.right, 0.5));
    expect(area.bottom, closeTo(plot.bottom, 0.5));
    expect(breach.left, closeTo(plot.left + plot.width / 2, 0.5));
    expect(breach.right, closeTo(plot.right, 0.5));
    // Entre le seuil (0,50 sur 1,00 : mi-hauteur) et la valeur de tête.
    expect(breach.bottom, closeTo(plot.top + plot.height / 2, 0.5));
    expect(breach.top, closeTo(plot.top + plot.height * (1 - 0.84), 0.5));
  });

  testWidgets('couleurs des zones : signal-ghost sous la série, nogo-ghost '
      'au franchissement', (tester) async {
    await _act1(tester);
    Color? color(String key) {
      final CustomPaint paint = tester.widget(
        find.descendant(
          of: _key(key),
          matching: find.byType(CustomPaint),
          matchRoot: true,
        ),
      );
      return (paint.painter! as TrendPolygonPainter).color;
    }

    expect(color('trend-area'), _theme.signalGhost);
    expect(color('trend-breach'), _theme.blockingBackground);
  });

  testWidgets('le point de tête est un disque de 10 px au dernier jour de '
      'la série suivie', (tester) async {
    await _act1(tester);
    final Rect plot = tester.getRect(_key('trend-plot'));
    final Rect head = tester.getRect(_key('trend-head'));
    expect(head.size, const Size(10, 10));
    expect(head.center.dx, closeTo(plot.right, 0.5));
    expect(head.center.dy, closeTo(plot.top + plot.height * (1 - 0.84), 0.5));
    final Rect value = tester.getRect(_key('trend-head-value'));
    expect(value.right, lessThan(head.left));
    expect(value.bottom, lessThanOrEqualTo(head.center.dy));
  });

  testWidgets('l\'annotation est sous le seuil, à droite du croisement', (
    tester,
  ) async {
    await _act1(tester);
    final Rect plot = tester.getRect(_key('trend-plot'));
    final Rect callout = tester.getRect(_key('trend-callout'));
    expect(callout.left, greaterThan(plot.left + plot.width / 2));
    expect(callout.top, greaterThan(plot.top + plot.height / 2));
    expect(callout.right, lessThanOrEqualTo(plot.right));
  });

  testWidgets('légende à traits de 18 x 3 px, texte en ink-muted', (
    tester,
  ) async {
    await _act2(tester);
    for (final String name in <String>['Android 3.4', 'Android 3.3']) {
      expect(tester.getSize(_key('trend-swatch-$name')), const Size(18, 3));
    }
    final Text legend = tester.widget(
      find.descendant(
        of: _key('trend-series-Android 3.4'),
        matching: find.text('Android 3.4'),
      ),
    );
    expect(legend.style?.fontSize, _theme.micro.legend.fontSize);
    expect(legend.style?.color, _theme.textSecondary);
    expect(_text(tester, 'trend-threshold-legend'), 'Seuil 0,50 %');
    expect(tester.getSize(_key('trend-threshold-swatch')), const Size(18, 3));
  });

  testWidgets('acte 2 : une seule zone, sur Android 3.4 ; la 3.3 n\'a ni zone '
      'ni point de tête', (tester) async {
    await _act2(tester);
    expect(_key('trend-area'), findsOneWidget);
    expect(_key('trend-breach'), findsOneWidget);
    expect(_key('trend-head'), findsOneWidget);
    expect(_text(tester, 'trend-callout'), '▲ seuil franchi dès J5');
    expect(_text(tester, 'trend-head-value'), '0,84 %');
  });

  testWidgets('correction iOS : sans franchissement, ni zone de '
      'franchissement ni annotation', (tester) async {
    final h = await _act2(tester);
    await h.sendVariant(tester, 'correction-ios');
    expect(_key('trend-breach'), findsNothing);
    expect(_key('trend-callout'), findsNothing);
    expect(_key('trend-area'), findsOneWidget, reason: 'série courante unique');
    expect(_text(tester, 'trend-head-value'), '0,19 %');
  });

  testWidgets('graduations en ink-muted (jamais ink-faint sous 24 px, F12), '
      'jours sous le tracé', (tester) async {
    await _act1(tester);
    final Finder ticks = find.descendant(
      of: _key('trend-axis'),
      matching: find.byType(Text),
    );
    expect(ticks, findsNWidgets(4));
    expect(
      <String>[
        for (final Element e in ticks.evaluate()) (e.widget as Text).data!,
      ],
      <String>['0,25', '0,50', '0,75', '1,00'],
    );
    final Rect plot = tester.getRect(_key('trend-plot'));
    for (final Element e in ticks.evaluate()) {
      final Text text = e.widget as Text;
      expect(text.style?.color, _theme.textSecondary);
      expect(text.style?.fontSize, _theme.micro.tick.fontSize);
      expect(tester.getRect(find.byWidget(text)).right, lessThan(plot.left));
    }
    for (final String day in <String>['J1', 'J4', 'J7']) {
      final Finder label = find.descendant(
        of: find.byKey(const Key('surface-trend')),
        matching: find.text(day),
      );
      expect(label, findsOneWidget);
      expect(
        tester.getRect(label).top,
        greaterThanOrEqualTo(plot.bottom - 0.5),
      );
      expect((tester.widget(label) as Text).style?.color, _theme.textSecondary);
    }
  });

  testWidgets('la grille est peinte en `line`, sous le dévoilement', (
    tester,
  ) async {
    await _act1(tester);
    final Finder grid = find.descendant(
      of: _key('trend-grid'),
      matching: find.byType(CustomPaint),
      matchRoot: true,
    );
    expect(
      tester.renderObject(grid.first),
      paints
        ..line(color: _theme.line)
        ..line(color: _theme.line),
    );
  });

  testWidgets('aucun texte n\'est peint au canevas : le painter des séries '
      'ne porte plus de style de texte', (tester) async {
    await _act1(tester);
    final CustomPaint paint = tester.widget(_key('trend-chart-paint'));
    expect(paint.painter.runtimeType.toString(), 'TrendChartPainter');
    expect(tester.takeException(), isNull);
  });
}
