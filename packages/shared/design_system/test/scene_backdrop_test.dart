import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Fond d'écran du design system (pdr-0084 U9) : vide `void` et grille de
/// points `line` au pas de 24 px, peinte en un seul `drawPoints`.
Widget _host({Widget? child, Size size = const Size(1920, 1080)}) =>
    MaterialApp(
      theme: ThemeData(extensions: const [SceneTheme.dark()]),
      home: Center(
        child: SizedBox.fromSize(
          size: size,
          child: SceneBackdrop(child: child),
        ),
      ),
    );

CustomPaint _dots(WidgetTester tester) => tester.widget<CustomPaint>(
  find.descendant(
    of: find.byType(SceneBackdrop),
    matching: find.byType(CustomPaint),
  ),
);

TestRecordingCanvas _record(CustomPainter painter, Size size) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  return canvas;
}

void main() {
  testWidgets('un seul drawPoints couvre tout l\'écran, en couleur line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());

    final painter = _dots(tester).painter!;
    final canvas = _record(painter, const Size(1920, 1080));
    final calls = canvas.invocations
        .where((i) => i.invocation.memberName == #drawRawPoints)
        .toList();
    expect(calls, hasLength(1));

    final args = calls.single.invocation.positionalArguments;
    expect(args[0], ui.PointMode.points);
    final coords = args[1] as Float32List;
    // Points au centre de chaque tuile de 24 px : 80 colonnes x 45 lignes.
    expect(coords.length, 2 * 80 * 45);
    expect(coords[0], 12);
    expect(coords[1], 12);
    final paint = args[2] as Paint;
    expect(paint.color.toARGB32(), const SceneTheme.dark().line.toARGB32());
    expect(paint.strokeCap, StrokeCap.round);
    expect(paint.strokeWidth, inInclusiveRange(1, 2));
  });

  testWidgets('le fond est la couleur void du thème', (tester) async {
    await tester.pumpWidget(_host(size: const Size(200, 100)));
    final box = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(SceneBackdrop),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(box.color, const SceneTheme.dark().background);
  });

  testWidgets(
    'shouldRepaint : faux à l\'identique, vrai si la couleur change',
    (tester) async {
      await tester.pumpWidget(_host(size: const Size(200, 100)));
      final painter = _dots(tester).painter!;
      await tester.pumpWidget(_host(size: const Size(200, 100)));
      expect(_dots(tester).painter!.shouldRepaint(painter), isFalse);

      Widget themed(Color line) => MaterialApp(
        theme: ThemeData(
          extensions: [const SceneTheme.dark().copyWith(line: line)],
        ),
        home: const SizedBox(width: 200, height: 100, child: SceneBackdrop()),
      );
      await tester.pumpWidget(themed(const Color(0xFF111111)));
      final before = _dots(tester).painter!;
      await tester.pumpWidget(themed(const Color(0xFF222222)));
      await tester.pump(const Duration(seconds: 1));
      expect(_dots(tester).painter!.shouldRepaint(before), isTrue);
    },
  );

  testWidgets('la taille change : la grille suit (un seul drawRawPoints)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(size: const Size(240, 120)));
    final canvas = _record(_dots(tester).painter!, const Size(240, 120));
    final calls = canvas.invocations
        .where((i) => i.invocation.memberName == #drawRawPoints)
        .toList();
    expect(calls, hasLength(1));
    // 10 colonnes x 5 lignes.
    expect(
      (calls.single.invocation.positionalArguments[1] as Float32List).length,
      2 * 10 * 5,
    );
  });

  testWidgets('RepaintBoundary autour des points ; le contenu est au-dessus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(size: const Size(200, 100), child: const Text('contenu')),
    );
    expect(
      find.ancestor(
        of: find.byType(CustomPaint),
        matching: find.descendant(
          of: find.byType(SceneBackdrop),
          matching: find.byType(RepaintBoundary),
        ),
      ),
      findsWidgets,
    );
    expect(find.text('contenu'), findsOneWidget);
    // Le contenu est peint après la grille (au-dessus).
    final Offset dotsAt = tester.getTopLeft(
      find.descendant(
        of: find.byType(SceneBackdrop),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(dotsAt, tester.getTopLeft(find.byType(SceneBackdrop)));
  });
}
