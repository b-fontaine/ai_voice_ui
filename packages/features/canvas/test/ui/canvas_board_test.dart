import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<void> pumpBoard(WidgetTester tester) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: BlocProvider<CanvasBloc>.value(
        value: bloc,
        child: CanvasBoard(
          key: const Key('canvas-board'),
          controller: controller,
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
}
