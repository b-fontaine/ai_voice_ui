import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:entity_session/entity_session.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart';

/// Sonde genui 0.10.4 (feature 010, T05) : la remise à vide du canevas
/// (`CanvasResetRequested` = `deleteSurface` sur chaque surface), du validateur
/// (`A2uiGate.reset`) puis la réinjection des mêmes messages bruts redonnent le
/// même rendu, sans refus ni erreur du moteur. C'est le mécanisme du rejeu.

List<Map<String, Object?>> _act1() {
  var dir = Directory.current.absolute;
  while (!File(
    '${dir.path}/apps/genesis_canvas/assets/replays/act1-replay.jsonl',
  ).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('act1-replay.jsonl introuvable');
    }
    dir = parent;
  }
  return File(
        '${dir.path}/apps/genesis_canvas/assets/replays/act1-replay.jsonl',
      )
      .readAsLinesSync()
      .where((String l) => l.trim().isNotEmpty)
      .map(
        (String l) =>
            (jsonDecode(l) as Map<String, dynamic>)['message']
                as Map<String, Object?>,
      )
      .toList();
}

void main() {
  late SurfaceController controller;
  late CanvasBloc bloc;
  late A2uiGate gate;
  late StreamController<SessionEvent> input;
  late List<String> rejected;
  late List<String> engineErrors;
  late List<CanvasState> states;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  /// Tous les textes affichés (Text et RichText), dans l'ordre de l'arbre.
  List<String> shownTexts(WidgetTester tester) => <String>[
    for (final Element e in find.byType(RichText).evaluate())
      (e.widget as RichText).text.toPlainText(),
  ];

  Future<void> inject(
    WidgetTester tester,
    List<Map<String, Object?>> raws,
  ) async {
    for (final Map<String, Object?> raw in raws) {
      input.add(
        A2uiEnvelopeReceived(message: a2ui.A2uiMessage.fromJson(raw), raw: raw),
      );
      await settle(tester);
    }
  }

  testWidgets(
    'remise à vide puis réinjection de l\'acte 1, deux fois : même rendu, aucun refus',
    (tester) async {
      final List<Map<String, Object?>> messages = _act1();
      final List<String> expectedIds = <String>[
        'kpi',
        'trend',
        'reviews',
        'checklist',
      ];
      controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
      bloc = CanvasBloc(controller);
      input = StreamController<SessionEvent>.broadcast();
      rejected = <String>[];
      engineErrors = <String>[];
      states = <CanvasState>[];
      gate = A2uiGate(
        catalogId: GenesisContract.defaultCatalogId,
        onRejected: rejected.add,
      );
      final StreamSubscription<dynamic> errors = controller.onSubmit.listen(
        (m) => engineErrors.add(m.toString()),
      );
      final StreamSubscription<CanvasState> stateSub = bloc.stream.listen(
        states.add,
      );
      final StreamSubscription<a2ui.A2uiMessage> acceptedSub = gate.accepted
          .listen((m) => bloc.add(A2uiMessageReceived(m)));
      gate.attach(input.stream);
      addTearDown(() async {
        await errors.cancel();
        await stateSub.cancel();
        await acceptedSub.cancel();
        await gate.dispose();
        await input.close();
        await bloc.close();
        controller.dispose();
      });

      await tester.binding.setSurfaceSize(const Size(1800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
          ),
          home: Scaffold(
            body: BlocProvider<CanvasBloc>.value(
              value: bloc,
              child: CanvasBoard(controller: controller),
            ),
          ),
        ),
      );

      // Premier passage : référence.
      await inject(tester, messages);
      expect(bloc.state.surfaceIds, expectedIds);
      for (final String id in expectedIds) {
        expect(bloc.state.phaseOf(id), SurfacePhase.data, reason: id);
      }
      expect(find.byType(Surface), findsNWidgets(expectedIds.length));
      final List<String> reference = shownTexts(tester);
      expect(reference, contains('Sessions sans crash'));
      expect(reference, contains('99,57 %'));
      expect(rejected, isEmpty);
      expect(engineErrors, isEmpty);

      for (var round = 1; round <= 2; round++) {
        // Remise à vide : surfaces du moteur, puis validateur.
        bloc.add(const CanvasResetRequested());
        await settle(tester);
        gate.reset();
        expect(bloc.state.surfaceIds, isEmpty, reason: 'tour $round');
        expect(controller.activeSurfaceIds, isEmpty, reason: 'tour $round');
        expect(find.byType(Surface), findsNothing, reason: 'tour $round');

        states.clear();
        await inject(tester, messages);

        expect(bloc.state.surfaceIds, expectedIds, reason: 'tour $round');
        expect(controller.activeSurfaceIds, unorderedEquals(expectedIds));
        for (final String id in expectedIds) {
          expect(
            bloc.state.phaseOf(id),
            SurfacePhase.data,
            reason: '$id, tour $round',
          );
        }
        // Mêmes phases traversées : skeleton, components, data par surface.
        for (final String id in expectedIds) {
          expect(
            states.map((s) => s.phaseOf(id)).whereType<SurfacePhase>().toSet(),
            <SurfacePhase>{
              SurfacePhase.skeleton,
              SurfacePhase.components,
              SurfacePhase.data,
            },
            reason: '$id, tour $round',
          );
        }
        expect(find.byType(Surface), findsNWidgets(expectedIds.length));
        expect(shownTexts(tester), reference, reason: 'tour $round');
        expect(rejected, isEmpty, reason: 'tour $round');
        expect(engineErrors, isEmpty, reason: 'tour $round');
      }
    },
  );
}
