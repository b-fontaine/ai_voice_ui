import 'dart:async';
import 'dart:ui' as ui show Tristate;

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:feature_stage_controls/feature_stage_controls.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/stage_bar/stage_bar.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:shared_design_system/shared_design_system.dart';

import 'package:testing_real_fonts/testing_real_fonts.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart'
    show RelayFailure, RelayFailureKind;
import 'package:testing_voice_fakes/testing_voice_fakes.dart';

import '../support/contrast.dart';
import '../support/focus_ring.dart';
import '../support/paragraphs.dart';
import '../support/replay_rig.dart';

void main() {
  late StageBloc stage;
  late AgentActivityBloc agents;
  late StreamController<SessionEvent> events;
  late int resets;
  late int silences;
  late int micPresses;
  late ReplayRig replay;
  late VoiceHarness voiceHarness;
  late VoiceSessionBloc voice;
  late OrbPhaseBloc phase;

  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    stage = StageBloc();
    agents = AgentActivityBloc();
    events = StreamController<SessionEvent>.broadcast();
    resets = 0;
    silences = 0;
    micPresses = 0;
    replay = ReplayRig(withJournal: true);
    voiceHarness = VoiceHarness();
    voice = VoiceSessionBloc(voiceHarness.session);
    phase = OrbPhaseBloc(
      speakingThreshold: 0.03,
      resumeSilence: const Duration(seconds: 3),
      maxInterruption: const Duration(seconds: 10),
      stopSpan: const Duration(seconds: 3),
    );
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    unawaited(voice.close());
    unawaited(phase.close());
    unawaited(voiceHarness.session.dispose());
    unawaited(events.close());
    unawaited(stage.close());
    unawaited(agents.close());
    replay.dispose();
    await tester.pump();
  });

  Future<void> pumpBar(WidgetTester tester, {bool realFont = false}) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<StageBloc>.value(value: stage),
            BlocProvider<AgentActivityBloc>.value(value: agents),
            BlocProvider<ReplayBloc>.value(value: replay.bloc),
            BlocProvider<VoiceSessionBloc>.value(value: voice),
            BlocProvider<OrbPhaseBloc>.value(value: phase),
          ],
          // Sans `MaterialApp`, rien ne fournit la police au texte des
          // boutons : le test la pose, comme le fait le thème de l'app.
          child: DefaultTextStyle(
            style: realFont
                ? const TextStyle(
                    fontFamily: realFontFamily,
                    fontFamilyFallback: realFontFallback,
                  )
                : const TextStyle(),
            child: Align(
              alignment: Alignment.topRight,
              child: StageBar(
                onResetPressed: () => resets++,
                onSilencePressed: () => silences++,
                onMicPressed: () => micPresses++,
              ),
            ),
          ),
        ),
      ),
    );
    voice.add(const VoiceSessionSubscribed());
    phase.add(OrbPhaseSourceSubscribed(events.stream));
    agents.add(AgentActivitySourceSubscribed(events.stream));
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, SessionEvent event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  /// Session voix `Active` (frontières fausses), puis laisse les chaînes
  /// asynchrones avancer.
  Future<void> startVoice(WidgetTester tester) async {
    unawaited(voiceHarness.session.start());
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Finder silenceButton() => find.byKey(const Key('silence-button'));
  Finder micButton() => find.byKey(const Key('mic-button'));
  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  Finder indicator() => find.byKey(const Key('act-indicator'));
  FilledButton resetButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('reset-button')));

  group('couleurs de la régie (thème de scène)', () {
    const theme = SceneTheme.dark();

    /// Fond (premier remplissage opaque du visuel, sinon le fond de page) et
    /// bordure du visuel de 34 points d'un contrôle.
    (Color fill, Color border) visualOf(WidgetTester tester, String key) {
      final box = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(DecoratedBox),
              matchRoot: true,
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first;
      final Color fill = box.color ?? theme.background;
      return (
        fill.a == 0 ? theme.background : fill,
        (box.border! as Border).top.color,
      );
    }

    Color textColor(WidgetTester tester, String key) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
            matchRoot: true,
          ),
        )
        .last
        .style!
        .color!;

    void expectGroup(WidgetTester tester) {
      // « Remettre à vide » : texte 4,5:1 et bordure 3:1 sur le fond de page.
      final (Color fill, Color border) = visualOf(
        tester,
        'reset-button-visual',
      );
      expect(
        contrast(textColor(tester, 'reset-button-visual'), fill),
        greaterThanOrEqualTo(4.5),
        reason: 'reset-button texte/fond',
      );
      expect(
        contrast(border, theme.background),
        greaterThanOrEqualTo(3),
        reason: 'reset-button bordure/fond de page',
      );
      // Segments : jamais `inkFaint` (pdr-0088 F12) et texte lisible.
      for (var i = 1; i <= 3; i++) {
        final String key = 'act-segment-$i';
        expect(textColor(tester, key), isNot(theme.inkFaint));
        final Color bg = i == 1
            ? Color.alphaBlend(theme.plasmaGhost, theme.surface)
            : theme.surface;
        expect(
          contrast(textColor(tester, key), bg),
          greaterThanOrEqualTo(4.5),
          reason: '$key texte/fond',
        );
      }
    }

    testWidgets('actifs : texte 4,5:1 et bordure 3:1', (tester) async {
      await pumpBar(tester);
      expectGroup(tester);
    });

    testWidgets('inactifs : texte 4,5:1 et bordure 3:1', (tester) async {
      await pumpBar(tester);
      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 't1',
          state: AgentTaskState.working,
        ),
      );
      expectGroup(tester);
    });
  });

  testWidgets('acte 1 par défaut : « Acte 1/3 · Créer »', (tester) async {
    await pumpBar(tester);

    expect(
      find.descendant(
        of: indicator(),
        matching: findTextIgnoringCase('Acte 1/3 · Créer'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('les segments d\'acte prennent les micro-styles segment et '
      'segmentNo du thème', (tester) async {
    await pumpBar(tester);

    const theme = SceneTheme.dark();
    TextStyle? styleOf(String text) => tester
        .renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const Key('act-segment-1')),
            matching: find.text(text),
          ),
        )
        .text
        .style;
    expect(styleOf('Créer')?.fontSize, theme.micro.segment.fontSize);
    expect(styleOf('01')?.fontSize, theme.micro.segmentNo.fontSize);
    // pdr-0087 / pdr-0088 F1 : échelle du design system (11 px au plus bas).
    expect(theme.micro.segmentNo.fontSize, greaterThanOrEqualTo(11));
  });

  testWidgets(
    'un clic sur l\'indicateur passe à l\'acte suivant, cycliquement',
    (tester) async {
      await pumpBar(tester);

      Future<void> clickAndExpect(String text) async {
        await tester.tap(indicator());
        await tester.pump();
        await tester.pump();
        expect(
          find.descendant(of: indicator(), matching: find.text(text)),
          findsOneWidget,
        );
      }

      await clickAndExpect('Acte 2/3 · Transformer');
      await clickAndExpect('Acte 3/3 · Interagir');
      await clickAndExpect('Acte 1/3 · Créer');
    },
  );

  testWidgets('l\'indicateur suit une remise à zéro du Bloc d\'acte', (
    tester,
  ) async {
    await pumpBar(tester);
    await tester.tap(indicator());
    await tester.pump();
    await tester.pump();

    stage.add(const StageResetRequested());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Acte 1/3'), findsOneWidget);
  });

  group('sélecteur d\'actes en segments (F8, T31)', () {
    Finder segment(int n) => find.byKey(Key('act-segment-$n'));

    String shown(WidgetTester tester, int n) => tester
        .widgetList<Text>(
          find.descendant(
            of: segment(n),
            matching: find.byType(Text),
            matchRoot: true,
          ),
        )
        .map((t) => t.data!)
        .join(' ');

    Color? fill(WidgetTester tester, int n) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: segment(n),
            matching: find.byType(DecoratedBox),
            matchRoot: true,
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .firstWhere((c) => c != null, orElse: () => null);

    Color numberColor(WidgetTester tester, int n) => tester
        .widgetList<Text>(
          find.descendant(
            of: segment(n),
            matching: find.byType(Text),
            matchRoot: true,
          ),
        )
        .first
        .style!
        .color!;

    Future<void> advance(WidgetTester tester) async {
      await tester.tap(indicator());
      await tester.pump();
      await tester.pump();
    }

    testWidgets('acte 1 : « 01 » actif, les deux suivants à venir', (
      tester,
    ) async {
      await pumpBar(tester);

      const theme = SceneTheme.dark();
      expect(shown(tester, 1), '01 Créer');
      expect(shown(tester, 2), '02 Transformer');
      expect(shown(tester, 3), '03 Interagir');
      expect(fill(tester, 1), theme.plasmaGhost);
      expect(fill(tester, 2), isNull);
      expect(fill(tester, 3), isNull);
      expect(numberColor(tester, 1), theme.plasma);
      // F12 : un segment à venir n'est jamais en `inkFaint`.
      expect(numberColor(tester, 2), theme.textSecondary);
      expect(numberColor(tester, 3), theme.textSecondary);
    });

    testWidgets('acte 2 : « 01 ✓ » fait en go, « 02 » actif', (tester) async {
      await pumpBar(tester);
      await advance(tester);

      const theme = SceneTheme.dark();
      expect(shown(tester, 1), '01 ✓ Créer');
      expect(shown(tester, 2), '02 Transformer');
      expect(fill(tester, 1), isNull);
      expect(fill(tester, 2), theme.plasmaGhost);
      expect(numberColor(tester, 1), theme.okForeground);
    });

    testWidgets('acte 3 : deux segments faits, le dernier actif', (
      tester,
    ) async {
      await pumpBar(tester);
      await advance(tester);
      await advance(tester);

      expect(shown(tester, 1), '01 ✓ Créer');
      expect(shown(tester, 2), '02 ✓ Transformer');
      expect(shown(tester, 3), '03 Interagir');
      expect(fill(tester, 3), const SceneTheme.dark().plasmaGhost);
    });

    testWidgets('un seul bouton : cliquer n\'importe quel segment passe à '
        'l\'acte suivant', (tester) async {
      await pumpBar(tester);

      expect(find.byKey(const Key('act-indicator')), findsOneWidget);
      await tester.tap(segment(3));
      await tester.pump();
      await tester.pump();

      expect(stage.state.act, 2);
    });

    testWidgets('texte accessible inchangé : « Acte n/3 · nom »', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester);

      expect(tester.getSemantics(indicator()).label, 'Acte 1/3 · Créer');
      semantics.dispose();
    });

    testWidgets('en rejeu : un seul segment « Acte 4 · Rejeu », non '
        'cliquable', (tester) async {
      await pumpBar(tester);
      replay.bloc.add(const ReplayPlayPressed());
      await tester.pump();
      await tester.pump();

      expect(segment(1), findsNothing);
      expect(segment(2), findsNothing);
      expect(segment(3), findsNothing);
      final Finder single = find.byKey(const Key('act-segment-replay'));
      expect(single, findsOneWidget);
      expect(
        find.descendant(of: single, matching: find.text('Acte 4 · Rejeu')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextButton>(indicator()).onPressed,
        isNull,
        reason: 'non cliquable',
      );
    });
  });

  group('boutons du haut sm (F1, T31)', () {
    void linuxTest(
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) => testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    linuxTest('visuels de 34 points au centre de cibles d\'au moins 48', (
      tester,
    ) async {
      await pumpBar(tester);

      for (final (String target, String visual) in <(String, String)>[
        ('mic-button', 'mic-button-visual'),
        ('silence-button', 'silence-button-visual'),
        ('reset-button', 'reset-button-visual'),
      ]) {
        final Rect t = tester.getRect(find.byKey(Key(target)));
        final Rect v = tester.getRect(find.byKey(Key(visual)));
        expect(v.height, 34, reason: visual);
        expect(t.height, greaterThanOrEqualTo(48), reason: target);
        expect(v.center.dy, closeTo(t.center.dy, 0.5), reason: 'centré');
        expect(t.contains(v.topLeft) && t.contains(v.bottomRight), isTrue);
      }
    });

    linuxTest('le visuel du micro est plein (surface-300), ceux de « Faire '
        'taire » et « Remettre à vide » sont fantômes', (tester) async {
      await pumpBar(tester);

      const theme = SceneTheme.dark();
      BoxDecoration decoration(String key) => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(DecoratedBox),
              matchRoot: true,
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first;

      expect(decoration('mic-button-visual').color, theme.surface300);
      expect(decoration('silence-button-visual').color, isNull);
      expect(decoration('reset-button-visual').color, isNull);
      for (final String key in <String>[
        'mic-button-visual',
        'silence-button-visual',
        'reset-button-visual',
      ]) {
        final BoxDecoration d = decoration(key);
        expect(d.borderRadius, SceneRadius.borderMd, reason: key);
        // pdr-0084 U4 : jamais `line-strong` (2,3:1) comme bordure de bouton.
        expect((d.border! as Border).top.color, theme.textSecondary);
      }
    });

    linuxTest('le point d\'enregistrement n\'existe que micro ouvert', (
      tester,
    ) async {
      await pumpBar(tester);
      final dot = find.byKey(const Key('mic-rec-dot'));

      expect(dot, findsNothing, reason: 'hors session');

      await startVoice(tester);
      expect(dot, findsOneWidget, reason: 'micro ouvert');
      expect(tester.getSize(dot), const Size.square(8));
      final decoration =
          tester.widget<DecoratedBox>(dot).decoration as BoxDecoration;
      expect(decoration.color, const SceneTheme.dark().blockingForeground);
      expect(decoration.shape, BoxShape.circle);

      await voiceHarness.session.setMicMuted(true);
      await tester.pump();
      await tester.pump();
      expect(dot, findsNothing, reason: 'micro coupé');
    });
  });

  testWidgets('« Remettre à vide » appelle onResetPressed, une fois par clic', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('reset-button')),
        matching: find.text('Remettre à vide'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pump();

    expect(resets, 1);
  });

  testWidgets('inactif tant qu\'un agent travaille, actif ensuite', (
    tester,
  ) async {
    await pumpBar(tester);
    expect(resetButton(tester).onPressed, isNotNull);

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.working,
      ),
    );
    expect(resetButton(tester).onPressed, isNull);
    await tester.tap(
      find.byKey(const Key('reset-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(resets, 0);

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.completed,
      ),
    );
    expect(resetButton(tester).onPressed, isNotNull);
  });

  testWidgets('l\'indicateur d\'acte reste cliquable pendant le travail', (
    tester,
  ) async {
    await pumpBar(tester);
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.working,
      ),
    );

    await tester.tap(indicator());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Acte 2/3'), findsOneWidget);
  });

  testWidgets('« Remettre à vide » est inactif quand un agent est en attente', (
    tester,
  ) async {
    await pumpBar(tester);
    expect(resetButton(tester).onPressed, isNotNull);

    events.add(
      PlanReceived(
        delegation: 'deleg_1',
        selected: const <String>['Qualité'],
        idle: const <String>[],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(resetButton(tester).onPressed, isNull);
  });

  testWidgets('en rejeu : « Acte 4 · Rejeu », texte seul non cliquable', (
    tester,
  ) async {
    await pumpBar(tester);
    replay.bloc.add(const ReplayPlayPressed());
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: indicator(),
        matching: findTextIgnoringCase('Acte 4 · Rejeu'),
      ),
      findsOneWidget,
    );
    await tester.tap(indicator());
    await tester.pump();
    await tester.pump();
    expect(stage.state.act, 1, reason: 'le clic ne change plus d\'acte');
    expect(findTextIgnoringCase('Acte 4 · Rejeu'), findsOneWidget);
    final style = tester
        .renderObject<RenderParagraph>(findTextIgnoringCase('Acte 4 · Rejeu'))
        .text
        .style;
    // pdr-0087 / pdr-0088 F1 : échelle du design system (11 px au plus bas), plus de plancher de 24 px.
    expect(style?.fontSize, greaterThanOrEqualTo(11));
  });

  testWidgets('en rejeu : « Remettre à vide » quitte le rejeu, sans reset', (
    tester,
  ) async {
    await pumpBar(tester);
    replay.bloc.add(const ReplayPlayPressed());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pump();
    await tester.pump();

    expect(resets, 0, reason: 'la remise à vide classique ne part pas');
    expect(replay.stage.exits, 1);
    expect(replay.bloc.state, isA<ReplayLive>());
    expect(findTextIgnoringCase('Acte 1/3 · Créer'), findsOneWidget);
  });

  testWidgets('en rejeu : « Remettre à vide » reste actif même si occupé', (
    tester,
  ) async {
    await pumpBar(tester);
    replay.bloc.add(const ReplayPlayPressed());
    await tester.pump();
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.working,
      ),
    );

    expect(resetButton(tester).onPressed, isNotNull);
  });

  testWidgets('en rejeu : un pas du lecteur ne reconstruit pas la barre', (
    tester,
  ) async {
    await pumpBar(tester);
    replay.bloc.add(const ReplayPlayPressed());
    await tester.pump();
    await tester.pump();
    final ReplayState before = replay.bloc.state;
    final Text label = tester.widget<Text>(
      findTextIgnoringCase('Acte 4 · Rejeu'),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(replay.bloc.state, isNot(before), reason: 'la position a avancé');
    expect(
      identical(
        tester.widget<Text>(findTextIgnoringCase('Acte 4 · Rejeu')),
        label,
      ),
      isTrue,
      reason: 'le sous-arbre n\'est pas reconstruit à chaque pas',
    );
  });

  group('cibles de pointage sous Linux (NFR-05, pdr-0033)', () {
    // La démo tourne sous Linux : `flutter_test` simule Android par défaut, ce
    // qui donnerait une cible `padded` et fausserait la mesure.
    void linuxTest(
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) => testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    linuxTest('les deux contrôles font au moins 48 points, de largeur '
        'égale, empilés dans 104 points', (tester) async {
      await pumpBar(tester);

      final act = tester.getRect(indicator());
      final reset = tester.getRect(find.byKey(const Key('reset-button')));
      expect(tester.getSize(indicator()).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.byKey(const Key('reset-button'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(act.width, reset.width);
      expect(act.bottom, lessThanOrEqualTo(reset.top));
      expect(reset.bottom - act.top, lessThanOrEqualTo(104));
    });

    linuxTest('les libellés les plus longs tiennent sans troncature, '
        'en polices réelles', (tester) async {
      await loadRealFonts();
      await pumpBar(tester, realFont: true);
      await tester.tap(indicator());
      await tester.pump();
      await tester.pump();

      expect(findTextIgnoringCase('Acte 2/3 · Transformer'), findsOneWidget);
      expect(paragraphsTruncated(tester), isEmpty);
      expect(tester.takeException(), isNull);

      replay.bloc.add(const ReplayPlayPressed());
      await tester.pump();
      await tester.pump();
      expect(findTextIgnoringCase('Acte 4 · Rejeu'), findsOneWidget);
      expect(paragraphsTruncated(tester), isEmpty);
    });

    linuxTest('chaque contrôle est annoncé par la sémantique', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester);

      expect(
        tester.getSemantics(indicator()).label,
        contains('Acte 1/3 · Créer'),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('reset-button'))).label,
        contains('Remettre à vide'),
      );
      semantics.dispose();
    });

    linuxTest('le sélecteur d\'actes est une pilule surface-100 à bordure '
        'line, dans une cible de 48 points', (tester) async {
      await pumpBar(tester);

      const theme = SceneTheme.dark();
      final pill = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: indicator(),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == theme.surface);
      expect((pill.border! as Border).top.color, theme.line);
      expect(pill.borderRadius, SceneRadius.borderPill);
      expect(
        tester.getRect(indicator()).height,
        greaterThanOrEqualTo(48),
        reason: 'cible',
      );
      final Rect visual = tester.getRect(
        find.descendant(
          of: indicator(),
          matching: find.byKey(const Key('act-segment-1')),
        ),
      );
      expect(visual.height, 34);
    });
  });

  group('Faire taire et micro (014, T13)', () {
    void linuxTest(
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) => testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('hors session : « Faire taire » et le micro sont inactifs', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(
        find.descendant(
          of: silenceButton(),
          matching: find.text('Faire taire'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: micButton(),
          matching: find.text('Couper le micro'),
        ),
        findsOneWidget,
      );
      expect(enabled(tester, silenceButton()), isFalse);
      expect(enabled(tester, micButton()), isFalse);
    });

    testWidgets('session active : les deux boutons appellent la page', (
      tester,
    ) async {
      await pumpBar(tester);
      await startVoice(tester);
      expect(enabled(tester, silenceButton()), isTrue);
      expect(enabled(tester, micButton()), isTrue);

      await tester.tap(silenceButton());
      await tester.tap(micButton());
      await tester.pump();

      expect(silences, 1);
      expect(micPresses, 1);
    });

    testWidgets('micro coupé : le bouton propose de le rétablir', (
      tester,
    ) async {
      await pumpBar(tester);
      await startVoice(tester);
      await voiceHarness.session.setMicMuted(true);
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: micButton(),
          matching: find.text('Rétablir le micro'),
        ),
        findsOneWidget,
      );
      expect(find.text('Couper le micro'), findsNothing);
      expect(enabled(tester, micButton()), isTrue);
    });

    testWidgets('« Faire taire » est inactif tant que l\'orbe est interrompue '
        '(idempotent)', (tester) async {
      await pumpBar(tester);
      await startVoice(tester);
      expect(enabled(tester, silenceButton()), isTrue);

      events.add(const VoiceInterrupted(atMs: 2500));
      await tester.pump();
      await tester.pump();

      expect(phase.state, isA<Interrupted>());
      expect(enabled(tester, silenceButton()), isFalse);
      expect(enabled(tester, micButton()), isTrue);
    });

    testWidgets('session arrêtée : les boutons redeviennent inactifs', (
      tester,
    ) async {
      await pumpBar(tester);
      await startVoice(tester);
      unawaited(voiceHarness.session.stop());
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(enabled(tester, silenceButton()), isFalse);
      expect(enabled(tester, micButton()), isFalse);
    });

    linuxTest('quatre contrôles d\'au moins 48 points, deux colonnes de '
        'largeur égale, dans 104 points', (tester) async {
      await pumpBar(tester);
      await startVoice(tester);

      final act = tester.getRect(indicator());
      final reset = tester.getRect(find.byKey(const Key('reset-button')));
      final mic = tester.getRect(micButton());
      final silence = tester.getRect(silenceButton());
      for (final rect in <Rect>[act, reset, mic, silence]) {
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.width, StageBar.columnWidth);
      }
      expect(mic.top, act.top, reason: 'première ligne');
      expect(silence.top, reset.top, reason: 'seconde ligne');
      expect(mic.right, lessThanOrEqualTo(act.left), reason: 'à gauche');
      expect(silence.right, lessThanOrEqualTo(reset.left));
      expect(silence.bottom - mic.top, lessThanOrEqualTo(104));
      expect(
        tester.getSize(find.byType(StageBar)).width,
        lessThanOrEqualTo(2 * StageBar.columnWidth + 16),
      );
    });

    linuxTest('libellés entiers à 11 px au moins, polices réelles', (
      tester,
    ) async {
      await loadRealFonts();
      await pumpBar(tester, realFont: true);
      await startVoice(tester);
      await voiceHarness.session.setMicMuted(true);
      await tester.pump();
      await tester.pump();

      expect(find.text('Rétablir le micro'), findsOneWidget);
      expect(find.text('Faire taire'), findsOneWidget);
      expect(paragraphsTruncated(tester), isEmpty);
      expect(paragraphsBelowMinimum(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    linuxTest('chaque bouton est annoncé comme bouton par la sémantique', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester);
      await startVoice(tester);

      for (final (finder, label) in <(Finder, String)>[
        (silenceButton(), 'Faire taire'),
        (micButton(), 'Couper le micro'),
      ]) {
        final node = tester.getSemantics(finder);
        expect(node.label, contains(label));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, ui.Tristate.isTrue);
      }
      semantics.dispose();
    });

    /// Barre du haut complète à 1920 × 1080, polices réelles, transcription
    /// branchée sur le flux d'événements.
    Future<void> pumpTopBar(WidgetTester tester) async {
      await loadRealFonts();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final transcript = TranscriptBloc()
        ..add(TranscriptSourceSubscribed(events.stream));
      final level = ValueNotifier<double>(0);
      addTearDown(() {
        unawaited(transcript.close());
        level.dispose();
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<StageBloc>.value(value: stage),
              BlocProvider<AgentActivityBloc>.value(value: agents),
              BlocProvider<ReplayBloc>.value(value: replay.bloc),
              BlocProvider<VoiceSessionBloc>.value(value: voice),
              BlocProvider<OrbPhaseBloc>.value(value: phase),
              BlocProvider<TranscriptBloc>.value(value: transcript),
            ],
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: realFontFamily,
                fontFamilyFallback: realFontFallback,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: TopBar(
                    orbLevel: level,
                    stage: StageBar(
                      onResetPressed: () {},
                      onSilencePressed: () {},
                      onMicPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      voice.add(const VoiceSessionSubscribed());
    }

    linuxTest('dans la barre du haut à 1920 × 1080, rien ne déborde, '
        'orbe voilé compris', (tester) async {
      await pumpTopBar(tester);
      await startVoice(tester);
      await voiceHarness.session.setMicMuted(true);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TopBar)).height, TopBar.height);
      expect(find.text('Micro coupé'), findsOneWidget);
      expect(paragraphsTruncated(tester), isEmpty);
      final Rect stageRect = tester.getRect(find.byType(StageBar));
      final Rect stop = tester.getRect(find.byKey(const Key('stop-button')));
      expect(stageRect.right, lessThanOrEqualTo(stop.left));
      expect(
        stageRect.left,
        greaterThan(tester.getRect(find.text('Micro coupé')).right),
      );
    });

    linuxTest('transcription longue et message d\'état : la régie à quatre '
        'boutons ne fait pas déborder la zone de texte', (tester) async {
      await pumpTopBar(tester);
      voiceHarness.relay.createHook = (_) async =>
          throw const RelayFailure(RelayFailureKind.unreachable);
      unawaited(voiceHarness.session.start());
      events
        ..add(
          TranscriptDelta(
            role: TranscriptRole.user,
            text: 'Prépare la release trois point quatre ' * 12,
            startMs: 0,
            endMs: 1,
          ),
        )
        ..add(
          TranscriptDelta(
            role: TranscriptRole.ai,
            text: 'Je lance les trois agents sur la release ' * 12,
            startMs: 2,
            endMs: 3,
          ),
        );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      expect(find.byKey(const Key('status-message')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(paragraphsBelowMinimum(tester), isEmpty);
    });
  });

  group('focus clavier visible (pdr-0084 U4)', () {
    testWidgets('mic-button, silence-button et reset-button : anneau signal '
        'de 2 points au focus', (tester) async {
      await pumpBar(tester);
      await startVoice(tester);

      for (final String id in <String>[
        'mic-button',
        'silence-button',
        'reset-button',
        'act-indicator',
      ]) {
        final Key child = id == 'act-indicator'
            ? const Key('act-segment-1')
            : Key('$id-visual');
        await expectFocusRing(tester, Key(id), child);
      }
    });

    testWidgets('act-indicator désactivé en rejeu : pas de focus, pas '
        'd\'anneau', (tester) async {
      await pumpBar(tester);
      replay.bloc.add(const ReplayPlayPressed());
      await tester.pump();
      await tester.pump();

      Focus.of(tester.element(find.byKey(const Key('act-segment-replay'))))
          .requestFocus();
      await tester.pump();
      expect(paintedSide(tester, const Key('act-indicator')), BorderSide.none);
    });
  });
}
