import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Décoration de panneau du design system (pdr-0084 U1, U9) : couche
/// décorative statique, sœur du contenu.
const SceneTheme _theme = SceneTheme.dark();

Widget _host(Widget child, {Size size = const Size(400, 300)}) => MaterialApp(
  theme: ThemeData(extensions: const [_theme]),
  home: Center(
    child: SizedBox.fromSize(size: size, child: child),
  ),
);

Finder get _decoration => find.byType(ScenePanelDecoration);

BoxDecoration _box(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: _decoration,
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

CustomPaint _painted(WidgetTester tester) => tester.widget<CustomPaint>(
  find.descendant(of: _decoration, matching: find.byType(CustomPaint)),
);

TestRecordingCanvas _record(WidgetTester tester, Size size) {
  final canvas = TestRecordingCanvas();
  _painted(tester).painter!.paint(canvas, size);
  return canvas;
}

void main() {
  testWidgets('dégradé, bordure, rayon et ombre viennent des jetons', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ScenePanel(child: SizedBox.expand())));
    final BoxDecoration d = _box(tester);
    final gradient = d.gradient! as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.colors, <Color>[_theme.panelTop, _theme.surface]);
    expect(d.border, Border.all(color: _theme.line));
    expect(d.borderRadius, BorderRadius.circular(SceneRadius.lg));
    expect(d.boxShadow, SceneShadow.panel);
  });

  testWidgets('filet panelHighlight en haut et quatre traits lineStrong', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ScenePanel(child: SizedBox.expand())));
    final canvas = _record(tester, const Size(392, 292));

    final List<Paint> drawn = <Paint>[
      for (final i in canvas.invocations)
        if (i.invocation.positionalArguments.whereType<Paint>().isNotEmpty)
          i.invocation.positionalArguments.whereType<Paint>().first,
    ];
    expect(
      drawn.where(
        (p) => p.color.toARGB32() == _theme.panelHighlight.toARGB32(),
      ),
      isNotEmpty,
      reason: 'le filet du haut est peint',
    );

    // Coins HUD : deux L (haut gauche, bas droite), soit quatre traits.
    final Iterable<RecordedInvocation> strokes = canvas.invocations.where(
      (i) =>
          i.invocation.memberName == #drawRect &&
          (i.invocation.positionalArguments[1] as Paint).color.toARGB32() ==
              _theme.lineStrong.withValues(alpha: 0.8).toARGB32(),
    );
    final List<Rect> rects = [
      for (final i in strokes) i.invocation.positionalArguments[0] as Rect,
    ];
    expect(rects, hasLength(4));
    expect(rects, contains(const Rect.fromLTWH(8, 8, 10, 1)));
    expect(rects, contains(const Rect.fromLTWH(8, 8, 1, 10)));
    expect(rects, contains(const Rect.fromLTRB(374, 283, 384, 284)));
    expect(rects, contains(const Rect.fromLTRB(383, 274, 384, 284)));
  });

  testWidgets(
    'enfant : marge 24 × 20 du design system ; décoration : largeur - 2 x inset',
    (tester) async {
      await tester.pumpWidget(
        _host(const ScenePanel(child: SizedBox.expand(key: Key('c')))),
      );
      // Défauts : padding 24 horizontal × 20 vertical (`.gc-panel`), inset 4.
      expect(tester.getSize(find.byKey(const Key('c'))), const Size(352, 260));
      expect(
        tester.getTopLeft(find.byKey(const Key('c'))) -
            tester.getTopLeft(find.byType(ScenePanel)),
        const Offset(24, 20),
      );
      expect(tester.getSize(_decoration), const Size(392, 292));
      expect(
        tester.getTopLeft(_decoration) -
            tester.getTopLeft(find.byType(ScenePanel)),
        const Offset(4, 4),
      );
    },
  );

  testWidgets('padding et inset sont paramétrables', (tester) async {
    await tester.pumpWidget(
      _host(
        const ScenePanel(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          inset: 0,
          child: SizedBox.expand(key: Key('c')),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('c'))), const Size(384, 292));
    expect(tester.getSize(_decoration), const Size(400, 300));
  });

  testWidgets('RepaintBoundary propre, aucun clip au-dessus de la décoration', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ScenePanel(child: SizedBox.expand())));
    // La décoration porte son propre RepaintBoundary, à sa racine.
    expect(
      find.descendant(of: _decoration, matching: find.byType(RepaintBoundary)),
      findsOneWidget,
    );
    for (final Type clip in <Type>[ClipRect, ClipRRect, ClipPath, ClipOval]) {
      expect(
        find.descendant(
          of: find.byType(ScenePanel),
          matching: find.byType(clip),
        ),
        findsNothing,
        reason: '$clip rognerait l\'ombre',
      );
    }
  });

  testWidgets('la décoration ne se repeint pas quand seul le contenu change', (
    tester,
  ) async {
    final ValueNotifier<int> tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    await tester.pumpWidget(
      _host(
        ScenePanel(
          child: CustomPaint(painter: _TickPainter(tick), size: Size.infinite),
        ),
      ),
    );
    final RenderRepaintBoundary decoBoundary = tester.renderObject(
      find.descendant(of: _decoration, matching: find.byType(RepaintBoundary)),
    );
    final RenderObject content = tester.renderObject(
      find.descendant(
        of: find.byType(ScenePanel),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is _TickPainter,
        ),
      ),
    );
    tick.value++;
    expect(content.debugNeedsPaint, isTrue);
    expect(decoBoundary.debugNeedsPaint, isFalse);
  });

  testWidgets('glow : absent par défaut, ajouté à l\'ombre quand fourni', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ScenePanel(child: SizedBox.expand())));
    expect(_box(tester).boxShadow, SceneShadow.panel);

    await tester.pumpWidget(
      _host(
        const ScenePanel(
          glow: SceneShadow.glowSignal,
          child: SizedBox.expand(),
        ),
      ),
    );
    expect(_box(tester).boxShadow, <BoxShadow>[
      ...SceneShadow.panel,
      ...SceneShadow.glowSignal,
    ]);
  });
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.tick) : super(repaint: tick);
  final ValueNotifier<int> tick;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_TickPainter old) => false;
}
