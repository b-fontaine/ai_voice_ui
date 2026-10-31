import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:feature_stage_controls/feature_stage_controls.dart';
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
import 'package:shared_design_system/shared_design_system.dart';

import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/replay_rig.dart';

void main() {
  late StageBloc stage;
  late AgentActivityBloc agents;
  late StreamController<SessionEvent> events;
  late int resets;
  late ReplayRig replay;

  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    stage = StageBloc();
    agents = AgentActivityBloc();
    events = StreamController<SessionEvent>.broadcast();
    resets = 0;
    replay = ReplayRig(withJournal: true);
    await body(tester);
    await tester.pumpWidget(const SizedBox());
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
              child: StageBar(onResetPressed: () => resets++),
            ),
          ),
        ),
      ),
    );
    agents.add(AgentActivitySourceSubscribed(events.stream));
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, SessionEvent event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  Finder indicator() => find.byKey(const Key('act-indicator'));
  FilledButton resetButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('reset-button')));

  testWidgets('acte 1 par défaut : « Acte 1/3 · Créer »', (tester) async {
    await pumpBar(tester);

    expect(
      find.descendant(of: indicator(), matching: find.text('Acte 1/3 · Créer')),
      findsOneWidget,
    );
  });

  testWidgets('l\'indicateur d\'acte prend le style actIndicator du thème', (
    tester,
  ) async {
    await pumpBar(tester);

    final style = tester
        .renderObject<RenderParagraph>(find.text('Acte 1/3 · Créer'))
        .text
        .style;
    expect(style?.fontSize, const SceneTheme.dark().actIndicator.fontSize);
    expect(style?.fontSize, greaterThanOrEqualTo(24));
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
      find.descendant(of: indicator(), matching: find.text('Acte 4 · Rejeu')),
      findsOneWidget,
    );
    await tester.tap(indicator());
    await tester.pump();
    await tester.pump();
    expect(stage.state.act, 1, reason: 'le clic ne change plus d\'acte');
    expect(find.text('Acte 4 · Rejeu'), findsOneWidget);
    final style = tester
        .renderObject<RenderParagraph>(find.text('Acte 4 · Rejeu'))
        .text
        .style;
    expect(style?.fontSize, greaterThanOrEqualTo(24));
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
    expect(find.text('Acte 1/3 · Créer'), findsOneWidget);
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
    final Text label = tester.widget<Text>(find.text('Acte 4 · Rejeu'));

    await tester.pump(const Duration(milliseconds: 300));

    expect(replay.bloc.state, isNot(before), reason: 'la position a avancé');
    expect(
      identical(tester.widget<Text>(find.text('Acte 4 · Rejeu')), label),
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

      expect(find.text('Acte 2/3 · Transformer'), findsOneWidget);
      expect(paragraphsTruncated(tester), isEmpty);
      expect(tester.takeException(), isNull);

      replay.bloc.add(const ReplayPlayPressed());
      await tester.pump();
      await tester.pump();
      expect(find.text('Acte 4 · Rejeu'), findsOneWidget);
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

    linuxTest('le contrôle d\'acte a une bordure et un contraste de scène', (
      tester,
    ) async {
      await pumpBar(tester);

      final button = tester.widget<TextButton>(indicator());
      final side = button.style?.side?.resolve(<WidgetState>{});
      expect(side, isNotNull, reason: 'bordure explicite');
      expect(side!.color, const SceneTheme.dark().accent);
    });
  });
}
