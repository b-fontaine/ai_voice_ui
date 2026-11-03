import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/agents_rail/agents_rail.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/paragraphs.dart';

/// Habillage du rail aux jetons du design system (spec 019, T30, V-06) :
/// étiquette, tuiles et trois états (orchestrateur, au travail, terminé).
void main() {
  const SceneTheme theme = SceneTheme.dark();
  late AgentActivityBloc bloc;
  late StreamController<SessionEvent> events;

  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bloc = AgentActivityBloc();
    events = StreamController<SessionEvent>.broadcast();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BlocProvider<AgentActivityBloc>.value(
          value: bloc,
          child: const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 1872, height: 96, child: AgentsRail()),
          ),
        ),
      ),
    );
    bloc.add(AgentActivitySourceSubscribed(events.stream));
    await tester.pump();
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
    unawaited(bloc.close());
    await tester.pump();
  });

  Future<void> emit(WidgetTester tester, SessionEvent event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  Future<void> plan(WidgetTester tester) => emit(
    tester,
    PlanReceived(
      delegation: 'd1',
      selected: const <String>['Voix du client', 'Qualité', 'Livraison'],
      idle: const <String>['Conformité'],
    ),
  );

  Finder key(String name) => find.byKey(Key(name));

  // Première décoration de boîte de l'élément (lui-même ou le premier dedans).
  BoxDecoration decoration(String name) {
    final Finder box = find.descendant(
      of: key(name),
      matching: find.byType(DecoratedBox),
      matchRoot: true,
    );
    return (box.evaluate().first.widget as DecoratedBox).decoration
        as BoxDecoration;
  }

  Color borderOf(String tile) => (decoration(tile).border! as Border).top.color;

  testWidgets('étiquette « Agents A2A » en capitales, ink-muted, à gauche', (
    tester,
  ) async {
    await plan(tester);
    final Finder label = key('agents-rail-label');
    expect(label, findsOneWidget);
    final Text text = tester.widget<Text>(
      find.descendant(of: label, matching: find.byType(Text)),
    );
    expect(text.data, 'AGENTS A2A');
    expect(text.style?.color, theme.textSecondary);
    expect(
      tester.getRect(label).right,
      lessThanOrEqualTo(tester.getRect(key('agent-tile-Orchestrateur')).left),
    );
  });

  testWidgets('chaque tuile : coins md, bordure de 1 px, fond surface-100', (
    tester,
  ) async {
    await plan(tester);
    for (final String n in <String>['Orchestrateur', 'Voix du client']) {
      final BoxDecoration d = decoration('agent-tile-$n');
      expect(d.borderRadius, SceneRadius.borderMd, reason: n);
      expect((d.border! as Border).top.width, 1, reason: n);
      expect(d.color, theme.surface, reason: n);
    }
    // La tuile est celle du rectangle de la ligne (liaisons de 015).
    expect(
      tester.getRect(key('agent-tile-Qualité')),
      tester.getRect(key('agent-Qualité')),
    );
  });

  testWidgets('orchestrateur : bordure plasma, point plasma avec lueur', (
    tester,
  ) async {
    await plan(tester);
    final Color border = borderOf('agent-tile-Orchestrateur');
    expect(border.withValues(alpha: 1), theme.plasma);
    expect(border.a, closeTo(0.33, 0.02));
    final BoxDecoration dot = decoration('agent-dot-Orchestrateur');
    expect(dot.color, theme.plasma);
    expect(dot.boxShadow, isNotEmpty);
    expect(dot.boxShadow!.first.color.withValues(alpha: 1), theme.plasma);
    expect(
      tester.getSize(key('agent-dot-Orchestrateur')),
      const Size.square(8),
    );
    expect(key('agent-bar-Orchestrateur'), findsNothing);
  });

  testWidgets('au travail : bordure, point, état et barre en signal', (
    tester,
  ) async {
    await plan(tester);
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't',
        state: AgentTaskState.working,
        label: 'Analyse',
      ),
    );
    final Color border = borderOf('agent-tile-Qualité');
    expect(border.withValues(alpha: 1), theme.accent);
    expect(border.a, closeTo(0.4, 0.02));
    expect(decoration('agent-dot-Qualité').color, theme.agentWorking);
    final Text state = tester.widget<Text>(
      find.descendant(
        of: key('agent-state-Qualité'),
        matching: find.text('en cours'),
      ),
    );
    expect(state.style?.color, theme.accent);
    final Finder bar = key('agent-bar-Qualité');
    expect(bar, findsOneWidget);
    expect(tester.getSize(bar).height, 2);
    final Rect tile = tester.getRect(key('agent-tile-Qualité'));
    expect(tester.getSize(bar).width, closeTo(tile.width * 0.4, 1));
    expect(tester.getRect(bar).bottom, tile.bottom - 1);
    expect(key('agent-bar-Voix du client'), findsNothing);
  });

  testWidgets('terminé : point go, état ink-muted avec ✓ go, plus de barre', (
    tester,
  ) async {
    await plan(tester);
    for (final AgentTaskState s in <AgentTaskState>[
      AgentTaskState.working,
      AgentTaskState.completed,
    ]) {
      await emit(
        tester,
        AgentActivityReceived(agent: 'Qualité', task: 't', state: s),
      );
    }
    expect(decoration('agent-dot-Qualité').color, theme.okForeground);
    final Finder state = key('agent-state-Qualité');
    expect(
      find.descendant(of: state, matching: find.text('terminé')),
      findsOneWidget,
    );
    final Text word = tester.widget<Text>(
      find.descendant(of: state, matching: find.text('terminé')),
    );
    expect(word.style?.color, theme.textSecondary);
    final Text tick = tester.widget<Text>(
      find.descendant(of: state, matching: find.text('✓')),
    );
    expect(tick.style?.color, theme.okForeground);
    expect(key('agent-bar-Qualité'), findsNothing);
    expect(borderOf('agent-tile-Qualité'), theme.line);
  });

  testWidgets(
    'les autres états gardent leur libellé et l\'habillage aux jetons',
    (tester) async {
      await plan(tester);
      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 't',
          state: AgentTaskState.rejected,
          detail: 'hors périmètre',
        ),
      );
      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Livraison',
          task: 't2',
          state: AgentTaskState.failed,
          detail: 'délai dépassé',
        ),
      );
      for (final (String, String) c in <(String, String)>[
        ('Voix du client', 'en attente'),
        ('Qualité', 'hors périmètre'),
        ('Livraison', 'échec'),
        ('Conformité', 'en veille'),
      ]) {
        final Finder state = key('agent-state-${c.$1}');
        final Text word = tester.widget<Text>(
          find.descendant(of: state, matching: find.text(c.$2)),
        );
        expect(word.style?.color, theme.textSecondary, reason: c.$1);
        expect(borderOf('agent-tile-${c.$1}'), theme.line, reason: c.$1);
        expect(key('agent-bar-${c.$1}'), findsNothing, reason: c.$1);
      }
      expect(decoration('agent-dot-Conformité').color, theme.agentIdle);
      expect(decoration('agent-dot-Livraison').color, theme.blockingForeground);
    },
  );

  testWidgets('ordre fixe, rail de 96 px, noms jamais abrégés', (tester) async {
    await loadRealFonts(alsoAs: const <String>['Roboto']);
    await plan(tester);
    expect(tester.getSize(key('agents-rail')).height, 96);
    final List<double> lefts = <double>[
      for (final String n in <String>[
        'Orchestrateur',
        'Voix du client',
        'Qualité',
        'Livraison',
        'Conformité',
      ])
        tester.getRect(key('agent-tile-$n')).left,
    ];
    expect(lefts, orderedEquals(<double>[...lefts]..sort()));
    expect(tester.getSize(key('agent-tile-Qualité')).height, lessThan(80));
    final List<String> truncated = paragraphsTruncated(tester);
    for (final String n in <String>[
      'Orchestrateur',
      'Voix du client',
      'Qualité',
      'Livraison',
      'Conformité',
    ]) {
      expect(truncated, isNot(contains('« $n »')));
    }
    expect(paragraphsBelowMinimum(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
