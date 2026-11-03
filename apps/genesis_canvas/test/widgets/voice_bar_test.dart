import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:genesis_canvas/widgets/top_bar/voice_wave.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show DsBlink, SceneMotionScope, SceneTheme;
import 'package:testing_real_fonts/testing_real_fonts.dart';
import 'package:testing_voice_fakes/testing_voice_fakes.dart';

import '../support/motion_probe.dart';

/// Barre vocale (T31) : anneaux de l'orbe, onde et transcription « VOUS » /
/// « IA » à curseur. Le mouvement n'existe que quand l'IA parle (A-06) ; la
/// boucle tourne en continu et n'est jamais relancée au franchissement du
/// seuil de parole (plan 019, P2).

const Key _orbKey = Key('voice-orb');
const Key _waveKey = Key('voice-wave');

Key _ring(int index) => Key('voice-orb-ring-$index');

Widget _host(Widget child, {bool animationsDisabled = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: SceneMotionScope(
    disabled: animationsDisabled,
    child: Center(child: child),
  ),
);

/// Nombre de peintures du `RepaintBoundary` porté par la clé [key].
int _paints(WidgetTester tester, Key key) {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find
        .descendant(
          of: find.byKey(key),
          matching: find.byType(RepaintBoundary),
          matchRoot: true,
        )
        .first,
  );
  return boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;
}

/// L'élément se repeint-il pendant les prochaines images ?
Future<bool> _repaints(WidgetTester tester, Key key) async {
  final int before = _paints(tester, key);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return _paints(tester, key) > before;
}

/// Appels de dessin du `CustomPaint` descendant de la clé [key].
List<RecordedInvocation> _draw(WidgetTester tester, Key key, Size size) {
  final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(CustomPaint),
      matchRoot: true,
    ),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  render.painter!.paint(canvas, size);
  return canvas.invocations;
}

