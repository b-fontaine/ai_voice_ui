import 'package:feature_canvas/feature_canvas.dart';
import 'package:feature_canvas/src/ui/dashed_outline_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart'
    show BasicCatalogItems, Catalog, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart';

import '../support/messages.dart';

/// Couche panneau du canevas (017 T18, pdr-0084 U1 et U9) : chaque cellule
/// porte une `ScenePanelDecoration` sœur, sous le contenu animé, sans changer
/// un rectangle de 013 (D-01, D-07, S-02) ni repeindre les voisines (NFR-04).
void main() {
  const SceneTheme theme = SceneTheme.dark();
  late SurfaceController controller;
  late CanvasBloc bloc;
  late ValueNotifier<String?> highlight;

  /// Canevas de 013 : 1872 × 676 (deux rangées de 302 et le bandeau de 72).
  Future<void> pumpBoard(WidgetTester tester, {bool animations = false}) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1872, 676);
    addTearDown(tester.view.reset);
    controller = SurfaceController(
      catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
    );
    bloc = CanvasBloc(controller);
    highlight = ValueNotifier<String?>(null);
    addTearDown(() async {
      await bloc.close();
      controller.dispose();
      highlight.dispose();
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: const <ThemeExtension<dynamic>>[theme]),
          child: SceneMotionScope(
            disabled: !animations,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1872,
                height: 676,
                child: BlocProvider<CanvasBloc>.value(
                  value: bloc,
                  child: CanvasBoard(
                    key: const Key('canvas-board'),
                    controller: controller,
                    highlight: highlight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> send(WidgetTester tester, Iterable<Object> messages) async {
    for (final Object m in messages) {
      bloc.add(A2uiMessageReceived(m as dynamic));
    }
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Finder cell(String id) => find.byKey(ValueKey<String>('surface-$id'));
  Finder decorationOf(String id) => find.descendant(
    of: cell(id),
    matching: find.byType(ScenePanelDecoration),
  );

  int decorationPaints(WidgetTester tester, String id) {
    final Finder boundary = find.descendant(
      of: decorationOf(id),
      matching: find.byType(RepaintBoundary),
    );
    return (tester.renderObject(
      boundary.first,
    ) as RenderRepaintBoundary).debugSymmetricPaintCount;
  }

  group('couche panneau', () {
    testWidgets('chaque cellule a une décoration sœur, entre le fond et le '
        'contenu, sans Clip ancêtre', (tester) async {
      await pumpBoard(tester);
      await send(tester, <Object>[
        createSurface('kpi'),
        createSurface('trend'),
        updateComponents('kpi', 'A'),
      ]);

      for (final String id in <String>['kpi', 'trend']) {
        expect(decorationOf(id), findsOneWidget, reason: 'surface-$id');
        for (final Type clip in <Type>[ClipRect, ClipRRect, ClipPath]) {
          expect(
            find.ancestor(of: decorationOf(id), matching: find.byType(clip)),
            findsNothing,
            reason: 'l\'ombre ne doit jamais être rognée ($clip)',
          );
        }
        // Ordre du Stack : décoration, contenu animé, contour de surbrillance.
        final Stack stack = tester.widget<Stack>(
          find.descendant(of: cell(id), matching: find.byType(Stack)).first,
        );
        expect(stack.children, hasLength(3));
        final Widget first = stack.children[0];
        expect(first, isA<Positioned>());
        expect(
          (first as Positioned).child,
          isA<ScenePanelDecoration>(),
          reason: 'la décoration est sous le contenu',
        );
        expect(stack.children[1], isA<RepaintBoundary>());
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>('surface-content-$id')),
            matching: find.byType(ClipRect),
          ),
          findsOneWidget,
          reason: 'le ClipRect reste au-dessus du RepaintBoundary du contenu',
        );
        expect(
          find.descendant(
            of: decorationOf(id),
            matching: find.byType(RepaintBoundary),
          ),
          findsAtLeastNWidgets(1),
        );
      }
    });

    testWidgets('la décoration est en retrait de 4 px dans sa cellule, qui '
        'garde son rectangle (D-01 : 936 x 302 en 2 x 2)', (tester) async {
      await pumpBoard(tester);
      await send(tester, <Object>[
        createSurface('kpi'),
        createSurface('trend'),
        createSurface('reviews'),
        createSurface('checklist'),
        createSurface('actions'),
      ]);

      expect(tester.getRect(cell('kpi')), const Rect.fromLTWH(0, 0, 936, 302));
      expect(
        tester.getRect(cell('trend')),
        const Rect.fromLTWH(936, 0, 936, 302),
      );
      expect(
        tester.getRect(cell('reviews')),
        const Rect.fromLTWH(0, 302, 936, 302),
      );
      expect(
        tester.getRect(cell('checklist')),
        const Rect.fromLTWH(936, 302, 936, 302),
      );
      expect(
        tester.getRect(cell('actions')),
        const Rect.fromLTWH(0, 604, 1872, 72),
      );
      for (final String id in <String>[
        'kpi',
        'trend',
        'reviews',
        'checklist',
      ]) {
        expect(
          tester.getRect(decorationOf(id)),
          tester.getRect(cell(id)).deflate(4),
          reason: 'décoration de surface-$id',
        );
      }
      // Écart visible entre deux panneaux voisins : 4 + 4 = 8 px.
      expect(
        tester.getRect(decorationOf('trend')).left -
            tester.getRect(decorationOf('kpi')).right,
        8,
      );
    });

    testWidgets('3 x 2 : cellules de 624 x 302, rectangles identiques '
        '(S-02)', (tester) async {
      await pumpBoard(tester);
      await send(tester, <Object>[
        createSurface('kpi'),
        createSurface('trend'),
        createSurface('reviews'),
        createSurface('checklist'),
        createSurface('crashes'),
        createSurface('actions'),
      ]);
      expect(tester.getRect(cell('kpi')), const Rect.fromLTWH(0, 0, 624, 302));
      expect(
        tester.getRect(cell('crashes')),
        const Rect.fromLTWH(624, 302, 624, 302),
      );
      expect(
        tester.getRect(decorationOf('crashes')),
        const Rect.fromLTWH(628, 306, 616, 294),
      );
    });

    testWidgets('la décoration ne se repaint ni à l\'arrivée d\'une voisine ni '
        'pendant l\'apparition du contenu', (tester) async {
      await pumpBoard(tester, animations: true);
      await send(tester, <Object>[
        createSurface('kpi'),
        createSurface('trend'),
        updateComponents('kpi', 'A'),
      ]);
      await tester.pump(const Duration(seconds: 1));
      final int kpi = decorationPaints(tester, 'kpi');
      final int trend = decorationPaints(tester, 'trend');

      await send(tester, <Object>[createSurface('reviews')]);
      expect(decorationPaints(tester, 'kpi'), kpi);
      expect(decorationPaints(tester, 'trend'), trend);

      // Le contenu de `trend` apparaît (fondu, translation) : il se repeint à
      // chaque image, pas la décoration.
      await send(tester, <Object>[updateComponents('trend', 'B')]);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(decorationPaints(tester, 'trend'), trend);
      expect(decorationPaints(tester, 'kpi'), kpi);
    });
  });

  group('contour de surbrillance', () {
    testWidgets('rayon 16, couleur highlightOutline, rectangle de la '
        'décoration', (tester) async {
      await pumpBoard(tester);
      await send(tester, <Object>[
        createSurface('kpi'),
        createSurface('trend'),
      ]);
      highlight.value = 'trend';
      await tester.pump();

      final Finder outline = find.byKey(const Key('highlight-trend'));
      expect(outline, findsOneWidget);
      final CustomPaint paint = tester.widget<CustomPaint>(outline);
      final DashedOutlinePainter painter =
          paint.painter! as DashedOutlinePainter;
      expect(painter.radius, SceneRadius.lg);
      expect(painter.radius, 16);
      expect(painter.color, theme.highlightOutline);
      expect(tester.getRect(outline), tester.getRect(decorationOf('trend')));
      expect(find.byKey(const Key('highlight-kpi')), findsNothing);
    });
  });
}
