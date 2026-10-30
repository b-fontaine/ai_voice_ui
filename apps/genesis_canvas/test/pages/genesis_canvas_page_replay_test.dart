import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:entity_session/entity_session.dart' show A2uiJournal;
import 'package:feature_canvas/feature_canvas.dart'
    show ActionRequested, CanvasActionBloc, CanvasActionScope;
import 'package:feature_replay/feature_replay.dart'
    show ReplayActive, ReplayBloc, ReplayLive;
import 'package:flutter/material.dart' show ButtonStyleButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show ReadContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart';
import 'package:shared_core/shared_core.dart' show ReplayedMessage;

import '../support/page_rig.dart';

/// Câblage du journal de rejeu dans la page (010, T09a) : la page enregistre
/// les messages A2UI qui entrent dans le gate, sans changer le rendu.
void main() {
  /// Journal de la page montée (membre `@visibleForTesting` de son `State`).
  A2uiJournal journalOf(WidgetTester tester) =>
      (tester.state(find.byType(GenesisCanvasPage)) as dynamic).journal
          as A2uiJournal;

  Future<void> playEnvelopes(WidgetTester tester, PageRig rig) async {
    for (final envelope in await act1Envelopes(tester)) {
      rig.receiveEnvelope(envelope);
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('en direct, les messages A2UI sont enregistrés et rendus', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    expect(journalOf(tester).length, 0);

    await playEnvelopes(tester, rig);

    expect(journalOf(tester).length, 12);
    expect(journalOf(tester).hasCreateSurface, isTrue);
    expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
    expect(find.byKey(const Key('surface-checklist')), findsOneWidget);
    expect(find.text('4 / 6 utilisés'), findsOneWidget);
    expect(rig.errors.toString(), isEmpty);
  });

  testWidgets('la remise à vide vide aussi le journal', (tester) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    await playEnvelopes(tester, rig);
    expect(journalOf(tester).length, 12);

    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pump();
    await tester.pump();

    expect(journalOf(tester).length, 0);
    expect(find.byKey(const Key('surface-kpi')), findsNothing);
  });

  testWidgets('en mode scénario, le journal enregistre aussi', (tester) async {
    final rig = PageRig(tester);
    final messages = StreamController<ReplayedMessage>();
    addTearDown(messages.close);
    await rig.mount(tester, replay: messages.stream, themed: true);

    for (final envelope in await act1Envelopes(tester)) {
      if (envelope['type'] != 'a2ui') continue;
      final raw = Map<String, Object?>.from(envelope['data']! as Map);
      messages.add((raw: raw, message: A2uiMessage.fromJson(raw)));
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));

    expect(journalOf(tester).length, 12);
    expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
    expect(rig.errors.toString(), isEmpty);
  });

  const play = Key('replay-play');
  const direct = Key('replay-direct');

  bool enabled(WidgetTester tester, Key key) => tester
      .widget<ButtonStyleButton>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (Widget w) => w is ButtonStyleButton,
          ),
          matchRoot: true,
        ),
      )
      .enabled;

  Map<String, Object?> liveCreate(String surfaceId) => <String, Object?>{
    'v': 1,
    'type': 'a2ui',
    'session': 's1',
    't_ms': 10,
    'data': <String, Object?>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': surfaceId,
        'catalogId': rigCatalog,
      },
    },
  };

  Future<PageRig> mountInReplay(WidgetTester tester) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    await playEnvelopes(tester, rig);
    await tester.tap(find.byKey(play));
    await tester.pump();
    await tester.pump();
    expect(rig.context.read<ReplayBloc>().state, isA<ReplayActive>());
    // Le lecteur réinjecte après la barrière d'un tour de boucle (A1), puis
    // au pas de l'horloge : on laisse le rejeu aller à son terme.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    return rig;
  }

  group('isolation pendant le rejeu (T09c)', () {
    testWidgets('Démarrer et les actions du canevas sont coupés', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester, themed: true);
      await rig.start(tester);
      await playEnvelopes(tester, rig);
      // La session est active : on la referme pour exposer « Démarrer ».
      await tester.tap(find.byKey(const Key('stop-button')));
      await tester.pump();
      await tester.pump();
      await drain(tester);
      expect(enabled(tester, const Key('start-button')), isTrue);
      expect(
        tester
            .widget<CanvasActionScope>(find.byType(CanvasActionScope))
            .enabled,
        isTrue,
      );

      await tester.tap(find.byKey(play));
      await tester.pump();
      await tester.pump();

      expect(enabled(tester, const Key('start-button')), isFalse);
      expect(
        tester
            .widget<CanvasActionScope>(find.byType(CanvasActionScope))
            .enabled,
        isFalse,
      );

      await tester.tap(find.byKey(direct));
      await tester.pump();
      await tester.pump();
      expect(enabled(tester, const Key('start-button')), isTrue);
      expect(
        tester
            .widget<CanvasActionScope>(find.byType(CanvasActionScope))
            .enabled,
        isTrue,
      );
    });

    testWidgets('un message vivant et un deleteSurface écho ne sont ni rendus '
        'ni enregistrés', (tester) async {
      final rig = await mountInReplay(tester);
      final before = journalOf(tester).length;

      rig.receiveEnvelope(liveCreate('vivant'));
      rig.receiveEnvelope(<String, Object?>{
        ...liveCreate('kpi'),
        'data': <String, Object?>{
          'version': 'v0.9',
          'deleteSurface': <String, Object?>{'surfaceId': 'kpi'},
        },
      });
      await tester.pump();
      await tester.pump();

      expect(journalOf(tester).length, before);
      expect(find.byKey(const Key('surface-vivant')), findsNothing);
      expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets('Remettre à vide pendant le rejeu : Direct, aucun refus', (
      tester,
    ) async {
      final rig = await mountInReplay(tester);

      await tester.tap(find.byKey(const Key('reset-button')));
      await tester.pump();
      await tester.pump();

      expect(rig.context.read<ReplayBloc>().state, isA<ReplayLive>());
      expect(rig.resetClient.calls, 1);
      expect(find.byKey(const Key('surface-kpi')), findsNothing);
      expect(rig.errors.toString(), isNot(contains('refusé')));
      expect(rig.errors.toString(), isNot(contains('Rejeu :')));
    });
  });

  group('occupation relayée à ReplayBloc (T09c)', () {
    testWidgets('un agent au travail ou une action en cours rend Lecture '
        'inactif', (tester) async {
      final rig = PageRig(tester);
      await rig.mount(tester, themed: true);
      await rig.start(tester);
      final envelopes = await act1Envelopes(tester);
      final completed = envelopes
          .where(
            (e) =>
                e['type'] == 'agent.activity' &&
                (e['data']! as Map)['state'] == 'completed',
          )
          .toList();
      for (final envelope in envelopes.where((e) => !completed.contains(e))) {
        rig.receiveEnvelope(envelope);
        await tester.pump();
        await tester.pump();
      }
      expect(journalOf(tester).hasCreateSurface, isTrue);
      expect(enabled(tester, play), isFalse);

      for (final envelope in completed) {
        rig.receiveEnvelope(envelope);
        await tester.pump();
        await tester.pump();
      }
      expect(enabled(tester, play), isTrue);

      // Une action en cours (202 reçu, activité pas encore vue) bloque aussi.
      rig.context.read<CanvasActionBloc>().add(
        ActionRequested(GenesisContract.actionIds.first, 'actions'),
      );
      await tester.pump();
      await tester.pump();
      expect(enabled(tester, play), isFalse);

      // Au bout de la durée maximale, les boutons et Lecture reviennent.
      await tester.pump(rig.settings.canvasActionMaxDuration);
      await tester.pump();
      expect(enabled(tester, play), isTrue);
    });
  });

  group('messages vivants écartés (T09c)', () {
    testWidgets('aucun message écarté : rien n\'est écrit à la sortie', (
      tester,
    ) async {
      final rig = await mountInReplay(tester);

      await tester.tap(find.byKey(direct));
      await tester.pump();
      await tester.pump();

      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets('n messages écartés : une seule ligne, le nombre seul', (
      tester,
    ) async {
      final rig = await mountInReplay(tester);
      rig.receiveEnvelope(liveCreate('secret-un'));
      rig.receiveEnvelope(liveCreate('secret-deux'));
      await tester.pump();

      await tester.tap(find.byKey(direct));
      await tester.pump();
      await tester.pump();

      expect(rig.errors.toString(), 'Rejeu : 2 messages vivants écartés\n');
    });
  });
}
