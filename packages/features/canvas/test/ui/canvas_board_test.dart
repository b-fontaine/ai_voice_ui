import 'package:feature_canvas/api/canvas.dart';
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
}
