import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Cadre de génération (`gc-gen`, 019 T32b, pdr-0088 F11) : arc tournant,
/// balayage, étiquette dans la cellule, `done` = dernier tour puis fondu.
const SceneTheme _theme = SceneTheme.dark();

Widget _host({
  bool disabled = false,
  double speed = 1,
  bool done = false,
  String? agent = 'Analyste',
  VoidCallback? onFinished,
  bool show = true,
  double width = 200,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Theme(
    data: ThemeData(extensions: const <ThemeExtension<dynamic>>[_theme]),
    child: SceneMotionScope(
      disabled: disabled,
      speed: speed,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 100,
          child: show
              ? DsGenFrame(
                  surfaceId: 'crashes',
                  agent: agent,
                  done: done,
                  onFinished: onFinished,
                  inset: 8,
                )
              : null,
        ),
      ),
    ),
  ),
);

Finder _frame() =>
    find.byKey(const ValueKey<String>('generation-frame-crashes'));
Finder _tag() =>
    find.byKey(const ValueKey<String>('generation-frame-crashes-tag'));

double _opacity(WidgetTester tester) {
  var opacity = 1.0;
  RenderObject? render = tester.renderObject(_frame());
  while (render != null) {
    if (render is RenderOpacity) opacity *= render.opacity;
    if (render is RenderAnimatedOpacity) opacity *= render.opacity.value;
    render = render.parent;
  }
  return opacity;
}

int _paints(WidgetTester tester) {
  final RenderRepaintBoundary boundary = tester.renderObject(_frame());
  return boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;
}

