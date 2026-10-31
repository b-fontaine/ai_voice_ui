import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart'
    show BasicCatalogItems, Catalog, SurfaceController;

import '../support/messages.dart';

/// Périmètre de reconstruction et de peinture du canevas (NFR-04, P6) : un
/// événement d'une surface ne reconstruit ni ne repeint les cellules voisines,
/// et la surbrillance ne reconstruit jamais le board.
void main() {
  late SurfaceController controller;
  late CanvasBloc bloc;
  late ValueNotifier<String?> highlight;

  /// Reconstructions comptées par cellule (éléments sous `slot-<id>`) ; la
  /// clé `board` compte celles du `BlocBuilder` de la grille.
  final Map<String, int> rebuilds = <String, int>{};

  void onRebuild(Element element, bool builtOnce) {
    if (element.widget is BlocBuilder<CanvasBloc, CanvasState>) {
      rebuilds['board'] = (rebuilds['board'] ?? 0) + 1;
    }
    element.visitAncestorElements((Element ancestor) {
      final Key? key = ancestor.widget.key;
      if (key is ValueKey<String> && key.value.startsWith('slot-')) {
        rebuilds[key.value] = (rebuilds[key.value] ?? 0) + 1;
        return false;
      }
      return true;
    });
  }

  setUp(() {
    rebuilds.clear();
    debugOnRebuildDirtyWidget = onRebuild;
    addTearDown(() => debugOnRebuildDirtyWidget = null);
  });

  Future<void> pumpBoard(WidgetTester tester) async {
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
        child: BlocProvider<CanvasBloc>.value(
          value: bloc,
          child: CanvasBoard(
            key: const Key('canvas-board'),
            controller: controller,
            highlight: highlight,
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> send(WidgetTester tester, Iterable<Object> messages) async {
    for (final Object m in messages) {
      bloc.add(A2uiMessageReceived(m as dynamic));
    }
    await settle(tester);
  }

  int paintsOf(WidgetTester tester, String id) {
    final Finder boundary = find
        .descendant(
          of: find.byKey(ValueKey<String>('slot-$id')),
          matching: find.byType(RepaintBoundary),
        )
        .first;
    return (tester.renderObject(
      boundary,
    ) as RenderRepaintBoundary).debugSymmetricPaintCount;
  }

  Future<void> threeSurfaces(WidgetTester tester) async {
    await pumpBoard(tester);
    await send(tester, <Object>[
      createSurface('kpi'),
      createSurface('trend'),
      createSurface('reviews'),
      updateComponents('kpi', 'A'),
    ]);
  }

  testWidgets('l\'arrivée d\'une surface ne reconstruit ni ne repeint les '
      'voisines', (tester) async {
    await threeSurfaces(tester);
    final int kpiPaints = paintsOf(tester, 'kpi');
    final int trendPaints = paintsOf(tester, 'trend');
    rebuilds.clear();

    await send(tester, <Object>[createSurface('checklist')]);

    expect(rebuilds['board'], isNonZero, reason: 'la grille change');
    expect(rebuilds['slot-kpi'], isNull);
    expect(rebuilds['slot-trend'], isNull);
    expect(rebuilds['slot-reviews'], isNull);
    expect(paintsOf(tester, 'kpi'), kpiPaints);
    expect(paintsOf(tester, 'trend'), trendPaints);
  });

  testWidgets('un changement de phase ne reconstruit que sa cellule', (
    tester,
  ) async {
    await threeSurfaces(tester);
    final int kpiPaints = paintsOf(tester, 'kpi');
    rebuilds.clear();

    await send(tester, <Object>[updateComponents('trend', 'B')]);

    expect(rebuilds['board'], isNull);
    expect(rebuilds['slot-trend'], isNonZero);
    expect(rebuilds['slot-kpi'], isNull);
    expect(rebuilds['slot-reviews'], isNull);
    expect(paintsOf(tester, 'kpi'), kpiPaints);
  });

  testWidgets('la surbrillance ne reconstruit que l\'ancienne et la nouvelle '
      'cellule, jamais le board', (tester) async {
    await threeSurfaces(tester);
    highlight.value = 'kpi';
    await tester.pump();
    final int reviewsPaints = paintsOf(tester, 'reviews');
    rebuilds.clear();

    highlight.value = 'trend';
    await tester.pump();

    expect(rebuilds['board'], isNull);
    expect(rebuilds['slot-kpi'], isNonZero);
    expect(rebuilds['slot-trend'], isNonZero);
    expect(rebuilds['slot-reviews'], isNull);
    expect(paintsOf(tester, 'reviews'), reviewsPaints);
    expect(find.byKey(const Key('highlight-kpi')), findsNothing);
    expect(find.byKey(const Key('highlight-trend')), findsOneWidget);
  });

  testWidgets('un message A2UI sans nouvelle surface ne reconstruit pas le '
      'board', (tester) async {
    await threeSurfaces(tester);
    rebuilds.clear();

    await send(tester, <Object>[updateDataModel('kpi', '/label', 'x')]);

    expect(rebuilds['board'], isNull);
  });

  testWidgets('chaque cellule a un RepaintBoundary à place fixe', (
    tester,
  ) async {
    await threeSurfaces(tester);
    final Element before = tester.element(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('surface-kpi')),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );

    await send(tester, <Object>[updateComponents('kpi', 'C')]);

    expect(
      tester.element(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('surface-kpi')),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      ),
      same(before),
    );
  });
}
