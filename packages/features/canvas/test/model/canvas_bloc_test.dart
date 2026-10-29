import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart'
    show BasicCatalogItems, Catalog, SurfaceController;

import '../support/bloc_harness.dart';
import '../support/messages.dart';

void main() {
  late SurfaceController controller;
  late CanvasBloc bloc;

  setUp(() {
    controller = SurfaceController(
      catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
    );
    bloc = CanvasBloc(controller);
  });
  tearDown(() => controller.dispose());

  test("l'état initial est un canevas vide", () async {
    expect(bloc.state.surfaceIds, isEmpty);
    await bloc.close();
  });

  test('A2uiMessageReceived applique createSurface, updateComponents puis updateDataModel', () async {
    final states = await statesAfter(bloc, (b) {
      b
        ..add(A2uiMessageReceived(createSurface('s')))
        ..add(A2uiMessageReceived(updateBoundComponents('s', '/kpi/label')))
        ..add(
          A2uiMessageReceived(
            updateDataModel('s', '/kpi/label', 'Sessions sans crash'),
          ),
        );
    });

    expect(states.map((s) => s.phaseOf('s')), <SurfacePhase>[
      SurfacePhase.skeleton,
      SurfacePhase.components,
      SurfacePhase.data,
    ]);
    expect(controller.activeSurfaceIds, <String>['s']);
  });

  test("A2uiMessageReceived deleteSurface retire la surface du moteur et de l'état", () async {
    final states = await statesAfter(bloc, (b) {
      b
        ..add(A2uiMessageReceived(createSurface('s')))
        ..add(A2uiMessageReceived(deleteSurface('s')));
    });

    expect(states.map((s) => s.surfaceIds), <List<String>>[
      <String>['s'],
      <String>[],
    ]);
    expect(controller.activeSurfaceIds, isEmpty);
  });

  test(
    'CanvasResetRequested vide le canevas et supprime les surfaces du moteur',
    () async {
      final states = await statesAfter(bloc, (b) {
        b
          ..add(A2uiMessageReceived(createSurface('a')))
          ..add(A2uiMessageReceived(createSurface('b')))
          ..add(const CanvasResetRequested());
      });

      expect(states.last.surfaceIds, isEmpty);
      expect(controller.activeSurfaceIds, isEmpty);
    },
  );

  group('CanvasSourceSubscribed', () {
    test('flux terminé : playing puis completed, messages appliqués', () async {
      final source = StreamController<A2uiMessage>();
      final states = await statesAfter(bloc, (b) async {
        b.add(CanvasSourceSubscribed(source.stream));
        await Future<void>.delayed(Duration.zero);
        source.add(createSurface('s'));
        await source.close();
        await Future<void>.delayed(Duration.zero);
      });

      expect(states.map((s) => s.sourceStatus), <CanvasSourceStatus>[
        CanvasSourceStatus.playing,
        CanvasSourceStatus.playing,
        CanvasSourceStatus.completed,
      ]);
      expect(states.last.surfaceIds, <String>['s']);
    });

    test('erreur du flux : failed avec le message', () async {
      final source = StreamController<A2uiMessage>();
      final states = await statesAfter(bloc, (b) async {
        b.add(CanvasSourceSubscribed(source.stream));
        await Future<void>.delayed(Duration.zero);
        source.addError(StateError('boum'));
        await source.close();
        await Future<void>.delayed(Duration.zero);
      });

      expect(states.last.sourceStatus, CanvasSourceStatus.failed);
      expect(states.last.sourceError, contains('boum'));
      expect(
        states.map((s) => s.sourceStatus),
        isNot(contains(CanvasSourceStatus.completed)),
      );
    });

    test("close() pendant le flux annule l'abonnement", () async {
      var cancelled = false;
      final source = StreamController<A2uiMessage>(
        onCancel: () => cancelled = true,
      );
      bloc.add(CanvasSourceSubscribed(source.stream));
      await Future<void>.delayed(Duration.zero);

      await bloc.close();

      expect(cancelled, isTrue);
      expect(bloc.state.sourceStatus, CanvasSourceStatus.playing);
    });
  });
}
