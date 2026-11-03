import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Dévoilement du tracé (`gc-wipe`, pdr-0088 F4 et F13) : de gauche à droite en
/// 1,6 s par un `ClipRect` à `clipper` au-dessus du `RepaintBoundary` des
/// séries ; le point de tête, sa valeur et l'annotation apparaissent ensuite.
const ({bool disabled, double speed}) _live = (disabled: false, speed: 1);
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

final Finder _reveal = find.byKey(const Key('trend-reveal'));
final Finder _head = find.byKey(const Key('trend-head'));

/// Fraction de la largeur que laisse voir le `ClipRect` du dévoilement.
double _visible(WidgetTester tester) {
  final RenderClipRect clip = tester.renderObject<RenderClipRect>(_reveal);
  return clip.clipper!.getClip(clip.size).width / clip.size.width;
}

/// Opacité rendue d'un élément : produit des opacités de ses ancêtres.
double _opacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  RenderObject? render = tester.renderObject(finder);
  while (render != null) {
    if (render is RenderOpacity) opacity *= render.opacity;
    if (render is RenderAnimatedOpacity) opacity *= render.opacity.value;
    render = render.parent;
  }
  return opacity;
}

Future<CatalogHarness> _start(
  WidgetTester tester, {
  ({bool disabled, double speed}) motion = _live,
}) async {
  final h = CatalogHarness('trend', 'trend');
  await h.pump(tester, motion: motion);
  await h.sendFixtureTo(tester, 3);
  return h;
}

void main() {
  testWidgets('le tracé se dévoile de gauche à droite en 1,6 s', (
    tester,
  ) async {
    await _start(tester);
    // `DsRise` fait apparaître la surface (480 ms) : le dévoilement part du
    // premier `data` et ne l\'attend pas.
    await tester.pump(const Duration(milliseconds: 200));
    final double early = _visible(tester);
    expect(early, inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 400));
    final double mid = _visible(tester);
    expect(mid, greaterThan(early));
    expect(mid, lessThan(1));

    await tester.pump(SceneMotion.wipe);
    expect(_visible(tester), 1);
  });

  testWidgets('le dévoilement est un ClipRect à clipper au-dessus du '
      'RepaintBoundary des séries ; la grille et l\'axe n\'en font pas '
      'partie', (tester) async {
    await _start(tester);
    final Finder paint = find.byKey(const Key('trend-chart-paint'));
    expect(
      find.descendant(of: _reveal, matching: paint),
      findsOneWidget,
      reason: 'les séries sont dans le dévoilement',
    );
    expect(
      find.descendant(of: _reveal, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
    expect(
      find.ancestor(of: paint, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
    final ClipRect clip = tester.widget<ClipRect>(_reveal);
    expect(clip.clipper, isNotNull);
    for (final String key in <String>['trend-grid', 'trend-axis']) {
      expect(
        find.descendant(of: _reveal, matching: find.byKey(Key(key))),
        findsNothing,
        reason: '« $key » est statique, hors du dévoilement',
      );
      expect(find.byKey(Key(key)), findsOneWidget);
    }
  });

  testWidgets('le point de tête, sa valeur et l\'annotation apparaissent '
      'après le tracé', (tester) async {
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    for (final String key in <String>[
      'trend-head',
      'trend-head-value',
      'trend-callout',
    ]) {
      expect(
        _opacity(tester, find.byKey(Key(key))),
        lessThan(0.05),
        reason: key,
      );
    }
    // Tracé presque fini (1,5 s) : la tête n\'est pas encore là.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(_visible(tester), greaterThan(0.9));
    expect(_opacity(tester, _head), lessThan(0.1));

    await tester.pump(const Duration(milliseconds: 700));
    for (final String key in <String>[
      'trend-head',
      'trend-head-value',
      'trend-callout',
    ]) {
      expect(
        _opacity(tester, find.byKey(Key(key))),
        greaterThanOrEqualTo(0.99),
        reason: key,
      );
    }
    // Tracé fini : seule boucle restante, l'anneau de tête (`gc-ring`,
    // pdr-0088 F9, T34).
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('animations coupées : état final aussitôt, aucun Ticker', (
    tester,
  ) async {
    await _start(tester, motion: _still);
    expect(_visible(tester), 1);
    expect(_opacity(tester, _head), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('animations coupées en cours de route : état final aussitôt', (
    tester,
  ) async {
    final h = await _start(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_visible(tester), lessThan(1));
    await h.pump(tester, motion: _still);
    await tester.pump();
    expect(_visible(tester), 1);
    expect(_opacity(tester, _head), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('rejeu à 2 x : le tracé est fini en moitié moins de temps', (
    tester,
  ) async {
    await _start(tester, motion: (disabled: false, speed: 2));
    await tester.pump(SceneMotion.wipe ~/ 2);
    expect(_visible(tester), 1);
  });

  testWidgets('la mutation de l\'acte 2 rejoue le dévoilement', (tester) async {
    final h = await _start(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_visible(tester), 1);

    await h.sendVariant(tester, 'act2');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_visible(tester), lessThan(1));
    expect(_opacity(tester, _head), lessThan(0.05));

    await tester.pump(const Duration(seconds: 3));
    expect(_visible(tester), 1);
    expect(_opacity(tester, _head), 1);
  });

  testWidgets('une mise à jour qui garde les mêmes séries ne rejoue rien', (
    tester,
  ) async {
    final h = await _start(tester);
    await tester.pump(const Duration(seconds: 3));
    await h.sendData(tester, cloneJson(h.data)..['title'] = 'Autre titre');
    expect(find.text('Autre titre'), findsOneWidget);
    expect(_visible(tester), 1);
    expect(_opacity(tester, _head), 1);
    // Rien ne rejoue ; l'anneau de tête (T34) est la seule boucle.
    expect(tester.binding.transientCallbackCount, 1);
  });
}
