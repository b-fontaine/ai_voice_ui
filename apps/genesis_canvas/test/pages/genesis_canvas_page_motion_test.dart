import 'dart:async';
import 'dart:ui' show AccessibilityFeatures;

import 'package:feature_replay/feature_replay.dart'
    show ReplayActive, ReplayBloc;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show ReadContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart' show ReplayedMessage;
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart' show TopBar;
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotion, SceneMotionScope;

import '../support/page_rig.dart';

/// Réglage d'animation posé par la page au-dessus du canevas (013, T21b) :
/// durée nulle en scénario, en capture ou sous « réduire les animations »,
/// vitesse du rejeu en cours sinon.
void main() {
  SceneMotionScope motionOf(WidgetTester tester) => SceneMotionScope.of(
    tester.element(find.byKey(const Key('canvas-board'))),
  );

  SceneMotionScope topBarMotion(WidgetTester tester) =>
      SceneMotionScope.of(tester.element(find.byType(TopBar)));

  bool orbRuns(WidgetTester tester) =>
      tester.binding.transientCallbackCount > 0;

  testWidgets('la barre du haut est sous le réglage d\'animation de la page', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    expect(topBarMotion(tester).disabled, isFalse);
    expect(topBarMotion(tester).speed, 1);
    expect(orbRuns(tester), isTrue, reason: 'l\'orbe bat en direct');
  });

  testWidgets('scénario : barre du haut figée, pumpAndSettle converge', (
    tester,
  ) async {
    final rig = PageRig(tester);
    final messages = StreamController<ReplayedMessage>();
    addTearDown(messages.close);
    await rig.mount(tester, replay: messages.stream, themed: true);

    expect(topBarMotion(tester).disabled, isTrue);
    expect(find.byKey(const Key('voice-orb')), findsOneWidget);
    expect(orbRuns(tester), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'sous « réduire les animations » : l\'orbe est figé, pumpAndSettle converge',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const _NoAnimations();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final rig = PageRig(tester);
      await rig.mount(tester, themed: true);

      expect(topBarMotion(tester).disabled, isTrue);
      expect(find.byKey(const Key('voice-orb')), findsOneWidget);
      expect(orbRuns(tester), isFalse, reason: 'aucun Ticker actif');
      await tester.pumpAndSettle();
    },
  );

  testWidgets('en mode scénario, les durées sont nulles', (tester) async {
    final rig = PageRig(tester);
    final messages = StreamController<ReplayedMessage>();
    addTearDown(messages.close);
    await rig.mount(tester, replay: messages.stream, themed: true);

    final scope = motionOf(tester);
    expect(scope.disabled, isTrue);
    expect(scope.durationFor(SceneMotion.appear), Duration.zero);
  });

  testWidgets('sous « réduire les animations », les durées sont nulles', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const _NoAnimations();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);

    final scope = motionOf(tester);
    expect(scope.disabled, isTrue);
    expect(scope.durationFor(SceneMotion.appear), Duration.zero);
  });

  testWidgets('en direct, les animations sont actives à la vitesse 1', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);

    final scope = motionOf(tester);
    expect(scope.disabled, isFalse);
    expect(scope.speed, 1);
    expect(scope.durationFor(SceneMotion.appear), SceneMotion.appear);
  });

  testWidgets('pendant un rejeu, la vitesse choisie est propagée', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    for (final envelope in await act1Envelopes(tester)) {
      rig.receiveEnvelope(envelope);
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('replay-play')));
    await tester.pump();
    await tester.pump();
    expect(rig.context.read<ReplayBloc>().state, isA<ReplayActive>());
    expect(motionOf(tester).speed, 1);

    await tester.tap(find.byKey(const Key('replay-speed-2')));
    await tester.pump();
    await tester.pump();

    expect(
      (rig.context.read<ReplayBloc>().state as ReplayActive).snapshot.speed,
      2,
    );
    final scope = motionOf(tester);
    expect(scope.speed, 2);
    expect(
      scope.durationFor(SceneMotion.appear),
      const Duration(milliseconds: 240),
    );
  });
}

class _NoAnimations implements AccessibilityFeatures {
  const _NoAnimations();

  @override
  bool get disableAnimations => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
