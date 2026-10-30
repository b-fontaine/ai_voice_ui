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

import 'support/stub_voice_session_bloc.dart';

const Key _start = Key('start-button');
const Key _stop = Key('stop-button');
const Key _status = Key('status-message');

/// Hôte : Blocs réels pour la transcription et les agents (alimentés par un
/// flux d'événements de session), substitut pour la session voix.
class _Rig {
  final StubVoiceSessionBloc voice = StubVoiceSessionBloc();
  final TranscriptBloc transcript = TranscriptBloc();
  final AgentActivityBloc agents = AgentActivityBloc();
  final StreamController<SessionEvent> events =
      StreamController<SessionEvent>.broadcast();
  final ValueNotifier<double> level = ValueNotifier<double>(0);

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
    transcript.add(TranscriptSourceSubscribed(events.stream));
    agents.add(AgentActivitySourceSubscribed(events.stream));
    await tester.pump();
  }

  Future<void> dispose() async {
    await events.close();
    await voice.close();
    await transcript.close();
    await agents.close();
    level.dispose();
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
    await tester.pump();
  });

  Future<void> status(WidgetTester tester, VoiceSessionStatus s) async {
    rig.voice.setStatus(s);
    await tester.pump();
  }

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

      expect(rig.voice.received, <Matcher>[isA<VoiceSessionStarted>()]);
    });

    for (final (name, s) in <(String, VoiceSessionStatus)>[
      ('Connecting', const Connecting()),
      ('Active', const Active()),
    ]) {
      testWidgets('$name : Arrêter actif, Démarrer absent', (tester) async {
        await rig.pump(tester);
        await status(tester, s);

        expect(find.byKey(_start), findsNothing);
        expect(find.text('Arrêter'), findsOneWidget);

        await tester.tap(find.byKey(_stop));
        await tester.pump();
        expect(rig.voice.received, <Matcher>[isA<VoiceSessionStopped>()]);
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
      expect(rig.voice.received, isEmpty);
    });

    testWidgets('Stopping : Arrêter désactivé', (tester) async {
      await rig.pump(tester);
      await status(tester, const Stopping());

      expect(find.byKey(_stop), findsOneWidget);
      await tester.tap(find.byKey(_stop), warnIfMissed: false);
      await tester.pump();

      expect(rig.voice.received, isEmpty);
      expect(find.text('Arrêt…'), findsOneWidget);
    });

    testWidgets('Failed : Démarrer revient, avec le message', (tester) async {
      await rig.pump(tester);
      await status(tester, const Failed(BackendUnreachable()));

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
      await status(tester, const Connecting());
      expect(find.text('Connexion…'), findsOneWidget);

      await status(tester, const Active());
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
      await status(tester, const Active());
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
    await status(tester, const Failed(MicUnavailable()));

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
      await status(tester, const Active());
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
