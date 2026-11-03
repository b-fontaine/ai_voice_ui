import 'dart:async';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_protocol_feed/feature_protocol_feed.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/agents_rail/agents_rail.dart';
import 'package:genesis_canvas/widgets/protocol_panel/protocol_panel.dart';
import 'package:genesis_canvas/widgets/replay_bar/replay_bar.dart';
import 'package:genesis_canvas/widgets/top_bar/sm_button.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/motion_probe.dart';
import '../support/replay_rig.dart';

/// Animations de niveau B (019 T34, pdr-0088 F9 et F13) : chaque boucle suit
/// `SceneMotionScope.loop`, a sa phase de repos sous `disabled`, son propre
/// `RepaintBoundary` et un contrôleur lancé une seule fois (une
/// reconstruction ne la relance pas). Le curseur de la transcription est dans
/// `voice_bar_test`, l'anneau de tête dans la slice canvas, le losange de
/// l'étiquette dans `ds_gen_frame_test`.
const Key _outer = Key('motion-outer');

Finder _key(String name) => find.byKey(Key(name));

class _Clock implements AppClock {
  int now = 1761800000000;

  @override
  int nowUnixMs() => now += 1000;
}

ValidatedEnvelope _accepted(String operation, String surface) =>
    ValidatedEnvelope(
      raw: <String, Object?>{
        'version': 'v0.9',
        operation: <String, Object?>{'surfaceId': surface},
      },
      verdict: const ValidationAccepted(),
      agent: 'Qualité',
    );

