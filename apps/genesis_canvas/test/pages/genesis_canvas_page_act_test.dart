import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:feature_canvas/feature_canvas.dart'
    show ActionRequested, CanvasActionBloc;
import 'package:feature_stage_controls/feature_stage_controls.dart'
    show StageBloc;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show ReadContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart' show ReplayedMessage;

import '../support/page_rig.dart';

/// Avance automatique de l'indicateur d'acte (011, T24) : la page relie la
/// surface `actions` (acte 2) et l'action acceptée (acte 3) au `StageBloc`.
void main() {
  const play = Key('replay-play');
  const indicator = Key('act-indicator');

  Map<String, Object?> envelopeOf(Map<String, Object?> a2ui) =>
      <String, Object?>{
        'v': 1,
        'type': 'a2ui',
        'session': 's1',
        't_ms': 10,
        'data': <String, Object?>{'version': 'v0.9', ...a2ui},
      };

  Map<String, Object?> createSurface(String id) => envelopeOf(<String, Object?>{
    'createSurface': <String, Object?>{
      'surfaceId': id,
      'catalogId': rigCatalog,
    },
  });

  Map<String, Object?> updateData(String id) => envelopeOf(<String, Object?>{
    'updateDataModel': <String, Object?>{
      'surfaceId': id,
      'path': '/x',
      'value': 1,
    },
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> emit(
    WidgetTester tester,
    PageRig rig,
    Map<String, Object?> envelope,
  ) async {
    rig.receiveEnvelope(envelope);
    await settle(tester);
  }

  int act(PageRig rig) => rig.context.read<StageBloc>().state.act;

  Future<PageRig> mountLive(WidgetTester tester) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    return rig;
  }

  void click(PageRig rig) => rig.context.read<CanvasActionBloc>().add(
    ActionRequested(GenesisContract.actionIds.first, 'actions'),
  );

  testWidgets('l\'acte 2 arrive avec la surface actions, pas avant', (
    tester,
  ) async {
    final rig = await mountLive(tester);
    await emit(tester, rig, createSurface('kpi'));
    await emit(tester, rig, createSurface('checklist'));
    expect(act(rig), 1);
    // Une mise à jour de données d'une surface existante ne change rien.
    await emit(tester, rig, updateData('kpi'));
    expect(act(rig), 1);

    await emit(tester, rig, createSurface('actions'));
    expect(act(rig), 2);
    expect(
      find.descendant(
        of: find.byKey(indicator),
        matching: find.textContaining('Acte 2/3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'un clic accepté passe à l\'acte 3, et l\'acte ne recule jamais',
    (tester) async {
      final rig = await mountLive(tester);
      await emit(tester, rig, createSurface('actions'));
      expect(act(rig), 2);

      click(rig);
      await settle(tester);
      expect(act(rig), 3);

      // Une nouvelle surface ou une mise à jour ne fait pas reculer.
      await emit(tester, rig, updateData('actions'));
      await emit(tester, rig, createSurface('kpi'));
      expect(act(rig), 3);
    },
  );

  testWidgets('un clic sans surface actions saute à l\'acte 3', (tester) async {
    final rig = await mountLive(tester);
    expect(act(rig), 1);
    click(rig);
    await settle(tester);
    expect(act(rig), 3);
  });

  testWidgets('le clic manuel corrige l\'acte, sans que la surface '
      'existante le refasse avancer', (tester) async {
    final rig = await mountLive(tester);
    await emit(tester, rig, createSurface('actions'));
    expect(act(rig), 2);

    await tester.tap(find.byKey(indicator));
    await settle(tester);
    expect(act(rig), 3);
    await tester.tap(find.byKey(indicator));
    await settle(tester);
    expect(act(rig), 1);

    await emit(tester, rig, createSurface('actions'));
    expect(
      act(rig),
      1,
      reason: 'la surface existe déjà : pas de nouvelle apparition',
    );
  });

  testWidgets('après remise à vide, l\'acte repart de 1 sans rejouer', (
    tester,
  ) async {
    final rig = await mountLive(tester);
    await emit(tester, rig, createSurface('actions'));
    click(rig);
    await settle(tester);
    expect(act(rig), 3);

    await tester.tap(find.byKey(const Key('reset-button')));
    await settle(tester);
    expect(act(rig), 1);
    await tester.pump(const Duration(seconds: 1));
    expect(act(rig), 1);

    await emit(tester, rig, createSurface('actions'));
    expect(act(rig), 2);
  });

  testWidgets('en mode scénario, la surface actions ne touche pas l\'acte', (
    tester,
  ) async {
    final rig = PageRig(tester);
    final messages = StreamController<ReplayedMessage>();
    addTearDown(messages.close);
    await rig.mount(tester, replay: messages.stream, themed: true);
    final raw = Map<String, Object?>.from(
      createSurface('actions')['data']! as Map,
    );
    messages.add((raw: raw, message: A2uiMessage.fromJson(raw)));
    await settle(tester);
    expect(find.byKey(const Key('surface-actions')), findsOneWidget);
    expect(act(rig), 1);
  });

  testWidgets('pendant le rejeu, la réinjection de actions n\'avance pas '
      'l\'acte', (tester) async {
    final rig = await mountLive(tester);
    await emit(tester, rig, createSurface('actions'));
    expect(act(rig), 2);
    // Correction manuelle vers l'acte 1 (2 → 3 → 1).
    await tester.tap(find.byKey(indicator));
    await settle(tester);
    await tester.tap(find.byKey(indicator));
    await settle(tester);
    expect(act(rig), 1);

    await tester.tap(find.byKey(play));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Acte 4 · Rejeu'), findsOneWidget);
    expect(act(rig), 1);
  });
}
