import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;
import 'package:genui/genui.dart'
    show BasicCatalogItems, Catalog, Surface, SurfaceController;

import '../support/messages.dart';

void main() {
  late SurfaceController controller;
  late CanvasBloc bloc;

  /// Construit le moteur et le Bloc dans la zone du test : un Bloc créé dans
  /// `setUp` vit hors de la zone `FakeAsync` et `pump` ne vide pas ses flux.
  void createEngine() {
    controller = SurfaceController(
      catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
    );
    bloc = CanvasBloc(controller);
    addTearDown(() async {
      await bloc.close();
      controller.dispose();
    });
  }

  Future<void> pumpBoard(WidgetTester tester, {String? highlightedSurfaceId}) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BlocProvider<CanvasBloc>.value(
            value: bloc,
            child: CanvasBoard(
              key: const Key('canvas-board'),
              controller: controller,
              highlightedSurfaceId: highlightedSurfaceId,
            ),
          ),
        ),
      );

  /// Les events du Bloc sont traités en différé : on laisse passer quelques
  /// cadres pour que chaque état émis soit rendu.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  testWidgets('sans surface, le canevas est vide', (tester) async {
    createEngine();
    await pumpBoard(tester);

    expect(find.byKey(const Key('canvas-board')), findsOneWidget);
    expect(find.byType(Surface), findsNothing);
  });

  testWidgets('une surface créée par messages v0.9 affiche sa valeur liée', (
    tester,
  ) async {
    createEngine();
    await pumpBoard(tester);

    bloc
      ..add(A2uiMessageReceived(createSurface('kpi')))
      ..add(A2uiMessageReceived(updateBoundComponents('kpi', '/label')))
      ..add(
        A2uiMessageReceived(
          updateDataModel('kpi', '/label', 'Sessions sans crash'),
        ),
      );
    await settle(tester);

    expect(find.byType(Surface), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Surface),
        matching: find.text('Sessions sans crash'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('la cellule existe dès createSurface et peint le squelette', (
    tester,
  ) async {
    createEngine();
    await pumpBoard(tester);

    bloc.add(A2uiMessageReceived(createSurface('kpi')));
    await settle(tester);

    expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('surface-kpi')),
        matching: find.byKey(const Key('skeleton-kpi')),
      ),
      findsOneWidget,
    );
    expect(find.byType(Surface), findsNothing);
  });

  testWidgets('Surface est montée dès updateComponents et le squelette part', (
    tester,
  ) async {
    createEngine();
    await pumpBoard(tester);
    bloc.add(A2uiMessageReceived(createSurface('kpi')));
    await settle(tester);

    bloc.add(A2uiMessageReceived(updateComponents('kpi', 'Bonjour')));
    await settle(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('surface-kpi')),
        matching: find.byType(Surface),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('skeleton-kpi')), findsNothing);
  });

  testWidgets('une surface supprimée disparaît du canevas', (tester) async {
    createEngine();
    await pumpBoard(tester);
    bloc
      ..add(A2uiMessageReceived(createSurface('kpi')))
      ..add(A2uiMessageReceived(updateComponents('kpi', 'Bonjour')));
    await settle(tester);
    expect(find.text('Bonjour'), findsOneWidget);

    bloc.add(A2uiMessageReceived(deleteSurface('kpi')));
    await settle(tester);

    expect(find.byType(Surface), findsNothing);
  });

  testWidgets(
    'quatre surfaces : grille 2 × 2 de cellules égales, dans l\'ordre '
    'd\'arrivée',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      createEngine();
      await pumpBoard(tester);

      for (final String id in <String>[
        'kpi',
        'trend',
        'reviews',
        'checklist',
      ]) {
        bloc.add(A2uiMessageReceived(createSurface(id)));
      }
      await settle(tester);

      Rect cell(String id) => tester.getRect(find.byKey(Key('surface-$id')));
      final Rect kpi = cell('kpi');
      final Rect trend = cell('trend');
      final Rect reviews = cell('reviews');
      final Rect checklist = cell('checklist');
      expect(kpi.size, trend.size);
      expect(kpi.size, reviews.size);
      expect(kpi.size, checklist.size);
      expect(kpi.width, 960);
      expect(kpi.height, 260);
      expect(trend.topLeft, kpi.topRight);
      expect(reviews.topLeft, kpi.bottomLeft);
      expect(checklist.topLeft, kpi.bottomRight);
    },
  );

  testWidgets('une surface occupe toute la largeur ; six surfaces : 3 × 2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    createEngine();
    await pumpBoard(tester);

    bloc.add(A2uiMessageReceived(createSurface('a')));
    await settle(tester);
    expect(tester.getSize(find.byKey(const Key('surface-a'))).width, 1800);

    for (final String id in <String>['b', 'c', 'd', 'e', 'f']) {
      bloc.add(A2uiMessageReceived(createSurface(id)));
    }
    await settle(tester);
    final Rect a = tester.getRect(find.byKey(const Key('surface-a')));
    expect(a.size, const Size(600, 300));
    expect(
      tester.getRect(find.byKey(const Key('surface-d'))).topLeft,
      a.bottomLeft,
    );
  });

  testWidgets(
    'emplacement déterministe : kpi, trend, reviews, checklist quel que soit '
    'l\'ordre d\'arrivée, les surfaces inconnues ensuite',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      createEngine();
      await pumpBoard(tester);

      for (final String id in <String>[
        'inconnue',
        'checklist',
        'reviews',
        'trend',
        'kpi',
      ]) {
        bloc.add(A2uiMessageReceived(createSurface(id)));
      }
      await settle(tester);

      Rect cell(String id) => tester.getRect(find.byKey(Key('surface-$id')));
      // Cinq surfaces : 3 × 2, ordre du contrat puis surfaces inconnues.
      final Rect kpi = cell('kpi');
      expect(kpi.size, const Size(600, 300));
      expect(kpi.topLeft, Offset.zero);
      expect(cell('trend').topLeft, kpi.topRight);
      expect(cell('reviews').topLeft, cell('trend').topRight);
      expect(cell('checklist').topLeft, kpi.bottomLeft);
      expect(cell('inconnue').topLeft, cell('checklist').topRight);
    },
  );

  testWidgets(
    'quatre surfaces arrivées à l\'envers : kpi en haut à gauche, checklist '
    'en bas à droite',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      createEngine();
      await pumpBoard(tester);

      for (final String id in <String>[
        'checklist',
        'reviews',
        'trend',
        'kpi',
      ]) {
        bloc.add(A2uiMessageReceived(createSurface(id)));
      }
      await settle(tester);

      Rect cell(String id) => tester.getRect(find.byKey(Key('surface-$id')));
      expect(cell('kpi').topLeft, Offset.zero);
      expect(cell('trend').topLeft, cell('kpi').topRight);
      expect(cell('reviews').topLeft, cell('kpi').bottomLeft);
      expect(cell('checklist').topLeft, cell('kpi').bottomRight);
    },
  );

  group('contour pointillé de la surface mise en évidence (D2)', () {
    Future<void> createTwo(WidgetTester tester, {String? highlighted}) async {
      createEngine();
      await pumpBoard(tester, highlightedSurfaceId: highlighted);
      bloc
        ..add(A2uiMessageReceived(createSurface('kpi')))
        ..add(A2uiMessageReceived(createSurface('trend')))
        ..add(A2uiMessageReceived(updateComponents('trend', 'Bonjour')));
      await settle(tester);
    }

    testWidgets('sans surface en évidence, aucun contour', (tester) async {
      await createTwo(tester);

      expect(find.byKey(const Key('highlight-kpi')), findsNothing);
      expect(find.byKey(const Key('highlight-trend')), findsNothing);
    });

    testWidgets('le contour est posé sur la seule surface visée, dans sa '
        'cellule', (tester) async {
      await createTwo(tester, highlighted: 'trend');

      final Finder outline = find.byKey(const Key('highlight-trend'));
      expect(outline, findsOneWidget);
      expect(find.byKey(const Key('highlight-kpi')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('surface-trend')),
          matching: outline,
        ),
        findsOneWidget,
      );
      // Le tracé est un peintre de tirets, dans la couleur du thème de scène.
      final CustomPaint paint = tester.widget<CustomPaint>(outline);
      expect(paint.painter, isNotNull);
      expect(paint.painter.runtimeType.toString(), contains('Dashed'));
      // Plusieurs tirets (chemins disjoints), traits de la couleur du thème de
      // scène.
      final Color color = const SceneTheme.dark().highlightOutline;
      expect(
        tester.renderObject(outline),
        paints
          ..path(color: color, style: PaintingStyle.stroke)
          ..path(color: color, style: PaintingStyle.stroke)
          ..path(color: color, style: PaintingStyle.stroke),
      );
      expect(
        tester.getSize(outline),
        tester.getSize(find.byKey(const Key('surface-trend'))),
      );
    });

    testWidgets('le contour peut cercler un squelette', (tester) async {
      await createTwo(tester, highlighted: 'kpi');

      expect(
        find.descendant(
          of: find.byKey(const Key('surface-kpi')),
          matching: find.byKey(const Key('highlight-kpi')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('une surface absente (refusée) ne reçoit aucun contour', (
      tester,
    ) async {
      await createTwo(tester, highlighted: 'fantome');

      expect(find.byKey(const Key('highlight-fantome')), findsNothing);
      expect(find.byKey(const Key('highlight-kpi')), findsNothing);
      expect(find.byKey(const Key('highlight-trend')), findsNothing);
    });

    testWidgets('changer de surface en évidence ne remonte pas le moteur', (
      tester,
    ) async {
      await createTwo(tester, highlighted: 'kpi');
      final Element before = tester.element(find.byType(Surface));

      await pumpBoard(tester, highlightedSurfaceId: 'trend');
      await tester.pump();

      expect(find.byKey(const Key('highlight-kpi')), findsNothing);
      expect(find.byKey(const Key('highlight-trend')), findsOneWidget);
      expect(tester.element(find.byType(Surface)), same(before));
    });
  });
}
