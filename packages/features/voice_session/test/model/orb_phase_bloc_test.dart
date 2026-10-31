import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _resume = Duration(seconds: 3);
const Duration _max = Duration(seconds: 10);
const Duration _stopSpan = Duration(seconds: 3);
const double _threshold = 0.03;

class _Rig {
  _Rig() {
    bloc = OrbPhaseBloc(
      speakingThreshold: _threshold,
      resumeSilence: _resume,
      maxInterruption: _max,
      stopSpan: _stopSpan,
    );
    bloc.stream.listen(phases.add);
    bloc.add(OrbPhaseSourceSubscribed(source.stream));
  }

  late final OrbPhaseBloc bloc;
  final StreamController<SessionEvent> source =
      StreamController<SessionEvent>.broadcast();
  final List<OrbPhase> phases = <OrbPhase>[];

  Future<void> send(WidgetTester tester, SessionEvent event) async {
    // Laisse d'abord le Bloc s'abonner : la source est en diffusion.
    await tester.pump();
    source.add(event);
    await tester.pump();
  }

  // Le Bloc vit dans le temps simulé : sa fermeture avance par `pump`.
  Future<void> close(WidgetTester tester) async {
    unawaited(source.close());
    unawaited(bloc.close());
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    expect(bloc.isClosed, isTrue);
  }
}

