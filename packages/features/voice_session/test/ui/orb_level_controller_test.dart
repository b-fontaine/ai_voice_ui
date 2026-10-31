import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_voice_session/src/ui/orb_level_controller.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<SessionEvent> events;
  late OrbLevelController controller;
  late List<double> seen;

  Future<void> pumpEvent(WidgetTester tester, SessionEvent e) async {
    events.add(e);
    await tester.pump();
  }

  setUp(() {
    events = StreamController<SessionEvent>.broadcast(sync: true);
    seen = <double>[];
  });

  tearDown(() async {
    await events.close();
  });

  OrbLevelController build(TickerProvider vsync) {
    controller = OrbLevelController(vsync: vsync, events: events.stream);
    controller.level.addListener(() => seen.add(controller.level.value));
    return controller;
  }

  testWidgets('le niveau monte puis redescend', (WidgetTester tester) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.8));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final double high = controller.level.value;
    expect(high, greaterThan(0.3));
    await pumpEvent(tester, const OrbLevelChanged(0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.level.value, lessThan(high));
    controller.dispose();
  });

  testWidgets('retombe à 0 après 600 ms sans événement', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.8));
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.level.value, greaterThan(0.5));
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.level.value, 0.0);
    controller.dispose();
  });

  testWidgets('closed remet le niveau à 0 immédiatement', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.8));
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.level.value, greaterThan(0));
    events.add(const SessionStateChanged(state: SessionState.closed));
    expect(controller.level.value, 0.0);
    controller.dispose();
  });

  testWidgets('ChannelLost remet le niveau à 0 immédiatement', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.8));
    await tester.pump(const Duration(milliseconds: 200));
    events.add(const ChannelLost('coupure'));
    expect(controller.level.value, 0.0);
    controller.dispose();
  });

  testWidgets('un état non fermé ne touche pas au niveau', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.8));
    await tester.pump(const Duration(milliseconds: 200));
    final double before = controller.level.value;
    events.add(const SessionStateChanged(state: SessionState.active));
    expect(controller.level.value, before);
    controller.dispose();
  });

  testWidgets('le ticker s\'arrête au repos et redémarre', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.5));
    for (int i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.level.value, 0.0);
    final int count = seen.length;
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(seen.length, count);
    await pumpEvent(tester, const OrbLevelChanged(0.5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.level.value, greaterThan(0));
    controller.dispose();
  });

  testWidgets('valeurs hors bornes bornées, NaN ignoré', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(5));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.level.value, inInclusiveRange(0.0, 1.0));
    expect(controller.level.value, greaterThan(0.9));
    events.add(const OrbLevelChanged(double.nan));
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.level.value.isNaN, isFalse);
    events.add(const OrbLevelChanged(-3));
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.level.value, inInclusiveRange(0.0, 1.0));
    controller.dispose();
  });

  testWidgets('ne notifie pas si la valeur est inchangée', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.5));
    for (int i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      events.add(const OrbLevelChanged(0.5));
    }
    // Plateau atteint : plus aucune notification successive identique.
    for (int i = 1; i < seen.length; i++) {
      expect(seen[i], isNot(seen[i - 1]));
    }
    controller.dispose();
  });

  testWidgets('une erreur du flux est ignorée', (WidgetTester tester) async {
    build(tester);
    events.addError(StateError('boom'));
    await tester.pump();
    await pumpEvent(tester, const OrbLevelChanged(0.5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.level.value, greaterThan(0));
    controller.dispose();
  });

  testWidgets('dispose annule tout et est idempotent', (
    WidgetTester tester,
  ) async {
    build(tester);
    await pumpEvent(tester, const OrbLevelChanged(0.5));
    await tester.pump(const Duration(milliseconds: 50));
    controller.dispose();
    controller.dispose();
    final int count = seen.length;
    expect(events.hasListener, isFalse);
    events.add(const OrbLevelChanged(0.9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(seen.length, count);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  group('interruption (FR-19)', () {
    testWidgets('voice.interrupted ramène le niveau à 0 aussitôt', (
      WidgetTester tester,
    ) async {
      build(tester);
      await pumpEvent(tester, const OrbLevelChanged(0.8));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.level.value, greaterThan(0.3));

      await pumpEvent(tester, const VoiceInterrupted(atMs: 2500));
      expect(controller.level.value, 0.0);
      controller.dispose();
    });

    testWidgets('VoiceSilenced ramène le niveau à 0 et ignore les suivants', (
      WidgetTester tester,
    ) async {
      build(tester);
      await pumpEvent(tester, const OrbLevelChanged(0.9));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.level.value, greaterThan(0.3));

      await pumpEvent(tester, const VoiceSilenced());
      expect(controller.level.value, 0.0);
      await pumpEvent(tester, const OrbLevelChanged(0.9));
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.level.value, 0.0);
      controller.dispose();
    });

    testWidgets('la reprise suit un silence local', (
      WidgetTester tester,
    ) async {
      build(tester);
      await pumpEvent(tester, const VoiceSilenced());
      controller.resume();
      await pumpEvent(tester, const OrbLevelChanged(0.9));
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.level.value, greaterThan(0.3));
      controller.dispose();
    });

    testWidgets('les niveaux reçus pendant l\'interruption sont ignorés', (
      WidgetTester tester,
    ) async {
      build(tester);
      await pumpEvent(tester, const VoiceInterrupted(atMs: 2500));
      await pumpEvent(tester, const OrbLevelChanged(0.9));
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.level.value, 0.0);
      controller.dispose();
    });

    testWidgets('la reprise rend la main aux niveaux suivants', (
      WidgetTester tester,
    ) async {
      build(tester);
      await pumpEvent(tester, const VoiceInterrupted(atMs: 2500));
      controller.resume();
      await pumpEvent(tester, const OrbLevelChanged(0.9));
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.level.value, greaterThan(0.3));
      controller.dispose();
    });

    testWidgets('une nouvelle session lève l\'interruption', (
      WidgetTester tester,
    ) async {
      build(tester);
      await pumpEvent(tester, const VoiceInterrupted(atMs: 2500));
      await pumpEvent(
        tester,
        const SessionStateChanged(state: SessionState.closed),
      );
      await pumpEvent(tester, const OrbLevelChanged(0.9));
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.level.value, greaterThan(0.3));
      controller.dispose();
    });
  });
}
