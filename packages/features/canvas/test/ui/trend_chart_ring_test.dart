import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/catalog_harness.dart';

/// Anneau de tête du graphique (`gc-ring`, 1,8 s, pdr-0088 F9) : un cercle
/// `signal` qui grossit de 1 à 3 en s'estompant de .9 à 0, en boucle, une
/// fois le tracé fini. Son propre `RepaintBoundary` ; invisible et sans
/// `Ticker` quand les animations sont coupées (phase de repos).
const ({bool disabled, double speed}) _live = (disabled: false, speed: 1);
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

final Finder _ring = find.byKey(const Key('trend-head-ring'));

Future<CatalogHarness> _start(
  WidgetTester tester, {
  ({bool disabled, double speed}) motion = _live,
}) async {
  final h = CatalogHarness('trend', 'trend');
  await h.pump(tester, motion: motion);
  await h.sendFixtureTo(tester, 3);
  return h;
}

/// Cercles que peint l'anneau : (rayon, opacité du trait, épaisseur).
List<({double radius, double alpha, double width})> _circles(
  WidgetTester tester,
) {
  final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
    find.descendant(
      of: _ring,
      matching: find.byType(CustomPaint),
      matchRoot: true,
    ),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  render.painter!.paint(canvas, const Size.square(10));
  return <({double radius, double alpha, double width})>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawCircle)
        (
          radius: call.invocation.positionalArguments[1] as double,
          alpha: (call.invocation.positionalArguments[2] as Paint).color.a,
          width: (call.invocation.positionalArguments[2] as Paint).strokeWidth,
        ),
  ];
}

int _paints(WidgetTester tester, Finder boundaryFinder) {
  final RenderRepaintBoundary boundary = tester.renderObject(boundaryFinder);
  return boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;
}

void main() {
  testWidgets('pas d\'anneau tant que le tracé n\'est pas fini', (
    tester,
  ) async {
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_circles(tester), isEmpty);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_circles(tester), isEmpty, reason: 'la tête monte encore');
  });

  testWidgets('une fois le tracé fini : le cercle grossit de 1 à 3 en 1,8 s et '
      's\'estompe de .9 à 0, puis recommence', (tester) async {
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(tester.binding.transientCallbackCount, 1);
    final first = _circles(tester).single;
    expect(first.radius, closeTo(5, 1.5), reason: 'départ : rayon 5');
    expect(first.alpha, closeTo(0.9, 0.15));

    await tester.pump(const Duration(milliseconds: 900));
    final mid = _circles(tester).single;
    expect(mid.radius, greaterThan(first.radius));
    expect(mid.alpha, lessThan(first.alpha));
    expect(mid.width, greaterThan(first.width), reason: 'le trait grossit');

    // Fin de période : l'anneau est presque invisible, puis il repart.
    await tester.pump(const Duration(milliseconds: 800));
    expect(_circles(tester).single.alpha, lessThan(0.2));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_circles(tester).single.alpha, greaterThan(0.5), reason: 'repart');
  });

  testWidgets('l\'anneau a son RepaintBoundary : le tracé ne se repeint pas', (
    tester,
  ) async {
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 2000));
    // Le boundary de l'anneau est dans l'anneau ; celui des séries est
    // au-dessus de leur dessin.
    final Finder ringBoundary = find
        .descendant(of: _ring, matching: find.byType(RepaintBoundary))
        .first;
    final Finder series = find
        .ancestor(
          of: find.byKey(const Key('trend-chart-paint')),
          matching: find.byType(RepaintBoundary),
        )
        .first;
    final int ringBefore = _paints(tester, ringBoundary);
    final int seriesBefore = _paints(tester, series);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_paints(tester, ringBoundary), greaterThan(ringBefore));
    expect(_paints(tester, series), seriesBefore);
  });

  testWidgets('animations coupées : anneau invisible, aucun Ticker', (
    tester,
  ) async {
    await _start(tester, motion: _still);
    expect(_circles(tester), isEmpty);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_circles(tester), isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('animations coupées en cours de route : l\'anneau s\'arrête', (
    tester,
  ) async {
    final h = await _start(tester);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(tester.binding.transientCallbackCount, 1);
    await h.pump(tester, motion: _still);
    await tester.pump();
    expect(_circles(tester), isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('la mutation de l\'acte 2 : l\'anneau s\'éteint pendant le '
      'tracé, puis revient', (tester) async {
    final h = await _start(tester);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(_circles(tester), isNotEmpty);

    await h.sendVariant(tester, 'act2');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_circles(tester), isEmpty);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(_circles(tester), isNotEmpty);
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('rejeu à 2 x : la période de l\'anneau est de 0,9 s', (
    tester,
  ) async {
    await _start(tester, motion: (disabled: false, speed: 2));
    await tester.pump(const Duration(milliseconds: 1200));
    // Instants (en ms) où le rayon retombe : début d'une nouvelle période.
    final List<int> wraps = <int>[];
    double? last;
    for (var t = 0; t <= 2400; t += 50) {
      final double radius = _circles(tester).single.radius;
      if (last != null && radius < last) wraps.add(t);
      last = radius;
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(wraps.length, greaterThanOrEqualTo(2));
    expect(wraps[1] - wraps[0], inInclusiveRange(850, 950));
  });
}
