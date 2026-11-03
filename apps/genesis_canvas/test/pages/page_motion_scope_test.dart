import 'dart:async';
import 'dart:ui' show AccessibilityFeatures;

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:feature_stage_controls/feature_stage_controls.dart'
    show StageActReached, StageBloc;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show ReadContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart' show ReplayedMessage;
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope;

import '../support/page_rig.dart';

/// Portée du mouvement (019 T12, plan P2) : un seul `SceneMotionScope` couvre
/// toute la scène, pied (étagère du catalogue, barre de rejeu) et panneau du
/// protocole compris. La vraie mesure de « aucune boucle active » est
/// `transientCallbackCount == 0` une fois la scène stabilisée : toute boucle
/// qui ne passe pas par `SceneMotionScope.loop` la fait échouer.
void main() {
  /// Laisse les animations ponctuelles et les ticks en vol se terminer.
  Future<void> stabilize(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> reachAct(WidgetTester tester, PageRig rig, int act) async {
    rig.context.read<StageBloc>().add(StageActReached(act));
    await tester.pump();
    await tester.pump();
    await stabilize(tester);
    expect(rig.context.read<StageBloc>().state.act, act);
  }

  group('portée du mouvement', () {
    for (final key in const <String>[
      'catalog-shelf',
      'replay-bar',
      'protocol-panel',
    ]) {
      testWidgets('$key est sous le SceneMotionScope de la page, désactivé '
          'en scénario', (tester) async {
        final rig = PageRig(tester);
        final messages = StreamController<ReplayedMessage>();
        addTearDown(messages.close);
        await rig.mount(tester, replay: messages.stream, themed: true);

        final finder = find.byKey(Key(key));
        expect(finder, findsOneWidget);
        expect(SceneMotionScope.of(tester.element(finder)).disabled, isTrue);
      });
    }

    testWidgets('le pied et le panneau du protocole voient le même réglage '
        'que le canevas', (tester) async {
      final rig = PageRig(tester);
      final messages = StreamController<ReplayedMessage>();
      addTearDown(messages.close);
      await rig.mount(tester, replay: messages.stream, themed: true);

      final canvas = SceneMotionScope.of(
        tester.element(find.byKey(const Key('canvas-board'))),
      );
      expect(canvas.disabled, isTrue);
      final scopes = find.byType(SceneMotionScope).evaluate();
      expect(scopes, isNotEmpty);
      // Un seul scope enveloppe la scène : il est l'ancêtre du canevas, du
      // pied et du panneau du protocole.
      final root = scopes.first;
      for (final key in const <String>['canvas-board', 'replay-play']) {
        final element = tester.element(find.byKey(Key(key)));
        var found = false;
        element.visitAncestorElements((ancestor) {
          if (identical(ancestor, root)) found = true;
          return !found;
        });
        expect(found, isTrue, reason: '$key hors du scope de la scène');
      }
    });
  });

  group('aucune boucle active', () {
    for (final act in <int>[1, 2, 3]) {
      testWidgets('acte $act, mode scénario : transientCallbackCount == 0', (
        tester,
      ) async {
        final rig = PageRig(tester);
        final messages = StreamController<ReplayedMessage>();
        addTearDown(messages.close);
        await rig.mount(tester, replay: messages.stream, themed: true);
        for (final envelope in await act1Envelopes(tester)) {
          if (envelope['type'] != 'a2ui') continue;
          final raw = Map<String, Object?>.from(envelope['data']! as Map);
          messages.add((raw: raw, message: A2uiMessage.fromJson(raw)));
          await tester.pump();
        }
        await reachAct(tester, rig, act);

        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('acte $act, sous disableAnimations : '
          'transientCallbackCount == 0', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const _NoAnimations();
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final rig = PageRig(tester);
        await rig.mount(tester, themed: true);
        await rig.start(tester);
        for (final envelope in await act1Envelopes(tester)) {
          rig.receiveEnvelope(envelope);
          await tester.pump();
          await tester.pump();
        }
        await reachAct(tester, rig, act);

        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  });
}

class _NoAnimations implements AccessibilityFeatures {
  const _NoAnimations();

  @override
  bool get disableAnimations => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
