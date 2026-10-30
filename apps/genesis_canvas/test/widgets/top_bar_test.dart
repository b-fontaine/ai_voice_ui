import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/material.dart' show FilledButton;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:testing_voice_fakes/testing_voice_fakes.dart';

const Key _start = Key('start-button');
const Key _stop = Key('stop-button');
const Key _status = Key('status-message');

/// Enregistre les commandes (events) reçues par le `VoiceSessionBloc` réel,
/// via l'observateur global de Bloc ; l'abonnement au statut, posé par le
/// banc, n'est pas une commande des widgets et est écarté.
class _CommandRecorder extends BlocObserver {
  final List<VoiceSessionEvent> received = <VoiceSessionEvent>[];

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event is VoiceSessionEvent && event is! VoiceSessionSubscribed) {
      received.add(event);
    }
  }
}

/// Hôte : Blocs réels pour la transcription et les agents (alimentés par un
/// flux d'événements de session) et pour la session voix : un vrai
/// `VoiceSessionBloc` sur une vraie `VoiceSession`, dont seules les
/// frontières (transport WebRTC, relais, canal) sont fausses. Les statuts
/// sont obtenus en pilotant ces frontières.
class _Rig {
  _Rig() {
    _previousObserver = Bloc.observer;
    Bloc.observer = commands;
    voice = VoiceSessionBloc(harness.session);
  }

  final VoiceHarness harness = VoiceHarness();
  final _CommandRecorder commands = _CommandRecorder();
  late final BlocObserver _previousObserver;
  late final VoiceSessionBloc voice;
  final TranscriptBloc transcript = TranscriptBloc();
  final AgentActivityBloc agents = AgentActivityBloc();
  final StreamController<SessionEvent> events =
      StreamController<SessionEvent>.broadcast();
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  /// Réponses du relais en attente (connexion ou fermeture en cours).
  Completer<RelayAnswer>? _pendingCreate;
  Completer<void>? _pendingDelete;

  List<VoiceSessionEvent> get received => commands.received;

  Widget host({Widget? bar}) => Directionality(
    textDirection: TextDirection.ltr,
    child: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<VoiceSessionBloc>.value(value: voice),
        BlocProvider<TranscriptBloc>.value(value: transcript),
        BlocProvider<AgentActivityBloc>.value(value: agents),
      ],
      child: bar ?? TopBar(orbLevel: level),
    ),
  );

  /// Monte l'hôte puis branche les Blocs sur la source, dans la zone du test.
  Future<void> pump(WidgetTester tester, {Widget? bar}) async {
    await tester.pumpWidget(host(bar: bar));
    voice.add(const VoiceSessionSubscribed());
    transcript.add(TranscriptSourceSubscribed(events.stream));
    agents.add(AgentActivitySourceSubscribed(events.stream));
    await tester.pump();
  }

  /// Laisse les chaînes asynchrones de la session avancer.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  /// `Connecting` : le relais n'a pas encore répondu à l'offre.
  Future<void> connecting(WidgetTester tester) async {
    final pending = _pendingCreate = Completer<RelayAnswer>();
    harness.relay.createHook = (_) => pending.future;
    unawaited(harness.session.start());
    await settle(tester);
  }

  /// Le relais répond : la connexion aboutit.
  Future<void> answerRelay(WidgetTester tester) async {
    _pendingCreate!.complete(
      const RelayAnswer(answerSdp: 'answer-1', sessionId: 's1'),
    );
    await settle(tester);
  }

  /// `Active` : connexion complète (relais, transport, canal).
  Future<void> active(WidgetTester tester) async {
    unawaited(harness.session.start());
    await settle(tester);
  }

  /// `Stopping` : session active dont le `DELETE` du relais n'a pas répondu.
  Future<void> stopping(WidgetTester tester) async {
    await active(tester);
    final pending = _pendingDelete = Completer<void>();
    harness.relay.deleteHook = (_) => pending.future;
    unawaited(harness.session.stop());
    await settle(tester);
  }

  /// `Failed(BackendUnreachable)` : le relais est injoignable.
  Future<void> backendUnreachable(WidgetTester tester) async {
    harness.relay.createHook = (_) async =>
        throw const RelayFailure(RelayFailureKind.unreachable);
    unawaited(harness.session.start());
    await settle(tester);
  }

  /// `Failed(MicUnavailable)` : le transport ne peut pas ouvrir le micro.
  Future<void> micUnavailable(WidgetTester tester) async {
    harness.onNewTransport = (transport) => transport.offerHook = () async =>
        throw const VoiceTransportException(
          VoiceTransportFailure.micUnavailable,
        );
    unawaited(harness.session.start());
    await settle(tester);
  }

  Future<void> dispose() async {
    // Libère ce qui attend une réponse de frontière, puis ferme.
    final create = _pendingCreate;
    if (create != null && !create.isCompleted) {
      create.completeError(const RelayFailure(RelayFailureKind.unreachable));
    }
    final delete = _pendingDelete;
    if (delete != null && !delete.isCompleted) delete.complete();
    await events.close();
    await voice.close();
    await harness.session.dispose();
    await transcript.close();
    await agents.close();
    level.dispose();
    Bloc.observer = _previousObserver;
  }
}