Iterable<RecordedInvocation> _circles(List<RecordedInvocation> calls) =>
    calls.where((c) => c.invocation.memberName == #drawCircle);

double _radius(RecordedInvocation call) =>
    call.invocation.positionalArguments[1] as double;

Size _ringSize(WidgetTester tester) => tester.getSize(find.byKey(_orbKey));

void main() {
  late ValueNotifier<double> level;

  setUp(() => level = ValueNotifier<double>(0));
  tearDown(() => level.dispose());

  group('anneaux de l\'orbe (gc-orbring)', () {
    Future<void> pumpOrb(
      WidgetTester tester, {
      bool animationsDisabled = false,
    }) => tester.pumpWidget(
      _host(VoiceOrb(level: level), animationsDisabled: animationsDisabled),
    );

    testWidgets('trois anneaux, chacun dans son RepaintBoundary', (
      tester,
    ) async {
      await pumpOrb(tester);

      for (var i = 0; i < 3; i++) {
        expect(find.byKey(_ring(i)), findsOneWidget);
        expect(
          tester.renderObject(find.byKey(_ring(i))),
          isA<RenderRepaintBoundary>(),
        );
      }
      expect(find.byKey(const Key('voice-orb-core')), findsOneWidget);
    });

    testWidgets('l\'IA se tait : les anneaux ne se repeignent pas et ne '
        'dessinent rien', (tester) async {
      await pumpOrb(tester);

      for (var i = 0; i < 3; i++) {
        expect(await _repaints(tester, _ring(i)), isFalse, reason: 'anneau $i');
        expect(_circles(_draw(tester, _ring(i), _ringSize(tester))), isEmpty);
      }
      // Le corps de l'orbe, lui, continue de respirer.
      expect(await _repaints(tester, const Key('voice-orb-core')), isTrue);
    });

    testWidgets('l\'IA parle : les trois anneaux tournent, décalés', (
      tester,
    ) async {
      await pumpOrb(tester);
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));

      for (var i = 0; i < 3; i++) {
        expect(await _repaints(tester, _ring(i)), isTrue, reason: 'anneau $i');
      }
      final List<double> radii = <double>[
        for (var i = 0; i < 3; i++)
          _radius(_circles(_draw(tester, _ring(i), _ringSize(tester))).single),
      ];
      expect(radii.toSet(), hasLength(3), reason: 'phases décalées');
    });

    testWidgets('l\'IA se tait de nouveau : les anneaux s\'arrêtent', (
      tester,
    ) async {
      await pumpOrb(tester);
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));
      expect(await _repaints(tester, _ring(0)), isTrue);

      level.value = 0;
      await tester.pump(const Duration(milliseconds: 16));

      expect(await _repaints(tester, _ring(0)), isFalse);
      expect(_circles(_draw(tester, _ring(0), _ringSize(tester))), isEmpty);
    });

    testWidgets('animations coupées : phase de repos, anneaux invisibles même '
        'quand l\'IA parle', (tester) async {
      await pumpOrb(tester, animationsDisabled: true);
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));

      for (var i = 0; i < 3; i++) {
        expect(await _repaints(tester, _ring(i)), isFalse, reason: 'anneau $i');
        expect(_circles(_draw(tester, _ring(i), _ringSize(tester))), isEmpty);
      }
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('franchir le seuil ne relance pas la boucle : la phase '
        'continue', (tester) async {
      await pumpOrb(tester);
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 700));
      final double before = _radius(
        _circles(_draw(tester, _ring(0), _ringSize(tester))).single,
      );

      // Le niveau retombe puis remonte en deux images : si la boucle était
      // relancée, l'anneau repartirait de son rayon initial.
      level.value = 0;
      await tester.pump(const Duration(milliseconds: 16));
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));
      final double after = _radius(
        _circles(_draw(tester, _ring(0), _ringSize(tester))).single,
      );

      expect(after, greaterThan(before));
    });

    testWidgets('hystérésis : un niveau juste sous le seuil garde les '
        'anneaux, un niveau nul les éteint', (tester) async {
      await pumpOrb(tester);
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));

      // 0,02 est sous le seuil de parole (0,03) mais au-dessus de sa moitié.
      level.value = 0.02;
      await tester.pump(const Duration(milliseconds: 16));
      expect(_circles(_draw(tester, _ring(0), _ringSize(tester))), isNotEmpty);

      level.value = 0.005;
      await tester.pump(const Duration(milliseconds: 16));
      expect(_circles(_draw(tester, _ring(0), _ringSize(tester))), isEmpty);
    });
  });

  group('onde (gc-wave)', () {
    Future<void> pumpWave(
      WidgetTester tester, {
      bool animationsDisabled = false,
    }) => tester.pumpWidget(
      _host(
        VoiceWave(level: level, speakingThreshold: 0.03),
        animationsDisabled: animationsDisabled,
      ),
    );

    testWidgets('28 points de haut, dans son RepaintBoundary', (tester) async {
      await pumpWave(tester);

      expect(tester.getSize(find.byKey(_waveKey)).height, 28);
      expect(
        find.descendant(
          of: find.byKey(_waveKey),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('l\'IA se tait : l\'onde ne se repeint pas et ne dessine '
        'rien', (tester) async {
      await pumpWave(tester);

      expect(await _repaints(tester, _waveKey), isFalse);
      expect(
        _draw(
          tester,
          _waveKey,
          const Size(80, 28),
        ).where((c) => c.invocation.memberName == #drawRRect),
        isEmpty,
      );
    });

    testWidgets('l\'IA parle : douze barres dont la hauteur varie', (
      tester,
    ) async {
      await pumpWave(tester);
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));

      expect(await _repaints(tester, _waveKey), isTrue);
      double heightsSum() => _draw(tester, _waveKey, const Size(80, 28))
          .where((c) => c.invocation.memberName == #drawRRect)
          .map((c) => (c.invocation.positionalArguments[0] as RRect).height)
          .fold(0.0, (a, b) => a + b);
      final List<RecordedInvocation> bars = _draw(
        tester,
        _waveKey,
        const Size(80, 28),
      ).where((c) => c.invocation.memberName == #drawRRect).toList();
      expect(bars, hasLength(12));
      final double first = heightsSum();
      await tester.pump(const Duration(milliseconds: 250));
      expect(heightsSum(), isNot(first));
    });

    testWidgets('animations coupées : l\'onde reste invisible', (tester) async {
      await pumpWave(tester, animationsDisabled: true);
      level.value = 0.2;
      await tester.pump(const Duration(milliseconds: 16));

      expect(await _repaints(tester, _waveKey), isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('transcription « VOUS » / « IA »', () {
    late StreamController<SessionEvent> events;
    late VoiceHarness voiceHarness;
    late VoiceSessionBloc voice;
    late TranscriptBloc transcript;
    late AgentActivityBloc agents;
    late OrbPhaseBloc phase;

    void testBar(
      String description,
      Future<void> Function(WidgetTester tester) body, {
      bool motionDisabled = false,
    }) => testWidgets(description, (tester) async {
      events = StreamController<SessionEvent>.broadcast();
      voiceHarness = VoiceHarness();
      voice = VoiceSessionBloc(voiceHarness.session);
      transcript = TranscriptBloc();
      agents = AgentActivityBloc();
      phase = OrbPhaseBloc(
        speakingThreshold: 0.03,
        resumeSilence: const Duration(seconds: 3),
        maxInterruption: const Duration(seconds: 10),
        stopSpan: const Duration(seconds: 3),
      );
      await loadRealFonts();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<VoiceSessionBloc>.value(value: voice),
              BlocProvider<TranscriptBloc>.value(value: transcript),
              BlocProvider<AgentActivityBloc>.value(value: agents),
              BlocProvider<OrbPhaseBloc>.value(value: phase),
            ],
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: realFontFamily,
                fontFamilyFallback: realFontFallback,
              ),
              child: SceneMotionScope(
                disabled: motionDisabled,
                child: RepaintBoundary(
                  key: const Key('bar-outer'),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: TopBar(orbLevel: level),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      voice.add(const VoiceSessionSubscribed());
      transcript.add(TranscriptSourceSubscribed(events.stream));
      agents.add(AgentActivitySourceSubscribed(events.stream));
      phase.add(OrbPhaseSourceSubscribed(events.stream));
      await tester.pump();
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      unawaited(voice.close());
      unawaited(transcript.close());
      unawaited(agents.close());
      unawaited(phase.close());
      unawaited(voiceHarness.session.dispose());
      unawaited(events.close());
      await tester.pump();
    });

    Future<void> say(
      WidgetTester tester,
      TranscriptRole role,
      String text,
    ) async {
      events.add(TranscriptDelta(role: role, text: text, startMs: 0, endMs: 1));
      await tester.pump();
      await tester.pump();
    }

    testBar('étiquettes en capitales, sémantique d\'origine', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await say(tester, TranscriptRole.user, 'Compare la 3.3');
      await say(tester, TranscriptRole.ai, 'Le tableau est prêt');

      expect(
        find.descendant(
          of: find.byKey(const Key('transcript-user-who')),
          matching: find.text('VOUS'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('transcript-ai-who')),
          matching: find.text('IA'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(const Key('transcript-user-who'))).label,
        'Vous',
      );
      // Le contenu de la transcription n'est jamais mis en capitales.
      expect(find.text('Compare la 3.3'), findsOneWidget);
      expect(find.text('Le tableau est prêt'), findsOneWidget);
      semantics.dispose();
    });

    testBar('l\'étiquette de l\'IA est en plasma, celle de l\'utilisateur '
        'en ink-muted', (tester) async {
      const SceneTheme theme = SceneTheme.dark();
      TextStyle styleOf(String key) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )
          .style!;

      expect(styleOf('transcript-ai-who').color, theme.plasma);
      expect(styleOf('transcript-user-who').color, theme.textSecondary);
      expect(
        styleOf('transcript-ai-who').fontSize,
        theme.micro.quoteMeta.fontSize,
      );
    });

    testBar('le curseur accompagne la réplique de l\'IA et disparaît '
        'environ 1,2 s après la dernière parole', (tester) async {
      expect(find.byKey(const Key('transcript-ai-caret')), findsNothing);

      await say(tester, TranscriptRole.ai, 'Le tableau');
      expect(find.byKey(const Key('transcript-ai-caret')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const Key('transcript-ai-caret')), findsOneWidget);

      // Une nouvelle parole prolonge la saisie.
      await say(tester, TranscriptRole.ai, ' est prêt');
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const Key('transcript-ai-caret')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('transcript-ai-caret')), findsNothing);
    });

    // pdr-0088 F9, T34 : le curseur clignote (`gc-blink` .9 s) tant que la
    // réplique s'écrit et 1,2 s après, dans son propre RepaintBoundary.
    testBar('le curseur clignote en .9 s, dans son RepaintBoundary, sans '
        'redémarrer quand la réplique s\'allonge', (tester) async {
      await expectBlinkContract(
        tester,
        key: const Key('transcript-ai-caret'),
        period: const Duration(milliseconds: 900),
        mount: () => say(tester, TranscriptRole.ai, 'Le tableau'),
        rebuild: () => say(tester, TranscriptRole.ai, ' est prêt'),
        outer: find.byKey(const Key('bar-outer')),
      );
    });

    testBar('animations coupées : le curseur reste plein et ne tourne pas', (
      tester,
    ) async {
      await say(tester, TranscriptRole.ai, 'Le tableau');
      const caret = Key('transcript-ai-caret');
      expect(find.byKey(caret), findsOneWidget);
      expect(blinkOpacity(tester, caret), 1);
      await tester.pump(const Duration(milliseconds: 450));
      expect(blinkOpacity(tester, caret), 1);
      expect(tester.binding.transientCallbackCount, 0);
    }, motionDisabled: true);

    testBar('le curseur s\'arrête avec la réplique : plus de boucle 1,2 s '
        'après', (tester) async {
      await say(tester, TranscriptRole.ai, 'Le tableau');
      expect(find.byType(DsBlink), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.byKey(const Key('transcript-ai-caret')), findsNothing);
      expect(find.byType(DsBlink), findsNothing);
    });

    testBar('l\'onde est dans la barre, sous la transcription, et la barre '
        'garde sa hauteur', (tester) async {
      expect(find.byKey(_waveKey), findsOneWidget);
      expect(tester.getSize(find.byType(TopBar)).height, TopBar.height);
      final Rect ai = tester.getRect(find.byKey(const Key('transcript-ai')));
      final Rect wave = tester.getRect(find.byKey(_waveKey));
      expect(wave.top, greaterThanOrEqualTo(ai.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}
