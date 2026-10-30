import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:feature_catalog_shelf/feature_catalog_shelf.dart';
import 'package:feature_protocol_feed/feature_protocol_feed.dart';
import 'package:feature_replay/feature_replay.dart'
    show ReplayBloc, ReplayRouter;
import 'package:feature_stage_controls/feature_stage_controls.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/material.dart' show FilledButton, OutlinedButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/page_rig.dart';

import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart'
    show GenesisCanvasPage;
import 'package:shared_core/shared_core.dart' show ReplayedMessage;
import 'package:shared_backend_channel/shared_backend_channel.dart'
    show CanvasActionResult, CanvasResetResult;

const _catalog = rigCatalog;

void main() {
  testWidgets('la page ne résout qu\'une VoiceSession, partagée', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester);
    await rig.start(tester);

    expect(rig.resolved, 1);
  });

  testWidgets('ordre de fermeture : Bloc de session, stop, dispose, source, '
      'puis les autres Blocs', (tester) async {
    final rig = PageRig(tester);
    await rig.mount(tester);
    await rig.start(tester);
    final journal = rig.journal;
    final ctx = rig.context;
    rig.harness.session.status.listen(
      null,
      onDone: () => journal.add('session.status done'),
    );
    ctx.read<VoiceSessionBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.session closed'),
    );
    ctx.read<TranscriptBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.transcript closed'),
    );
    ctx.read<CanvasActionBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.action closed'),
    );
    ctx.read<AgentActivityBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.agents closed'),
    );
    ctx.read<CanvasBloc>().stream.listen((state) {
      if (state.sourceStatus == CanvasSourceStatus.completed) {
        journal.add('source disposed');
      }
    }, onDone: () => journal.add('bloc.canvas closed'));
    ctx.read<ProtocolFeedBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.protocol closed'),
    );
    ctx.read<CatalogShelfBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.shelf closed'),
    );
    ctx.read<StageBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.stage closed'),
    );

    await tester.pumpWidget(const SizedBox());
    await drain(tester);

    // La fin du flux `status` (libération de la session) est notifiée de façon
    // asynchrone : on la situe entre la libération du transport et la fermeture
    // du Bloc de transcription, sans l'ordonner finement par rapport à la
    // source (que la page ne ferme qu'après l'avoir attendue).
    final statusDone = journal.indexOf('session.status done');
    expect(statusDone, greaterThan(journal.indexOf('t1.dispose')));
    expect(statusDone, lessThan(journal.indexOf('bloc.transcript closed')));
    journal.remove('session.status done');
    // Le gate A2UI se ferme avec la source qui l'alimente, avant les Blocs : la
    // fin de son flux accepté (le Bloc du canevas passe à `completed`, repère
    // « source disposed ») n'arrive qu'à ce moment-là.
    final gateClosed = journal.indexOf('source disposed');
    expect(gateClosed, greaterThan(journal.indexOf('t1.dispose')));
    expect(gateClosed, lessThan(journal.indexOf('bloc.transcript closed')));
    expect(gateClosed, lessThan(journal.indexOf('bloc.canvas closed')));
    expect(gateClosed, lessThan(journal.indexOf('bloc.protocol closed')));
    expect(gateClosed, lessThan(journal.indexOf('bloc.shelf closed')));
    expect(journal, <String>[
      'bloc.session closed',
      'relay.delete(s1)',
      't1.stop',
      't1.dispose',
      'source disposed',
      'bloc.transcript closed',
      // Le Bloc d'action lit l'activité des agents (relayée par la page) : il
      // se ferme avant le Bloc des agents.
      'bloc.action closed',
      'bloc.agents closed',
      'bloc.canvas closed',
      // Les Blocs de l'écran de fabrication se ferment après la source et le
      // gate qui les nourrissent.
      'bloc.protocol closed',
      'bloc.shelf closed',
      'bloc.stage closed',
    ]);
    expect(rig.errors.toString(), isEmpty);
  });

  testWidgets('fermeture : Bloc du rejeu en premier et une seule fois, '
      'routeur avant le gate, Bloc du canevas après', (tester) async {
    final observer = _CloseCounter();
    final previous = Bloc.observer;
    Bloc.observer = observer;
    addTearDown(() => Bloc.observer = previous);
    final rig = PageRig(tester);
    await rig.mount(tester);
    await rig.start(tester);
    final journal = rig.journal;
    final ctx = rig.context;
    final page = tester.state(find.byType(GenesisCanvasPage)) as dynamic;
    (page.router as ReplayRouter).journalSize.listen(
      null,
      onDone: () => journal.add('router disposed'),
    );
    ctx.read<ReplayBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.replay closed'),
    );
    ctx.read<CanvasBloc>().stream.listen((state) {
      if (state.sourceStatus == CanvasSourceStatus.completed) {
        journal.add('source disposed');
      }
    }, onDone: () => journal.add('bloc.canvas closed'));

    await tester.pumpWidget(const SizedBox());
    await drain(tester);

    final replayClosed = journal.indexOf('bloc.replay closed');
    final routerDisposed = journal.indexOf('router disposed');
    final gateClosed = journal.indexOf('source disposed');
    final canvasClosed = journal.indexOf('bloc.canvas closed');
    expect(replayClosed, isNonNegative);
    expect(replayClosed, lessThan(journal.indexOf('t1.stop')));
    expect(replayClosed, lessThan(gateClosed));
    expect(replayClosed, lessThan(routerDisposed));
    expect(routerDisposed, lessThan(gateClosed));
    expect(canvasClosed, greaterThan(routerDisposed));
    expect(observer.closes[ReplayBloc], 1);
    expect(rig.errors.toString(), isEmpty);
  });

  testWidgets('stop qui ne se termine pas : borné par sessionCloseTimeout, '
      'la fermeture continue', (tester) async {
    final rig = PageRig(
      tester,
      config: const GenesisConfig(sessionCloseTimeout: Duration(seconds: 3)),
      stopNeverEnds: true,
    );
    await rig.mount(tester);
    await rig.start(tester);
    rig.context.read<CanvasBloc>().stream.listen(
      null,
      onDone: () => rig.journal.add('bloc.canvas closed'),
    );

    await tester.pumpWidget(const SizedBox());
    await drain(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(rig.journal, <String>['relay.delete(s1)', 't1.stop']);
    expect(rig.errors.toString(), isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await drain(tester);
    expect(rig.errors.toString(), contains('arrêt de la session a échoué'));

    // La libération, bornée à son tour, échoue sans bloquer la suite.
    await tester.pump(const Duration(seconds: 3));
    await drain(tester);
    expect(
      rig.errors.toString(),
      contains('libération de la session a échoué'),
    );
    expect(rig.journal, contains('bloc.canvas closed'));
  });

  testWidgets('sortie de l\'app : stop attendu, borné par exitCloseTimeout', (
    tester,
  ) async {
    final rig = PageRig(
      tester,
      config: const GenesisConfig(exitCloseTimeout: Duration(seconds: 2)),
      stopNeverEnds: true,
    );
    await rig.mount(tester);
    await rig.start(tester);

    AppExitResponse? response;
    unawaited(
      tester.binding.handleRequestAppExit().then((value) => response = value),
    );
    await drain(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(rig.journal, <String>['relay.delete(s1)', 't1.stop']);
    expect(response, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(response, AppExitResponse.exit);
  });

  group('source vivante et mode scénario', () {
    Map<String, Object?> create() => <String, Object?>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': 'kpi',
        'catalogId': _catalog,
      },
    };
    Map<String, Object?> components({String component = 'KeyIndicator'}) =>
        <String, Object?>{
          'version': 'v0.9',
          'updateComponents': <String, Object?>{
            'surfaceId': 'kpi',
            'components': <Object?>[
              <String, Object?>{
                'id': 'root',
                'component': component,
                'data': <String, Object?>{'path': '/kpi'},
              },
            ],
          },
        };
    Map<String, Object?> data() => <String, Object?>{
      'version': 'v0.9',
      'updateDataModel': <String, Object?>{
        'surfaceId': 'kpi',
        'path': '/kpi',
        'value': <String, Object?>{
          'label': 'vivant',
          'value': '1',
          'trend': '0',
          'threshold': '1',
          'status': 'ok',
          'statusLabel': 'OK',
        },
      },
    };

    bool startEnabled(WidgetTester tester) =>
        tester
            .widget<FilledButton>(find.byKey(const Key('start-button')))
            .onPressed !=
        null;

    testWidgets('sans scénario : les a2ui de la source vivante vont au '
        'canevas et Démarrer est actif', (tester) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      expect(startEnabled(tester), isTrue);
      await rig.start(tester);

      rig.receive(create());
      rig.receive(components());
      rig.receive(data());
      await tester.pump();
      await tester.pump();

      expect(find.text('vivant'), findsOneWidget);
    });

    testWidgets('un message vivant refusé par le gate : code consigné, '
        'surface retirée, flux intact', (tester) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);

      rig.receive(create());
      rig.receive(components(component: 'Inconnu'));
      await tester.pump();
      await tester.pump();

      expect(rig.errors.toString(), contains('component_not_allowed'));
      expect(rig.errors.toString(), isNot(contains('Inconnu')));
      expect(find.byKey(const Key('surface-kpi')), findsNothing);

      // Le flux continue : une nouvelle surface valide s'affiche.
      rig.receive(create());
      rig.receive(components());
      rig.receive(data());
      await tester.pump();
      await tester.pump();
      expect(find.text('vivant'), findsOneWidget);
    });

    testWidgets('avec scénario : la source vivante n\'est pas branchée au '
        'canevas et Démarrer est désactivé', (tester) async {
      final rig = PageRig(tester);
      final replay = StreamController<ReplayedMessage>();
      addTearDown(replay.close);
      await rig.mount(tester, replay: replay.stream);
      expect(startEnabled(tester), isFalse);
      await rig.start(tester);

      rig.receive(create());
      rig.receive(components());
      rig.receive(data());
      await tester.pump();
      await tester.pump();

      expect(find.text('vivant'), findsNothing);
      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets('sans scénario, la fin de la source ne dit pas '
        '« Rejeu impossible »', (tester) async {
      final rig = PageRig(tester);
      await rig.mount(tester);

      await tester.pumpWidget(const SizedBox());
      await drain(tester);

      expect(rig.errors.toString(), isNot(contains('Rejeu impossible')));
    });

    testWidgets('démarrage en mode vivant : une remise à vide du backend, '
        'avant toute session voix (pdr-0064 D6)', (tester) async {
      final rig = PageRig(tester);
      await rig.mount(tester);

      expect(rig.resetClient.startupCalls, 1);
      expect(rig.resetClient.calls, 0);
      expect(rig.resolved, 1);
      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets('démarrage en mode vivant : l\'échec de la remise à vide est '
        'consigné sans bloquer le démarrage', (tester) async {
      final rig = PageRig(tester);
      rig.resetClient.startupResult = CanvasResetResult.unreachable;
      await rig.mount(tester);
      await rig.start(tester);

      expect(rig.resetClient.startupCalls, 1);
      expect(rig.errors.toString(), contains('Remise à vide'));
      expect(rig.errors.toString(), contains('unreachable'));
    });

    testWidgets('remise à vide de démarrage occupée : plus aucune demande '
        'après le début de la première session', (tester) async {
      final rig = PageRig(tester);
      rig.resetClient.startupResult = CanvasResetResult.busy;
      rig.resetClient.script.addAll(<CanvasResetResult>[
        CanvasResetResult.busy,
        CanvasResetResult.busy,
        CanvasResetResult.busy,
      ]);
      await rig.mount(tester);
      expect(rig.resetClient.startupCalls, 1);

      // Un réessai a eu lieu (busy), puis la session démarre.
      await tester.pump(rig.settings.canvasResetRetryInterval);
      await drain(tester);
      expect(rig.resetClient.calls, 1);
      await rig.start(tester);

      await tester.pump(rig.settings.canvasResetRetryInterval * 5);
      await drain(tester);
      expect(
        rig.resetClient.calls,
        1,
        reason: 'aucune demande après Connecting',
      );
      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets('démarrage en mode rejeu : aucune remise à vide', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester, replay: const Stream<ReplayedMessage>.empty());
      await drain(tester);

      expect(rig.resetClient.calls, 0);
    });
  });

  group('écran de fabrication : Blocs de l\'acte 1 branchés par la page', () {
    Map<String, Object?> create(String id) => <String, Object?>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': id,
        'catalogId': _catalog,
      },
    };

    /// Journal des événements reçus par les Blocs de l'écran (observateur
    /// global) : il atteste l'ordre de la remise à vide.
    late List<String> events;
    late BlocObserver previousObserver;

    void observe(PageRig rig) {
      events = rig.journal;
      previousObserver = Bloc.observer;
      Bloc.observer = _JournalObserver(events);
      addTearDown(() => Bloc.observer = previousObserver);
    }

    Future<void> pumpMessages(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'le panneau et l\'étagère reçoivent les messages dès le premier '
      '(branchés avant toute connexion)',
      (tester) async {
        final rig = PageRig(tester);
        await rig.mount(tester);
        await rig.start(tester);

        rig.receive(create('kpi'));
        await pumpMessages(tester);

        final feed = rig.context.read<ProtocolFeedBloc>().state;
        expect(feed.entries, hasLength(1));
        expect(feed.entries.single.surfaceId, 'kpi');
        // Horodatée à l'horloge injectée par le graphe de l'app.
        expect(feed.entries.single.timestampMs, greaterThan(0));
      },
    );

    testWidgets('un message refusé est vu du panneau et pas du canevas', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);

      rig.receive(<String, Object?>{
        'version': 'v0.9',
        'updateComponents': <String, Object?>{
          'surfaceId': 'kpi',
          'components': <Object?>[
            <String, Object?>{'id': 'root', 'component': 'Column'},
          ],
        },
      });
      await pumpMessages(tester);

      final feed = rig.context.read<ProtocolFeedBloc>().state;
      expect(feed.entries.single.accepted, isFalse);
      expect(feed.entries.single.rejectionCode, 'component_not_allowed');
      expect(find.byKey(const Key('surface-kpi')), findsNothing);
    });

    testWidgets('la surface du message en cours est cerclée en pointillé', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);

      rig.receive(create('kpi'));
      rig.receive(create('trend'));
      await pumpMessages(tester);

      expect(find.byKey(const Key('highlight-trend')), findsOneWidget);
      expect(find.byKey(const Key('highlight-kpi')), findsNothing);
    });

    testWidgets('remise à vide : validateur, Blocs dans l\'ordre, puis client '
        'du backend', (tester) async {
      final rig = PageRig(tester);
      observe(rig);
      await rig.mount(tester);
      await rig.start(tester);
      rig.receive(create('kpi'));
      await pumpMessages(tester);
      expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
      await tester.tap(find.byKey(const Key('act-indicator')));
      await pumpMessages(tester);
      expect(rig.context.read<StageBloc>().state.act, 2);
      events.clear();

      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);

      // (2) un ordre à chaque Bloc, (3) puis la requête au backend, une fois.
      expect(events, <String>[
        'CanvasResetRequested',
        'ProtocolFeedCleared',
        'CatalogShelfCleared',
        'AgentActivityReset',
        'StageResetRequested',
        'ActionStageReset',
        'client.reset',
      ]);
      expect(rig.resetClient.calls, 1);
      // État cible = état initial.
      expect(find.byKey(const Key('surface-kpi')), findsNothing);
      expect(rig.context.read<StageBloc>().state.act, 1);
      expect(rig.context.read<ProtocolFeedBloc>().state.entries, isEmpty);
      expect(rig.context.read<CatalogShelfBloc>().state.usedCount, 0);
      expect(rig.context.read<AgentActivityBloc>().state.agents, isEmpty);
      expect(rig.errors.toString(), isEmpty);

      // (1) Le validateur est remis à zéro : la même surface se recrée au lieu
      // d'être refusée comme « existante ».
      rig.receive(create('kpi'));
      await pumpMessages(tester);
      expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets(
      'remise à vide : la requête au backend part dans le tour du clic, '
      'sans attendre',
      (tester) async {
        final rig = PageRig(tester);
        await rig.mount(tester);
        await rig.start(tester);
        rig.receive(create('kpi'));
        await pumpMessages(tester);

        await tester.tap(find.byKey(const Key('reset-button')));
        // Aucun `await` entre le clic et la lecture : tout est synchrone.
        expect(rig.resetClient.calls, 1);
        await pumpMessages(tester);
        expect(find.byKey(const Key('surface-kpi')), findsNothing);
      },
    );

    testWidgets(
      'backend occupé ou en échec : consigné, l\'écran est vidé quand '
      'même',
      (tester) async {
        // Sans réessai : la consigne est immédiate (les réessais ont leurs
        // propres tests).
        final rig = PageRig(
          tester,
          config: const GenesisConfig(canvasResetRetries: 0),
        );
        rig.resetClient.result = CanvasResetResult.busy;
        await rig.mount(tester);
        await rig.start(tester);
        rig.receive(create('kpi'));
        await pumpMessages(tester);

        await tester.tap(find.byKey(const Key('reset-button')));
        await pumpMessages(tester);

        expect(rig.errors.toString(), contains('Remise à vide'));
        expect(rig.errors.toString(), contains('busy'));
        expect(find.byKey(const Key('surface-kpi')), findsNothing);
        expect(rig.context.read<ProtocolFeedBloc>().state.entries, isEmpty);
      },
    );

    testWidgets('backend occupé puis disponible : réessai, une fois fini', (
      tester,
    ) async {
      final rig = PageRig(tester);
      rig.resetClient.script.addAll(<CanvasResetResult>[
        CanvasResetResult.busy,
        CanvasResetResult.done,
      ]);
      await rig.mount(tester);
      await rig.start(tester);

      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);
      expect(rig.resetClient.calls, 1);

      await tester.pump(rig.settings.canvasResetRetryInterval);
      await pumpMessages(tester);
      expect(rig.resetClient.calls, 2);

      // Aucun réessai après `done`.
      await tester.pump(rig.settings.canvasResetRetryInterval * 3);
      expect(rig.resetClient.calls, 2);
      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets(
      'backend toujours occupé : s\'arrête après N réessais, consigné',
      (tester) async {
        final rig = PageRig(
          tester,
          config: const GenesisConfig(
            canvasResetRetries: 3,
            canvasResetRetryInterval: Duration(milliseconds: 100),
          ),
        );
        rig.resetClient.result = CanvasResetResult.busy;
        await rig.mount(tester);
        await rig.start(tester);

        await tester.tap(find.byKey(const Key('reset-button')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Un essai initial puis trois réessais.
        expect(rig.resetClient.calls, 4);
        expect(rig.errors.toString(), contains('Remise à vide'));
        expect(rig.errors.toString(), contains('busy'));
      },
    );

    testWidgets('résultat autre que busy : pas de réessai', (tester) async {
      final rig = PageRig(tester);
      rig.resetClient.result = CanvasResetResult.unreachable;
      await rig.mount(tester);
      await rig.start(tester);

      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);
      await tester.pump(rig.settings.canvasResetRetryInterval * 3);

      expect(rig.resetClient.calls, 1);
      expect(rig.errors.toString(), contains('unreachable'));
    });

    testWidgets('fermeture de la page pendant un réessai : plus d\'appel', (
      tester,
    ) async {
      final rig = PageRig(tester);
      rig.resetClient.result = CanvasResetResult.busy;
      await rig.mount(tester);
      await rig.start(tester);

      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);
      expect(rig.resetClient.calls, 1);

      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      await tester.pump(rig.settings.canvasResetRetryInterval * 3);

      expect(rig.resetClient.calls, 1);
    });

    testWidgets('seconde remise à vide pendant un réessai : une seule boucle', (
      tester,
    ) async {
      final rig = PageRig(
        tester,
        config: const GenesisConfig(
          canvasResetRetries: 2,
          canvasResetRetryInterval: Duration(milliseconds: 100),
        ),
      );
      rig.resetClient.result = CanvasResetResult.busy;
      await rig.mount(tester);
      await rig.start(tester);

      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);
      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);
      expect(rig.resetClient.calls, 2);

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // La seconde boucle remplace la première : 2 essais initiaux + 2
      // réessais, pas 2 + 2 + 2.
      expect(rig.resetClient.calls, 4);
    });

    testWidgets('backend joignable : rien n\'est consigné', (tester) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);

      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);

      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets('« Remettre à vide » est inactif tant qu\'un agent travaille', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);
      rig.receiveEnvelope(<String, Object?>{
        'v': 1,
        'type': 'agent.activity',
        'session': 's1',
        't_ms': 10,
        'data': <String, Object?>{
          'agent': 'Qualité',
          'task': 't1',
          'state': 'working',
        },
        'agent': 'Qualité',
        'task': 't1',
      });
      await pumpMessages(tester);

      await tester.tap(
        find.byKey(const Key('reset-button')),
        warnIfMissed: false,
      );
      await pumpMessages(tester);

      expect(rig.resetClient.calls, 0);
    });
  });

  group('acte 3 : Bloc d\'action branché par la page', () {
    Map<String, Object?> activity(String state) => <String, Object?>{
      'v': 1,
      'type': 'agent.activity',
      'session': 's1',
      't_ms': 10,
      'data': <String, Object?>{
        'agent': 'Livraison',
        'task': 't1',
        'state': state,
      },
      'agent': 'Livraison',
      'task': 't1',
    };

    Map<String, Object?> actionsCreate() => <String, Object?>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': 'actions',
        'catalogId': _catalog,
      },
    };
    Map<String, Object?> actionsComponents() => <String, Object?>{
      'version': 'v0.9',
      'updateComponents': <String, Object?>{
        'surfaceId': 'actions',
        'components': <Object?>[
          <String, Object?>{
            'id': 'root',
            'component': 'ActionBar',
            'data': <String, Object?>{'path': '/actions'},
          },
        ],
      },
    };
    Map<String, Object?> actionsData() => <String, Object?>{
      'version': 'v0.9',
      'updateDataModel': <String, Object?>{
        'surfaceId': 'actions',
        'path': '/actions',
        'value': <String, Object?>{
          'title': 'Décision',
          'actions': <Object?>[
            <String, Object?>{
              'id': 'block_release',
              'label': 'Bloquer',
              'tone': 'danger',
            },
          ],
        },
      },
    };

    /// Le bouton de la Barre d'actions est-il actif (disponibilité vue par
    /// l'utilisateur : `OutlinedButton.onPressed`) ?
    bool actionEnabled(WidgetTester tester) =>
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('action-block_release')),
            )
            .onPressed !=
        null;

    ReplayedMessage replayed(Map<String, Object?> json) =>
        (raw: json, message: a2ui.A2uiMessage.fromJson(json));

    Future<void> pumpMessages(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    testWidgets('un clic envoie l\'action ; inactif jusqu\'à la fin de '
        'l\'activité des agents', (tester) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);
      final bloc = rig.context.read<CanvasActionBloc>();

      bloc.add(const ActionRequested('block_release', 'actions'));
      await pumpMessages(tester);
      expect(rig.actionClient.calls, <String>['block_release@actions']);
      expect(bloc.state, isA<ActionRunning>());

      rig.receiveEnvelope(activity('working'));
      await pumpMessages(tester);
      expect(bloc.state, isA<ActionRunning>());

      rig.receiveEnvelope(activity('completed'));
      await pumpMessages(tester);
      expect(bloc.state, isA<ActionIdle>());
    });

    testWidgets('la remise à vide réinitialise le Bloc d\'action', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);
      final bloc = rig.context.read<CanvasActionBloc>();
      bloc.add(const ActionRequested('block_release', 'actions'));
      await pumpMessages(tester);
      expect(bloc.state, isA<ActionRunning>());

      await tester.tap(find.byKey(const Key('reset-button')));
      await pumpMessages(tester);

      expect(bloc.state, isA<ActionIdle>());
    });

    testWidgets('la fermeture de la session libère l\'action en cours', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);
      final bloc = rig.context.read<CanvasActionBloc>();
      bloc.add(const ActionRequested('block_release', 'actions'));
      await pumpMessages(tester);
      expect(bloc.state, isA<ActionRunning>());

      unawaited(rig.harness.session.stop());
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      expect(bloc.state, isA<ActionIdle>());
    });

    testWidgets('un refus du backend est consigné, les boutons redeviennent '
        'actifs', (tester) async {
      final rig = PageRig(tester);
      rig.actionClient.script.add(CanvasActionResult.rejected);
      await rig.mount(tester);
      await rig.start(tester);
      final bloc = rig.context.read<CanvasActionBloc>();

      bloc.add(const ActionRequested('block_release', 'actions'));
      await pumpMessages(tester);

      expect(bloc.state, isA<ActionIdle>());
      expect(rig.errors.toString(), contains('Action'));
      expect(rig.errors.toString(), contains('rejected'));
    });

    testWidgets('mode rejeu : les actions ne sont pas disponibles', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(
        tester,
        replay: Stream<ReplayedMessage>.fromIterable(<ReplayedMessage>[
          replayed(actionsCreate()),
          replayed(actionsComponents()),
          replayed(actionsData()),
        ]),
      );
      await drain(tester);

      expect(actionEnabled(tester), isFalse);
      expect(rig.actionClient.calls, isEmpty);
    });

    testWidgets('mode vivant : les actions sont disponibles au repos', (
      tester,
    ) async {
      final rig = PageRig(tester);
      await rig.mount(tester);
      await rig.start(tester);

      rig.receive(actionsCreate());
      rig.receive(actionsComponents());
      rig.receive(actionsData());
      await tester.pump();
      await tester.pump();

      expect(actionEnabled(tester), isTrue);
    });
  });
}

/// Consigne le type de chaque événement de Bloc dans le journal des faux.
class _JournalObserver extends BlocObserver {
  _JournalObserver(this.journal);

  final List<String> journal;

  static const _watched = <String>{
    'CanvasResetRequested',
    'ProtocolFeedCleared',
    'CatalogShelfCleared',
    'AgentActivityReset',
    'StageResetRequested',
    'ActionStageReset',
  };

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    final name = event.runtimeType.toString();
    if (_watched.contains(name)) journal.add(name);
  }
}

/// Compte les appels à `close()` par type de Bloc.
class _CloseCounter extends BlocObserver {
  final Map<Type, int> closes = <Type, int>{};

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    closes[bloc.runtimeType] = (closes[bloc.runtimeType] ?? 0) + 1;
  }
}
