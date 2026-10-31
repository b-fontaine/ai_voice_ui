import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/agents_rail/agents_rail.dart';
import 'package:genesis_canvas/widgets/agents_rail/delegation_link_painter.dart';
import 'package:genesis_canvas/widgets/agents_rail/delegation_links.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/paragraphs.dart';

void main() {
  late AgentActivityBloc bloc;
  late StreamController<SessionEvent> events;

  // Créés dans la zone du test (FakeAsync) : sinon les microtâches du Bloc
  // échappent à `pump`.
  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    // Écran de la démo : le rail dispose de 1872 px (1920 - 2 × 24).
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bloc = AgentActivityBloc();
    events = StreamController<SessionEvent>.broadcast();
    await body(tester);
    // Démontage puis fermeture, vidée par `pump` (zone FakeAsync).
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
    unawaited(bloc.close());
    await tester.pump();
  });

  Widget railHost({bool disabled = false, double speed = 1}) => Directionality(
    textDirection: TextDirection.ltr,
    child: SceneMotionScope(
      disabled: disabled,
      speed: speed,
      child: BlocProvider<AgentActivityBloc>.value(
        value: bloc,
        child: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 1872, height: 96, child: AgentsRail()),
        ),
      ),
    ),
  );

  Future<void> pumpRail(
    WidgetTester tester, {
    bool disabled = false,
    double speed = 1,
  }) async {
    await tester.pumpWidget(railHost(disabled: disabled, speed: speed));
    bloc.add(AgentActivitySourceSubscribed(events.stream));
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, SessionEvent event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  Finder row(String agent) => find.byKey(Key('agent-$agent'));

  testWidgets('le rail porte la clé agents-rail et reste vide sans agent', (
    tester,
  ) async {
    await pumpRail(tester);

    expect(find.byKey(const Key('agents-rail')), findsOneWidget);
    // Seul le repère de zone est affiché ; aucune tuile.
    expect(find.text('AGENTS A2A'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text), findsOneWidget);
  });

  testWidgets(
    'le rail fait 96 px de haut et toute la largeur, vide ou rempli',
    (tester) async {
      await pumpRail(tester);
      final Size empty = tester.getSize(find.byKey(const Key('agents-rail')));
      expect(empty, const Size(1872, 96));

      await emit(
        tester,
        PlanReceived(
          delegation: 'd1',
          selected: const <String>['Qualité', 'Voix du client'],
          idle: const <String>['Livraison'],
        ),
      );
      expect(tester.getSize(find.byKey(const Key('agents-rail'))), empty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tuiles à droite du repère, dans l\'ordre, sur une rangée', (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd1',
        selected: const <String>['Qualité'],
        idle: const <String>['Livraison'],
      ),
    );
    final Rect title = tester.getRect(find.text('AGENTS A2A'));
    final List<Rect> tiles = <Rect>[
      for (final String n in <String>['Orchestrateur', 'Qualité', 'Livraison'])
        tester.getRect(row(n)),
    ];
    for (final Rect t in tiles) {
      expect(t.left, greaterThanOrEqualTo(title.right));
      expect(t.top, tiles.first.top);
      expect(t.height, lessThanOrEqualTo(96));
    }
    expect(tiles[1].left, greaterThanOrEqualTo(tiles[0].right));
    expect(tiles[2].left, greaterThanOrEqualTo(tiles[1].right));
  });

  testWidgets('cinq tuiles au pire cas : polices réelles, rien de tronqué '
      'sauf la tâche, aucun débordement', (tester) async {
    await loadRealFonts(alsoAs: const <String>['Roboto']);
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd1',
        selected: const <String>['Voix du client', 'Qualité', 'Livraison'],
        idle: const <String>['Conformité'],
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Voix du client',
        task: 't1',
        state: AgentTaskState.working,
        label: 'Analyse des avis des utilisateurs',
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't2',
        state: AgentTaskState.rejected,
        detail: 'hors périmètre',
      ),
    );

    expect(find.byKey(const Key('agent-Orchestrateur')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(paragraphsBelowMinimum(tester), isEmpty);
    // Le nom, l'état et le repère ne sont jamais tronqués.
    final List<String> truncated = paragraphsTruncated(tester);
    expect(truncated, isNot(contains('« Voix du client »')));
    expect(truncated, isNot(contains('« hors périmètre »')));
    expect(truncated, isNot(contains('« en cours »')));
    expect(truncated, isNot(contains('« Orchestrateur »')));
    expect(truncated, isNot(contains('« AGENTS A2A »')));
    // La tâche reste affichée (même abrégée) : son texte est dans l'arbre.
    expect(
      find.descendant(
        of: row('Voix du client'),
        matching: find.textContaining('Analyse des avis', findRichText: true),
      ),
      findsOneWidget,
    );
    // Chaque tuile reste dans la largeur du rail.
    for (final String n in <String>[
      'Orchestrateur',
      'Voix du client',
      'Qualité',
      'Livraison',
      'Conformité',
    ]) {
      final Rect r = tester.getRect(row(n));
      expect(r.right, lessThanOrEqualTo(1872), reason: n);
      expect(r.height, lessThanOrEqualTo(96), reason: n);
    }
  });

  testWidgets('un agent au travail puis terminé', (tester) async {
    await pumpRail(tester);

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'analyse',
        state: AgentTaskState.working,
        label: 'Analyse de la release',
      ),
    );
    expect(
      find.descendant(of: row('Qualité'), matching: find.text('en cours')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('Qualité'), matching: find.text('Qualité')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row('Qualité'),
        matching: find.text('Analyse de la release'),
      ),
      findsOneWidget,
    );

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'analyse',
        state: AgentTaskState.completed,
      ),
    );
    expect(
      find.descendant(of: row('Qualité'), matching: find.text('terminé')),
      findsOneWidget,
    );
    expect(find.text('en cours'), findsNothing);
  });

  testWidgets(
    'la couleur du point vient des jetons du thème de scène (RG-09)',
    (tester) async {
      await pumpRail(tester);
      const theme = SceneTheme.dark();
      Color? dot(String agent) => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: row(agent),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => (b.decoration as BoxDecoration).color)
          .first;

      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 'analyse',
          state: AgentTaskState.working,
        ),
      );
      expect(dot('Qualité'), theme.agentWorking);

      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 'analyse',
          state: AgentTaskState.completed,
        ),
      );
      expect(dot('Qualité'), theme.okForeground);
      // L'état reste dit en toutes lettres : la couleur n'est qu'un renfort.
      expect(
        find.descendant(of: row('Qualité'), matching: find.text('terminé')),
        findsOneWidget,
      );
    },
  );

  testWidgets('un échec affiche son détail', (tester) async {
    await pumpRail(tester);

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Risques',
        task: 'scan',
        state: AgentTaskState.failed,
        detail: 'délai dépassé',
      ),
    );

    final texts = find.descendant(
      of: row('Risques'),
      matching: find.byType(Text),
    );
    expect(
      tester.widgetList<Text>(texts).map((t) => t.data),
      contains('échec'),
    );
    expect(
      find.descendant(
        of: row('Risques'),
        matching: find.textContaining('délai dépassé'),
      ),
      findsOneWidget,
    );
  });

  testWidgets("fin de session : l'agent au travail devient interrompu", (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'analyse',
        state: AgentTaskState.working,
      ),
    );

    await emit(tester, const ChannelLost('connection_lost'));

    expect(
      find.descendant(of: row('Qualité'), matching: find.text('interrompu')),
      findsOneWidget,
    );
  });

  testWidgets('deux agents : deux lignes', (tester) async {
    await pumpRail(tester);
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'a',
        state: AgentTaskState.working,
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Risques',
        task: 'b',
        state: AgentTaskState.working,
      ),
    );

    expect(row('Qualité'), findsOneWidget);
    expect(row('Risques'), findsOneWidget);
  });

  testWidgets(
    'un plan affiche orchestrateur, agent retenu et agents en veille',
    (tester) async {
      await pumpRail(tester);
      await emit(
        tester,
        PlanReceived(
          delegation: 'd1',
          selected: const <String>['Voix du client'],
          idle: const <String>['Qualité', 'Livraison'],
        ),
      );
      expect(row('Orchestrateur'), findsOneWidget);
      expect(
        find.descendant(
          of: row('Voix du client'),
          matching: find.text('en attente'),
        ),
        findsOneWidget,
      );
      for (final String name in <String>['Qualité', 'Livraison']) {
        expect(
          find.descendant(of: row(name), matching: find.text('en veille')),
          findsOneWidget,
        );
      }
      expect(find.text('aucun agent retenu'), findsNothing);

      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Voix du client',
          task: 't',
          state: AgentTaskState.working,
        ),
      );
      expect(
        find.descendant(
          of: row('Voix du client'),
          matching: find.text('en cours'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('un plan vide affiche « aucun agent retenu »', (tester) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd',
        selected: const <String>[],
        idle: const <String>['Qualité'],
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('agents-rail')),
        matching: find.text('aucun agent retenu'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('agents-none')), findsOneWidget);
  });

  testWidgets('un agent qui refuse est « hors périmètre » avec son détail', (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd',
        selected: const <String>['Qualité'],
        idle: const <String>[],
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't',
        state: AgentTaskState.rejected,
        detail: 'hors périmètre',
      ),
    );
    expect(
      find.descendant(
        of: row('Qualité'),
        matching: find.text('hors périmètre'),
      ),
      findsOneWidget, // le détail identique au libellé n'est pas répété
    );
  });

  testWidgets('tout le texte du rail fait au moins 24 px et reste lisible', (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd1',
        selected: const <String>['Qualité', 'Voix du client'],
        idle: const <String>['Livraison'],
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.working,
        label: 'Analyse de la release',
      ),
    );

    expect(paragraphsBelowMinimum(tester), isEmpty);
    const theme = SceneTheme.dark();
    final Text name = tester.widget<Text>(
      find.descendant(of: row('Qualité'), matching: find.text('Qualité')),
    );
    expect(name.style?.color, theme.textPrimary);
  });

  testWidgets('un nom d\'agent de 80 caractères s\'abrège sans déborder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRail(tester);
    final String name = 'Agent${' très long'.padRight(75, 'x')}';
    expect(name, hasLength(80));
    await emit(
      tester,
      AgentActivityReceived(
        agent: name,
        task: 't1',
        state: AgentTaskState.working,
        label: 'Analyse de la release',
      ),
    );

    expect(tester.takeException(), isNull);
    final Text shown = tester.widget<Text>(
      find.descendant(of: row(name), matching: find.text(name)),
    );
    expect(shown.overflow, TextOverflow.ellipsis);
    expect(shown.maxLines, 1);
    expect(paragraphsBelowMinimum(tester), isEmpty);
  });

  testWidgets('un détail très long s\'abrège sans déborder', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRail(tester);
    await emit(
      tester,
      AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.failed,
        label: 'Analyse de la release ${'très longue ' * 20}',
        detail: 'délai dépassé ${'encore ' * 30}',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(row('Qualité'), findsOneWidget);
  });

  group('liaison de délégation (Q-85)', () {
    Finder link(String agent) => find.byKey(Key('delegation-link-$agent'));
    final Finder anyLink = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('delegation-link-'),
    );

    Future<void> plan(
      WidgetTester tester, {
      List<String> selected = const <String>['Qualité', 'Voix du client'],
      List<String> idle = const <String>['Livraison'],
    }) => emit(
      tester,
      PlanReceived(delegation: 'd1', selected: selected, idle: idle),
    );

    Future<void> activity(
      WidgetTester tester,
      String agent,
      AgentTaskState state,
    ) => emit(
      tester,
      AgentActivityReceived(agent: agent, task: 't-$agent', state: state),
    );

    testWidgets('L-01 : une liaison par agent en attente ou en cours', (
      tester,
    ) async {
      await pumpRail(tester);
      await plan(tester);
      await activity(tester, 'Qualité', AgentTaskState.working);
      await tester.pump();

      expect(link('Qualité'), findsOneWidget);
      expect(link('Voix du client'), findsOneWidget, reason: 'en attente');
      expect(link('Livraison'), findsNothing, reason: 'en veille');
      expect(link('Orchestrateur'), findsNothing);
      expect(anyLink, findsNWidgets(2));
    });

    for (final (String label, AgentTaskState state)
        in <(String, AgentTaskState)>[
          ('terminé', AgentTaskState.completed),
          ('échec', AgentTaskState.failed),
          ('hors périmètre', AgentTaskState.rejected),
          ('interrompu', AgentTaskState.canceled),
        ]) {
      testWidgets('L-02 : la liaison disparaît quand l\'agent est $label', (
        tester,
      ) async {
        await pumpRail(tester);
        await plan(tester);
        await activity(tester, 'Qualité', AgentTaskState.working);
        await tester.pump();
        expect(link('Qualité'), findsOneWidget);

        await activity(tester, 'Qualité', state);
        await tester.pump();

        expect(link('Qualité'), findsNothing);
        expect(link('Voix du client'), findsOneWidget);
      });
    }

    testWidgets('L-02 : un plan vide ne laisse aucune liaison', (tester) async {
      await pumpRail(tester);
      await plan(tester);
      await tester.pump();
      expect(anyLink, findsNWidgets(2));

      await plan(
        tester,
        selected: const <String>[],
        idle: const <String>['Qualité'],
      );
      await tester.pump();

      expect(find.byKey(const Key('agents-none')), findsOneWidget);
      expect(anyLink, findsNothing);
    });

    testWidgets('sans plan, rien à relier', (tester) async {
      await pumpRail(tester);
      await tester.pump();
      expect(anyLink, findsNothing);
    });

    testWidgets('la clé de la tuile reste sur la colonne de l\'agent', (
      tester,
    ) async {
      await pumpRail(tester);
      await plan(tester);
      await tester.pump();
      expect(row('Qualité'), findsOneWidget);
      expect(tester.widget(row('Qualité')), isA<Column>());
    });

    testWidgets('la liaison part de l\'orchestrateur et arrive à la tuile', (
      tester,
    ) async {
      await pumpRail(tester);
      await plan(tester);
      await tester.pump();

      final Rect orchestrator = tester.getRect(row('Orchestrateur'));
      final Rect target = tester.getRect(row('Voix du client'));
      final Rect mark = tester.getRect(link('Voix du client'));
      // Le repère contient le tracé : de la pastille de l'orchestrateur à
      // celle de l'agent, au-dessus des tuiles.
      expect(mark.left, lessThanOrEqualTo(orchestrator.left + 7));
      expect(mark.right, greaterThanOrEqualTo(target.left + 7));
      expect(mark.bottom, lessThanOrEqualTo(orchestrator.top));
      expect(mark.top, greaterThanOrEqualTo(0));
    });

    testWidgets('l\'arc le plus long ne recouvre aucun libellé du rail', (
      tester,
    ) async {
      await loadRealFonts(alsoAs: const <String>['Roboto']);
      await pumpRail(tester);
      await plan(
        tester,
        selected: const <String>['Voix du client', 'Qualité', 'Livraison'],
        idle: const <String>['Conformité'],
      );
      await activity(tester, 'Livraison', AgentTaskState.working);
      await tester.pump();

      final Rect farthest = tester.getRect(link('Livraison'));
      final Rect middle = tester.getRect(row('Qualité'));
      expect(farthest.left, lessThan(middle.left));
      expect(farthest.right, greaterThan(middle.right));
      final List<RenderParagraph> paragraphs = tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .toList();
      expect(paragraphs, isNotEmpty);
      for (final String agent in <String>[
        'Voix du client',
        'Qualité',
        'Livraison',
      ]) {
        final Rect mark = tester.getRect(link(agent));
        for (final RenderParagraph p in paragraphs) {
          final Rect text = p.localToGlobal(Offset.zero) & p.size;
          expect(
            mark.overlaps(text),
            isFalse,
            reason: '$agent recouvre « ${p.text.toPlainText()} »',
          );
        }
        // Le trait tient dans les 16,8 px libres au-dessus des tuiles.
        expect(mark.top, greaterThanOrEqualTo(0));
        expect(mark.bottom, lessThanOrEqualTo(tester.getRect(row(agent)).top));
      }
    });

    testWidgets('un redimensionnement déplace les liaisons avec les tuiles', (
      tester,
    ) async {
      await pumpRail(tester);
      await plan(tester);
      await tester.pump();
      final Rect before = tester.getRect(link('Voix du client'));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BlocProvider<AgentActivityBloc>.value(
            value: bloc,
            child: const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 1200, height: 96, child: AgentsRail()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final Rect after = tester.getRect(link('Voix du client'));
      expect(after.right, lessThan(before.right));
      expect(
        after.right,
        closeTo(tester.getRect(row('Voix du client')).left + 7 + 1.5, 0.01),
        reason: 'le trait arrive au-dessus de la pastille de la tuile',
      );
    });

    group('animation (T12b)', () {
      DelegationLinkPainter painter(WidgetTester tester) => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<DelegationLinkPainter>()
          .single;

      Future<void> twoLinks(WidgetTester tester) async {
        await plan(tester);
        await tester.pump();
      }

      testWidgets('L-03 témoin : la phase avance, la boucle recommence', (
        tester,
      ) async {
        await pumpRail(tester);
        await twoLinks(tester);
        expect(tester.binding.hasScheduledFrame, isTrue);
        final double start = painter(tester).phase.value;
        await tester.pump(const Duration(milliseconds: 130));
        final double later = painter(tester).phase.value;
        expect(later, isNot(start));
        expect(later - start, closeTo(130 / 1200, 0.001));
        await tester.pump(const Duration(milliseconds: 1100));
        expect(painter(tester).phase.value, lessThan(later), reason: 'boucle');
      });

      testWidgets('la vitesse de rejeu s\'applique à la période', (
        tester,
      ) async {
        await pumpRail(tester, speed: 2);
        await twoLinks(tester);
        final double start = painter(tester).phase.value;
        await tester.pump(const Duration(milliseconds: 150));
        expect(painter(tester).phase.value - start, closeTo(0.25, 0.001));
      });

      testWidgets('L-03 : animations coupées, phase fixe, aucun frame', (
        tester,
      ) async {
        await pumpRail(tester, disabled: true);
        await twoLinks(tester);
        await tester.pump();
        expect(anyLink, findsNWidgets(2), reason: 'la liaison reste');
        final double phase = painter(tester).phase.value;
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pump(const Duration(milliseconds: 500));
        expect(painter(tester).phase.value, phase);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('bascule de disabled en cours de route', (tester) async {
        await pumpRail(tester);
        await twoLinks(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.binding.hasScheduledFrame, isTrue);

        await tester.pumpWidget(railHost(disabled: true));
        await tester.pump();
        final double frozen = painter(tester).phase.value;
        await tester.pump(const Duration(milliseconds: 500));
        expect(painter(tester).phase.value, frozen);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(anyLink, findsNWidgets(2));

        await tester.pumpWidget(railHost());
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump(const Duration(milliseconds: 200));
        expect(painter(tester).phase.value, isNot(frozen));
      });

      testWidgets('aucun frame planifié sans lien', (tester) async {
        await pumpRail(tester);
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);

        await plan(
          tester,
          selected: const <String>[],
          idle: const <String>['Qualité'],
        );
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('le dernier lien disparu, l\'animation s\'arrête', (
        tester,
      ) async {
        await pumpRail(tester);
        await plan(
          tester,
          selected: const <String>['Qualité'],
          idle: const <String>[],
        );
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isTrue);

        await activity(tester, 'Qualité', AgentTaskState.completed);
        await tester.pump();
        await tester.pump();
        expect(anyLink, findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('un lien qui revient relance l\'animation', (tester) async {
        await pumpRail(tester);
        await plan(
          tester,
          selected: const <String>['Qualité'],
          idle: const <String>[],
        );
        await activity(tester, 'Qualité', AgentTaskState.completed);
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);

        await activity(tester, 'Qualité', AgentTaskState.working);
        await tester.pump();
        expect(anyLink, findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isTrue);
      });

      testWidgets('10 images d\'animation ne reconstruisent aucune tuile', (
        tester,
      ) async {
        await pumpRail(tester);
        await twoLinks(tester);
        await tester.pump();

        final Map<Type, int> rebuilt = <Type, int>{};
        debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
          rebuilt.update(
            element.widget.runtimeType,
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        };
        addTearDown(() => debugOnRebuildDirtyWidget = null);
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        debugOnRebuildDirtyWidget = null;

        expect(
          rebuilt[Text],
          isNull,
          reason: 'les tuiles ne sont pas refaites',
        );
        expect(rebuilt[Row], isNull);
        expect(rebuilt[DelegationLinks], isNull);
        expect(rebuilt[LayoutBuilder], isNull);
        expect(rebuilt[CustomPaint], isNull);
      });

      testWidgets('repeinture isolée autour du seul tracé', (tester) async {
        await pumpRail(tester);
        await twoLinks(tester);
        final Finder paint = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DelegationLinkPainter,
        );
        expect(
          find.ancestor(of: paint, matching: find.byType(RepaintBoundary)),
          findsWidgets,
        );
        expect(
          (tester.widget(
            find
                .ancestor(of: paint, matching: find.byType(RepaintBoundary))
                .first,
          ) as RepaintBoundary).child,
          paint.evaluate().single.widget,
        );
        expect(
          find.descendant(
            of: find.byType(RepaintBoundary),
            matching: find.text('AGENTS A2A'),
          ),
          findsNothing,
          reason: 'les tuiles ne sont pas sous la frontière du tracé',
        );
      });

      testWidgets('un démontage libère le contrôleur', (tester) async {
        await pumpRail(tester);
        await twoLinks(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    });

    testWidgets('les clés des agents disparus sont libérées', (tester) async {
      await pumpRail(tester);
      await plan(tester);
      await tester.pump();
      final DelegationLinksState state = tester.state<DelegationLinksState>(
        find.byType(DelegationLinks),
      );
      expect(state.tileKeyCount, 4);

      await plan(
        tester,
        selected: const <String>['Qualité'],
        idle: const <String>[],
      );
      await tester.pump();
      expect(state.tileKeyCount, 2);
    });
  });
}