void main() {
  const Listening listening = Listening();
  const Speaking speaking = Speaking();
  const Interrupted interrupted = Interrupted();
  const SessionEvent interrupt = VoiceInterrupted(atMs: 2500);

  testWidgets('état initial : écoute', (tester) async {
    final _Rig rig = _Rig();
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  testWidgets('le niveau au-dessus du seuil fait parler, en dessous écouter', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, const OrbLevelChanged(0.4));
    await rig.send(tester, const OrbLevelChanged(0.5));
    await rig.send(tester, const OrbLevelChanged(0));
    expect(rig.phases, <OrbPhase>[speaking, listening]);
    await rig.close(tester);
  });

  testWidgets('voice.interrupted : interrompue', (tester) async {
    final _Rig rig = _Rig();
    await rig.send(tester, const OrbLevelChanged(0.4));
    await rig.send(tester, interrupt);
    expect(rig.phases, <OrbPhase>[speaking, interrupted]);
    await rig.close(tester);
  });

  testWidgets('silence pendant le délai de reprise : retour à l\'écoute', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await rig.send(tester, const OrbLevelChanged(0));
    await tester.pump(_resume - const Duration(milliseconds: 1));
    expect(rig.bloc.state, interrupted);
    await tester.pump(const Duration(milliseconds: 1));
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  testWidgets('un niveau au-dessus du seuil repousse la reprise', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await tester.pump(const Duration(seconds: 2));
    await rig.send(tester, const OrbLevelChanged(0.4));
    await tester.pump(const Duration(seconds: 2));
    expect(rig.bloc.state, interrupted, reason: 'la voix continue');
    await tester.pump(const Duration(seconds: 1));
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  testWidgets('un niveau sous le seuil ne repousse pas la reprise', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await tester.pump(const Duration(seconds: 2));
    await rig.send(tester, const OrbLevelChanged(0.01));
    await tester.pump(const Duration(seconds: 1));
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  testWidgets('durée maximale : reprise même si la voix continue', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    for (int i = 0; i < 9; i++) {
      await tester.pump(const Duration(seconds: 1));
      await rig.send(tester, const OrbLevelChanged(0.4));
    }
    expect(rig.bloc.state, interrupted);
    await tester.pump(const Duration(seconds: 1));
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  testWidgets('la délégation suivante met fin à l\'interruption', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await rig.send(tester, const DelegationStarted(id: 'd2', offsetMs: 5501));
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  testWidgets('la délégation datée du « Stop » laisse l\'interruption', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await rig.send(tester, const DelegationStarted(id: 'd1', offsetMs: 0));
    await rig.send(tester, const DelegationStarted(id: 'd2', offsetMs: 5500));
    expect(rig.bloc.state, interrupted);
    expect(rig.phases, <OrbPhase>[interrupted]);
    await rig.close(tester);
  });

  testWidgets('une échéance périmée ne termine pas l\'interruption suivante', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await tester.pump(_resume - const Duration(milliseconds: 1));
    // L'échéance tombe dans la file au moment où une nouvelle interruption
    // la remplace.
    rig.source.add(interrupt);
    await tester.pump(const Duration(milliseconds: 1));
    expect(rig.bloc.state, interrupted, reason: 'délai neuf');
    await tester.pump(_resume - const Duration(milliseconds: 2));
    expect(rig.bloc.state, interrupted);
    await tester.pump(const Duration(milliseconds: 1));
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  testWidgets('ChannelLost : écoute, plus de reprise en attente', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await rig.send(tester, const ChannelLost('connection_lost'));
    expect(rig.phases, <OrbPhase>[interrupted, listening]);
    await tester.pump(_max);
    expect(rig.phases, hasLength(2));
    await rig.close(tester);
  });

  testWidgets('pendant l\'interruption, le niveau ne fait pas parler', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await rig.send(tester, const OrbLevelChanged(0.9));
    expect(rig.bloc.state, interrupted);
    await rig.close(tester);
  });

  testWidgets('fin de session : écoute, plus de reprise en attente', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await rig.send(
      tester,
      const SessionStateChanged(state: SessionState.closed),
    );
    expect(rig.phases, <OrbPhase>[interrupted, listening]);
    await tester.pump(_max);
    expect(rig.phases, hasLength(2));
    await rig.close(tester);
  });

  testWidgets('une nouvelle interruption repart d\'un délai neuf', (
    tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.send(tester, interrupt);
    await tester.pump(_resume);
    expect(rig.bloc.state, listening);
    await rig.send(tester, interrupt);
    await tester.pump(const Duration(seconds: 2));
    expect(rig.bloc.state, interrupted);
    await tester.pump(const Duration(seconds: 1));
    expect(rig.bloc.state, listening);
    await rig.close(tester);
  });

  group('silence local (VoiceSilenced)', () {
    testWidgets('passe en interrompue sans at_ms', (tester) async {
      final _Rig rig = _Rig();
      await rig.send(tester, const OrbLevelChanged(0.4));
      await rig.send(tester, const VoiceSilenced());
      expect(rig.phases, <OrbPhase>[speaking, interrupted]);
      await rig.close(tester);
    });

    testWidgets('le niveau ne fait pas parler, le silence reprend l\'écoute', (
      tester,
    ) async {
      final _Rig rig = _Rig();
      await rig.send(tester, const VoiceSilenced());
      await rig.send(tester, const OrbLevelChanged(0));
      await tester.pump(_resume);
      expect(rig.phases, <OrbPhase>[interrupted, listening]);
      await rig.close(tester);
    });

    testWidgets('pas d\'exemption stopSpan : toute délégation y met fin', (
      tester,
    ) async {
      final _Rig rig = _Rig();
      await rig.send(tester, const VoiceSilenced());
      await rig.send(tester, const DelegationStarted(id: 'd', offsetMs: 0));
      expect(rig.phases, <OrbPhase>[interrupted, listening]);
      await rig.close(tester);
    });

    testWidgets(
      'une interruption stop après un silence retrouve son exemption',
      (tester) async {
        final _Rig rig = _Rig();
        await rig.send(tester, const VoiceSilenced());
        await rig.send(tester, interrupt);
        await rig.send(
          tester,
          const DelegationStarted(id: 'd', offsetMs: 3000),
        );
        expect(rig.bloc.state, interrupted);
        await rig.close(tester);
      },
    );
  });

  group('cause correction', () {
    const SessionEvent correction = VoiceInterrupted(
      atMs: 2500,
      cause: InterruptionCause.correction,
    );

    testWidgets('interrompue, puis la délégation à at + 1500 rend l\'écoute', (
      tester,
    ) async {
      final _Rig rig = _Rig();
      await rig.send(tester, const OrbLevelChanged(0.4));
      await rig.send(tester, correction);
      await rig.send(tester, const DelegationStarted(id: 'd', offsetMs: 4000));
      expect(rig.phases, <OrbPhase>[speaking, interrupted, listening]);
      await rig.close(tester);
    });

    testWidgets(
      'une délégation datée avant at_ms ne termine pas l\'interruption',
      (tester) async {
        final _Rig rig = _Rig();
        await rig.send(tester, correction);
        await rig.send(
          tester,
          const DelegationStarted(id: 'd0', offsetMs: 2499),
        );
        expect(rig.bloc.state, interrupted);
        await rig.send(
          tester,
          const DelegationStarted(id: 'd1', offsetMs: 2500),
        );
        expect(rig.bloc.state, listening);
        await rig.close(tester);
      },
    );

    testWidgets('cause stop explicite : exemption stopSpan inchangée', (
      tester,
    ) async {
      final _Rig rig = _Rig();
      await rig.send(tester, interrupt);
      await rig.send(tester, const DelegationStarted(id: 'd', offsetMs: 5500));
      expect(rig.bloc.state, interrupted);
      await rig.send(tester, const DelegationStarted(id: 'e', offsetMs: 5501));
      expect(rig.bloc.state, listening);
      await rig.close(tester);
    });
  });
}