void main() {
  group('point d\'enregistrement du micro (gc-blink, 1,2 s)', () {
    Widget host({bool disabled = false, String label = 'Micro'}) => MaterialApp(
      home: SceneMotionScope(
        disabled: disabled,
        child: RepaintBoundary(
          key: _outer,
          child: Center(
            child: SmButton(
              buttonKey: const Key('mic-button'),
              visualKey: const Key('mic-button-visual'),
              label: label,
              onPressed: () {},
              recording: true,
            ),
          ),
        ),
      ),
    );

    flutter_test.testWidgets('contrat de clignotement, période de 1,2 s', (
      tester,
    ) async {
      await expectBlinkContract(
        tester,
        key: const Key('mic-rec-dot'),
        period: const Duration(milliseconds: 1200),
        mount: () => tester.pumpWidget(host()),
        rebuild: () => tester.pumpWidget(host(label: 'Micro ouvert')),
        mountDisabled: () => tester.pumpWidget(host(disabled: true)),
        outer: find.byKey(_outer),
      );
    });

    flutter_test.testWidgets('micro non ouvert : ni point ni boucle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SceneMotionScope(
            child: SmButton(
              buttonKey: const Key('mic-button'),
              visualKey: const Key('mic-button-visual'),
              label: 'Micro',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(_key('mic-rec-dot'), findsNothing);
      expect(find.byType(DsBlink), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('rail des agents : barre indéterminée et point battant', () {
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
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      unawaited(events.close());
      unawaited(bloc.close());
      await tester.pump();
    });

    Widget rail({bool disabled = false}) => Directionality(
      textDirection: TextDirection.ltr,
      child: SceneMotionScope(
        disabled: disabled,
        child: BlocProvider<AgentActivityBloc>.value(
          value: bloc,
          child: const RepaintBoundary(
            key: _outer,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 1872, height: 96, child: AgentsRail()),
            ),
          ),
        ),
      ),
    );

    Future<void> work(WidgetTester tester, {bool disabled = false}) async {
      await tester.pumpWidget(rail(disabled: disabled));
      bloc.add(AgentActivitySourceSubscribed(events.stream));
      await tester.pump();
      events.add(
        PlanReceived(
          delegation: 'd1',
          selected: const <String>['Voix du client', 'Qualité'],
          idle: const <String>['Conformité'],
        ),
      );
      await tester.pump();
      events.add(
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 't',
          state: AgentTaskState.working,
          label: 'Analyse',
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    // Décalage de la barre, en largeurs de barre (`translateX(-100% → 260%)`),
    // lu dans le dessin du segment.
    double barOffset(WidgetTester tester) {
      final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
        _key('agent-bar-Qualité'),
      );
      final TestRecordingCanvas canvas = TestRecordingCanvas();
      render.painter!.paint(canvas, render.size);
      final Rect rect =
          canvas.invocations
                  .singleWhere(
                    (RecordedInvocation c) =>
                        c.invocation.memberName == #drawRect,
                  )
                  .invocation
                  .positionalArguments[0]
              as Rect;
      return rect.left / render.size.width;
    }

    testWidgets('la barre défile de -100 % à 260 % en 1,3 s, en boucle', (
      tester,
    ) async {
      await work(tester);
      expect(barOffset(tester), closeTo(-1, 0.05), reason: 'départ');
      await tester.pump(const Duration(milliseconds: 1000));
      expect(barOffset(tester), greaterThan(1.5), reason: 'presque au bout');
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        barOffset(tester),
        lessThan(0),
        reason: 'repart de la gauche après 1,3 s',
      );
    });

    testWidgets('la barre a son RepaintBoundary : le texte voisin ne se '
        'repeint pas', (tester) async {
      await work(tester);
      final Finder bar = _key('agent-bar-Qualité');
      final Finder own = find.ancestor(
        of: bar,
        matching: find.byType(RepaintBoundary),
      );
      // Le boundary de la barre est dans la tuile et ne contient ni le point
      // ni le texte voisin.
      expect(
        find.descendant(
          of: _key('agent-tile-Qualité'),
          matching: find.byWidget(own.first.evaluate().first.widget),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: own.first, matching: _key('agent-state-Qualité')),
        findsNothing,
      );
      final int barBefore = boundaryPaints(tester, bar);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(boundaryPaints(tester, bar), greaterThan(barBefore));
    });

    testWidgets('une reconstruction ne relance pas la barre', (tester) async {
      await work(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final double before = barOffset(tester);
      events.add(
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 't',
          state: AgentTaskState.working,
          label: 'Analyse bis',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(barOffset(tester), greaterThan(before), reason: 'phase continue');
    });

    testWidgets('animations coupées : barre immobile et visible à gauche', (
      tester,
    ) async {
      await work(tester, disabled: true);
      expect(_key('agent-bar-Qualité'), findsOneWidget);
      expect(barOffset(tester), 0);
      await tester.pump(const Duration(milliseconds: 700));
      expect(barOffset(tester), 0);
      expect(tester.getSize(_key('agent-bar-Qualité')).height, 2);
    });

    // Cercles dessinés par le point battant (halo, avec ou sans point plein).
    int halos(WidgetTester tester) {
      final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
        find
            .descendant(
              of: find.ancestor(
                of: _key('agent-dot-Qualité'),
                matching: find.byType(DsBeacon),
              ),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      final TestRecordingCanvas canvas = TestRecordingCanvas();
      render.painter!.paint(canvas, const Size.square(8));
      return canvas.invocations
          .where(
            (RecordedInvocation c) => c.invocation.memberName == #drawCircle,
          )
          .length;
    }

    testWidgets('le point de l\'agent au travail bat (gc-beacon, 1,2 s) ; '
        'les autres sont fixes', (tester) async {
      await work(tester);
      expect(halos(tester), 0, reason: 'début de période : pas de halo');
      await tester.pump(const Duration(milliseconds: 500));
      expect(halos(tester), 1, reason: 'le halo s\'étend');
      // Période de 1,2 s (la puce Bloquant : 1,6 s) : à 75 % le halo est éteint.
      await tester.pump(const Duration(milliseconds: 400));
      expect(halos(tester), 0, reason: 'fin du halo à 70 % de 1,2 s');
      for (final String other in <String>['Orchestrateur', 'Voix du client']) {
        expect(
          find.ancestor(
            of: _key('agent-dot-$other'),
            matching: find.byType(DsBeacon),
          ),
          findsNothing,
          reason: other,
        );
      }
    });

    testWidgets('le point battant a son RepaintBoundary', (tester) async {
      await work(tester);
      final Finder dot = _key('agent-dot-Qualité');
      final Finder own = find.ancestor(
        of: dot,
        matching: find.byType(RepaintBoundary),
      );
      // Le boundary du point ne contient ni le nom ni le texte d'état.
      expect(
        find.descendant(of: own.first, matching: _key('agent-state-Qualité')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _key('agent-tile-Qualité'),
          matching: find.byWidget(own.first.evaluate().first.widget),
        ),
        findsOneWidget,
      );
      final int before = boundaryPaints(tester, dot);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(boundaryPaints(tester, dot), greaterThan(before));
    });

    testWidgets('animations coupées : point plein, sans halo ni boucle', (
      tester,
    ) async {
      await work(tester, disabled: true);
      expect(halos(tester), 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(halos(tester), 0);
      expect(tester.getSize(_key('agent-dot-Qualité')), const Size(8, 8));
    });

    testWidgets('l\'agent a fini : plus de barre, plus de point battant', (
      tester,
    ) async {
      await work(tester);
      events.add(
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 't',
          state: AgentTaskState.completed,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(_key('agent-bar-Qualité'), findsNothing);
      expect(find.byType(DsBeacon), findsNothing);
    });
  });

  group('« Direct » (gc-blink, 1 s) tant que le direct est affiché', () {
    ReplayRig? rig;

    Widget bar({bool disabled = false, double width = 480}) => MaterialApp(
      home: SceneMotionScope(
        disabled: disabled,
        child: BlocProvider<ReplayBloc>.value(
          value: rig!.bloc,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _outer,
              child: SizedBox(
                width: width,
                height: 140,
                child: const ReplayBar(),
              ),
            ),
          ),
        ),
      ),
    );

    flutter_test.testWidgets('contrat de clignotement, période de 1 s', (
      tester,
    ) async {
      rig = ReplayRig(withJournal: true);
      await expectBlinkContract(
        tester,
        key: const Key('replay-direct-dot'),
        period: SceneMotion.blink,
        mount: () => tester.pumpWidget(bar()),
        rebuild: () => tester.pumpWidget(bar(width: 481)),
        mountDisabled: () => tester.pumpWidget(bar(disabled: true)),
        outer: find.byKey(_outer),
      );
      await tester.pumpWidget(const SizedBox());
      rig!.dispose();
      await tester.pump();
    });

    flutter_test.testWidgets('en rejeu, le point est fixe et plein', (
      tester,
    ) async {
      rig = ReplayRig(withJournal: true);
      await tester.pumpWidget(bar());
      await tester.tap(_key('replay-play'));
      await tester.pump();
      await tester.pump();
      expect(_key('replay-direct-dot'), findsOneWidget);
      expect(
        find.ancestor(
          of: _key('replay-direct-dot'),
          matching: find.byType(DsBlink),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      rig!.dispose();
      await tester.pump();
    });
  });

  group('flux A2UI : apparition ligne à ligne (gc-row, 350 ms)', () {
    late ProtocolFeedBloc bloc;
    late StreamController<ValidatedEnvelope> envelopes;

    void testWidgets(
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) => flutter_test.testWidgets(description, (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bloc = ProtocolFeedBloc(clock: _Clock());
      envelopes = StreamController<ValidatedEnvelope>.broadcast();
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      unawaited(envelopes.close());
      unawaited(bloc.close());
      await tester.pump();
    });

    Future<void> mount(WidgetTester tester, {bool disabled = false}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SceneMotionScope(
            disabled: disabled,
            child: RepaintBoundary(
              key: _outer,
              child: Align(
                alignment: Alignment.bottomRight,
                child: BlocProvider<ProtocolFeedBloc>.value(
                  value: bloc,
                  child: const ProtocolPanel(),
                ),
              ),
            ),
          ),
        ),
      );
      bloc.add(ProtocolSourceSubscribed(envelopes.stream));
      await tester.pump();
      await tester.tap(_key('protocol-toggle'));
      await tester.pump();
      await tester.pump();
      // Fin de l'éclat du bouton (encre), qui n'est pas une boucle du flux.
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> receive(WidgetTester tester, String op, String id) async {
      envelopes.add(_accepted(op, id));
      await tester.pump();
      await tester.pump();
    }

    double opacity(WidgetTester tester, int index) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: _key('protocol-entry-$index'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    // Glissement horizontal courant, en points (-12 au départ, 0 à l'arrivée) :
    // décalage de la peinture de l'entrée par rapport à sa mise en page.
    double slide(WidgetTester tester, int index) {
      final Finder entry = _key('protocol-entry-$index');
      final Finder shifted = find
          .ancestor(of: entry, matching: find.byType(DsShift))
          .first;
      return tester.getTopLeft(entry).dx - tester.getTopLeft(shifted).dx;
    }

    testWidgets('une entrée entre en 350 ms : fondu et glissement depuis la '
        'gauche (12 px)', (tester) async {
      await mount(tester);
      await receive(tester, 'createSurface', 'kpi');
      expect(opacity(tester, 0), 0);
      expect(slide(tester, 0), closeTo(-12, 1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(tester, 0), allOf(greaterThan(0), lessThan(1)));
      await tester.pump(const Duration(milliseconds: 210));
      expect(opacity(tester, 0), 1);
      expect(slide(tester, 0), 0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('seule la nouvelle entrée joue ; les anciennes restent en '
        'place', (tester) async {
      await mount(tester);
      await receive(tester, 'createSurface', 'kpi');
      await tester.pump(const Duration(milliseconds: 400));
      await receive(tester, 'updateComponents', 'kpi');
      expect(opacity(tester, 0), 1, reason: 'entrée 0 inchangée');
      expect(opacity(tester, 1), 0, reason: 'entrée 1 qui entre');
      await tester.pump(const Duration(milliseconds: 400));
      // Une troisième : l'entrée 0 se redessine à un autre rang, sans rejouer.
      await receive(tester, 'updateDataModel', 'kpi');
      expect(opacity(tester, 0), 1);
      expect(opacity(tester, 1), 1);
      expect(opacity(tester, 2), 0);
    });

    testWidgets('chaque entrée anime dans son RepaintBoundary', (tester) async {
      await mount(tester);
      await receive(tester, 'createSurface', 'kpi');
      final Finder entry = _key('protocol-entry-0');
      final int before = boundaryPaints(tester, entry);
      final int outerBefore = paintsOf(tester, find.byKey(_outer));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(boundaryPaints(tester, entry), greaterThan(before));
      expect(
        paintsOf(tester, find.byKey(_outer)),
        outerBefore,
        reason:
            'le flux a ses RepaintBoundary : le reste du panneau est intact',
      );
    });

    testWidgets('animations coupées : l\'entrée est en place d\'emblée', (
      tester,
    ) async {
      await mount(tester, disabled: true);
      await receive(tester, 'createSurface', 'kpi');
      expect(opacity(tester, 0), 1);
      expect(slide(tester, 0), 0);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