void main() {
  // Le banc est créé dans la zone du test (FakeAsync) : sinon les microtâches
  // des Blocs échappent à `pump`.
  late _Rig rig;

  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    rig = _Rig();
    await body(tester);
    // Démontage puis fermeture, vidée par `pump` (zone FakeAsync).
    await tester.pumpWidget(const SizedBox());
    unawaited(rig.dispose());
    await rig.settle(tester);
  });

  testWidgets("l'orbe est présent et alimenté par orbLevel", (tester) async {
    await rig.pump(tester);

    final orb = tester.widget<VoiceOrb>(find.byKey(const Key('voice-orb')));
    expect(orb.level, same(rig.level));
  });

  group('boutons', () {
    testWidgets('Idle : Démarrer seul, sans message', (tester) async {
      await rig.pump(tester);

      expect(find.byKey(_start), findsOneWidget);
      expect(find.text('Démarrer'), findsOneWidget);
      expect(find.byKey(_stop), findsNothing);
      expect(find.byKey(_status), findsNothing);
    });

    testWidgets('Démarrer envoie VoiceSessionStarted', (tester) async {
      await rig.pump(tester);

      await tester.tap(find.byKey(_start));
      await tester.pump();

      expect(rig.received, <Matcher>[isA<VoiceSessionStarted>()]);
      // La commande atteint la vraie session : le relais reçoit l'offre.
      expect(rig.harness.events, contains('relay.create'));
    });

    for (final (name, s) in <(String, Future<void> Function(WidgetTester))>[
      ('Connecting', (tester) => rig.connecting(tester)),
      ('Active', (tester) => rig.active(tester)),
    ]) {
      testWidgets('$name : Arrêter actif, Démarrer absent', (tester) async {
        await rig.pump(tester);
        await s(tester);

        expect(find.byKey(_start), findsNothing);
        expect(find.text('Arrêter'), findsOneWidget);

        await tester.tap(find.byKey(_stop));
        await tester.pump();
        expect(rig.received, <Matcher>[isA<VoiceSessionStopped>()]);
      });
    }

    testWidgets('startEnabled false : Démarrer désactivé, rien envoyé', (
      tester,
    ) async {
      await rig.pump(
        tester,
        bar: TopBar(orbLevel: rig.level, startEnabled: false),
      );

      expect(find.byKey(_start), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(_start)).onPressed, isNull);
      await tester.tap(find.byKey(_start), warnIfMissed: false);
      await tester.pump();
      expect(rig.received, isEmpty);
    });

    testWidgets('Stopping : Arrêter désactivé', (tester) async {
      await rig.pump(tester);
      await rig.stopping(tester);

      expect(find.byKey(_stop), findsOneWidget);
      await tester.tap(find.byKey(_stop), warnIfMissed: false);
      await tester.pump();

      expect(rig.received, isEmpty);
      expect(find.text('Arrêt…'), findsOneWidget);
    });

    testWidgets('Failed : Démarrer revient, avec le message', (tester) async {
      await rig.pump(tester);
      await rig.backendUnreachable(tester);

      expect(find.byKey(_start), findsOneWidget);
      expect(find.byKey(_stop), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(_status),
          matching: find.textContaining('Backend injoignable'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Connecting : message « Connexion… » puis plus rien', (
      tester,
    ) async {
      await rig.pump(tester);
      await rig.connecting(tester);
      expect(find.text('Connexion…'), findsOneWidget);

      await rig.answerRelay(tester);
      expect(find.byKey(_status), findsNothing);
    });
  });

  group('réflexion', () {
    Future<void> working(WidgetTester tester, AgentTaskState s) async {
      rig.events.add(
        AgentActivityReceived(agent: 'Qualité', task: 't', state: s),
      );
      await tester.pump();
      await tester.pump();
    }

    bool thinking(WidgetTester tester) =>
        tester.widget<VoiceOrb>(find.byKey(const Key('voice-orb'))).thinking;

    testWidgets('session active et agent au travail : réflexion', (
      tester,
    ) async {
      await rig.pump(tester);
      await rig.active(tester);
      expect(thinking(tester), isFalse);

      await working(tester, AgentTaskState.working);
      expect(thinking(tester), isTrue);

      await working(tester, AgentTaskState.completed);
      expect(thinking(tester), isFalse);
    });

    testWidgets("agent au travail mais session inactive : pas d'animation", (
      tester,
    ) async {
      await rig.pump(tester);
      await working(tester, AgentTaskState.working);

      expect(thinking(tester), isFalse);
    });
  });

  group('transcription', () {
    testWidgets('deux lignes mises à jour par les fragments', (tester) async {
      await rig.pump(tester);

      rig.events
        ..add(
          const TranscriptDelta(
            role: TranscriptRole.user,
            text: 'Prépare la ',
            startMs: 0,
            endMs: 1,
          ),
        )
        ..add(
          const TranscriptDelta(
            role: TranscriptRole.user,
            text: 'release 3.4',
            startMs: 1,
            endMs: 2,
          ),
        );
      await tester.pump();
      await tester.pump();
      rig.events.add(
        const TranscriptDelta(
          role: TranscriptRole.ai,
          text: 'analyse de la release',
          startMs: 3,
          endMs: 4,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('transcript-user')),
          matching: find.text('Prépare la release 3.4'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('transcript-ai')),
          matching: find.text('analyse de la release'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('les deux lignes existent même vides', (tester) async {
      await rig.pump(tester);

      expect(find.byKey(const Key('transcript-user')), findsOneWidget);
      expect(find.byKey(const Key('transcript-ai')), findsOneWidget);
    });
  });

  testWidgets('le bouton et le message sont lisibles par les technologies '
      "d'assistance", (tester) async {
    final semantics = tester.ensureSemantics();
    await rig.pump(tester);
    await rig.micUnavailable(tester);

    expect(find.bySemanticsLabel(RegExp('Démarrer')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Micro indisponible')), findsWidgets);
    expect(find.bySemanticsLabel('Orbe vocal'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'NFR-04 : 60 niveaux différents ne reconstruisent ni TopBar ni la page',
    (tester) async {
      var topBarBuilds = 0;
      var pageBuilds = 0;
      var orbBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, _) {
        final widget = element.widget;
        if (widget is TopBar) topBarBuilds++;
        if (widget is VoiceOrb) orbBuilds++;
        if (widget is Builder && widget.key == const Key('page')) {
          pageBuilds++;
        }
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);

      await rig.pump(
        tester,
        bar: Builder(
          key: const Key('page'),
          builder: (context) => TopBar(orbLevel: rig.level),
        ),
      );
      await rig.active(tester);
      final topBefore = topBarBuilds;
      final pageBefore = pageBuilds;
      final orbBefore = orbBuilds;
      final render = tester.renderObject<RenderCustomPaint>(
        find.descendant(
          of: find.byKey(const Key('voice-orb')),
          matching: find.byType(CustomPaint),
        ),
      );

      var repainted = 0;
      for (var i = 1; i <= 60; i++) {
        rig.level.value = i / 61;
        if (render.debugNeedsPaint) repainted++;
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(repainted, 60, reason: "chaque niveau repeint l'orbe");
      expect(topBarBuilds, topBefore, reason: 'TopBar jamais reconstruit');
      expect(pageBuilds, pageBefore, reason: 'la page jamais reconstruite');
      expect(orbBuilds, orbBefore, reason: "l'orbe jamais reconstruit");
    },
  );
}