void main() {
  group('phases', () {
    test('en boucle : un seul temps, deux phases (2,8 s et 2,2 s)', () {
      final p = DsGenFrame.phasesAt(1 / 44, done: false);
      expect(p.spin, closeTo(0.25, 1e-9));
      expect(p.scan, closeTo(14 / 44, 1e-9));
      expect(p.opacity, 1);
      final q = DsGenFrame.phasesAt(1 / 22, done: false);
      expect(q.spin, closeTo(0.5, 1e-9));
      expect(q.scan, closeTo(14 / 22, 1e-9));
    });

    test('done : un tour, un balayage, puis fondu de 0,6 s', () {
      final total = (SceneMotion.spin + SceneMotion.fade).inMicroseconds
          .toDouble();
      double at(Duration d) => d.inMicroseconds / total;
      final mid = DsGenFrame.phasesAt(
        at(const Duration(milliseconds: 1400)),
        done: true,
      );
      expect(mid.spin, closeTo(0.5, 1e-9));
      expect(mid.scan, closeTo(1.4 / 2.2, 1e-9));
      expect(mid.opacity, 1);

      final fading = DsGenFrame.phasesAt(
        at(const Duration(milliseconds: 3100)),
        done: true,
      );
      expect(fading.spin, 1);
      expect(fading.scan, isNull, reason: 'le balayage a fini après 2,2 s');
      expect(fading.opacity, allOf(greaterThan(0.02), lessThan(0.98)));

      expect(DsGenFrame.phasesAt(1, done: true).opacity, 0);
    });
  });

  group('structure', () {
    testWidgets('clé sur le RepaintBoundary, fondu AU-DESSUS de la clé, '
        'étiquette dans la cellule en haut à droite', (tester) async {
      await tester.pumpWidget(_host(width: 400));
      expect(tester.renderObject(_frame()), isA<RenderRepaintBoundary>());
      expect(
        find.ancestor(
          of: _frame(),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Opacity || w is FadeTransition,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.getRect(_frame()), const Rect.fromLTWH(0, 0, 400, 100));

      final Rect cell = tester.getRect(_frame());
      final Rect pill = tester.getRect(_tag());
      expect(cell.contains(pill.topLeft), isTrue);
      expect(cell.contains(pill.bottomRight), isTrue);
      expect(pill.center.dx, greaterThan(cell.center.dx));
      expect(pill.top, lessThan(cell.top + 12));
      expect(pill.height, 22);
      expect(
        find.descendant(of: _tag(), matching: find.text('ANALYSTE · GÉNÈRE')),
        findsOneWidget,
      );
      await tester.pumpWidget(_host(disabled: true, width: 400));
    });

    testWidgets('sans agent : « génère » seul', (tester) async {
      await tester.pumpWidget(_host(agent: null));
      expect(
        find.descendant(of: _tag(), matching: find.text('GÉNÈRE')),
        findsOneWidget,
      );
      await tester.pumpWidget(_host(disabled: true, agent: null));
    });

    testWidgets('le cadre ne prend pas les clics', (tester) async {
      await tester.pumpWidget(_host());
      expect(
        find.ancestor(of: _frame(), matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      await tester.pumpWidget(_host(disabled: true));
    });
  });

  group('mouvement', () {
    testWidgets('un seul contrôleur tourne, le cadre se repeint', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      expect(tester.binding.transientCallbackCount, 1);
      final int before = _paints(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_paints(tester), greaterThan(before));
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(_host(disabled: true));
    });

    testWidgets('sous animations coupées : aucune boucle, cadre statique', (
      tester,
    ) async {
      await tester.pumpWidget(_host(disabled: true));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_frame(), findsOneWidget);
      expect(_opacity(tester), 1);
    });

    testWidgets('animations coupées en cours de route : la boucle s\'arrête', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(_host(disabled: true));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
      'done : dernier tour (2,8 s), fondu (0,6 s), puis `onFinished`',
      (tester) async {
        var finished = 0;
        await tester.pumpWidget(_host(onFinished: () => finished++));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(
          _host(done: true, onFinished: () => finished++),
        );
        await tester.pump(); // première image : le temps de la fin part de zéro

        await tester.pump(const Duration(seconds: 1));
        expect(_opacity(tester), 1);
        expect(tester.binding.transientCallbackCount, 1);
        final int before = _paints(tester);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_paints(tester), greaterThan(before), reason: 'encore animé');

        await tester.pump(const Duration(milliseconds: 2000));
        expect(_opacity(tester), allOf(greaterThan(0.02), lessThan(0.98)));
        expect(finished, 0);

        await tester.pump(const Duration(milliseconds: 800));
        expect(finished, 1);
        await tester.pumpWidget(_host(done: true, show: false));
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('done sous animations coupées : retiré sans fondu', (
      tester,
    ) async {
      var finished = 0;
      await tester.pumpWidget(
        _host(disabled: true, onFinished: () => finished++),
      );
      await tester.pumpWidget(
        _host(disabled: true, done: true, onFinished: () => finished++),
      );
      await tester.pump();
      expect(finished, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('la vitesse de rejeu raccourcit le fondu', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_host(speed: 2, onFinished: () => finished++));
      await tester.pumpWidget(
        _host(speed: 2, done: true, onFinished: () => finished++),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, 1);
      await tester.pumpWidget(_host(show: false));
    });
  });

  group('peinture', () {
    testWidgets('bordure de 2 px en arc dans le rectangle inset, rien à '
        'l\'intérieur', (tester) async {
      await tester.pumpWidget(_host(disabled: true));
      final RenderRepaintBoundary boundary = tester.renderObject(_frame());
      final ui.Image image = (await tester.runAsync(() => boundary.toImage()))!;
      final ByteData? data = await tester.runAsync<ByteData?>(
        () => image.toByteData(),
      );
      int alpha(int x, int y) => data!.getUint8((y * image.width + x) * 4 + 3);
      // Tête de l'arc vers 10 h 30 (80 à 88 % du tour depuis midi).
      expect(alpha(27, 8), greaterThan(150), reason: 'arc sur le bord haut');
      // Queue transparente, à l'opposé.
      expect(alpha(150, 92), lessThan(10), reason: 'queue de l\'arc');
      expect(alpha(100, 50), 0, reason: 'intérieur vide');
      // Hors du rectangle inset (marge de la cellule) : rien.
      expect(alpha(27, 1), 0);
    });
  });
}
