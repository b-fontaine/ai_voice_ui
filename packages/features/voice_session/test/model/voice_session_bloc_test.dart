import 'dart:async';

import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

import 'package:testing_bloc_harness/testing_bloc_harness.dart';
import 'package:testing_voice_fakes/testing_voice_fakes.dart';

void main() {
  late VoiceHarness h;

  setUp(() => h = VoiceHarness());
  tearDown(() => h.session.dispose());

  test('état initial : Idle', () async {
    final VoiceSessionBloc bloc = VoiceSessionBloc(h.session);
    expect(bloc.state, const Idle());
    await bloc.close();
  });

  test('Subscribed puis Started puis Stopped : reflète les statuts', () async {
    final VoiceSessionBloc bloc = VoiceSessionBloc(h.session);

    final List<VoiceSessionStatus> states = await statesAfter(bloc, (b) async {
      b.add(const VoiceSessionSubscribed());
      await pumpEventQueue();
      b.add(const VoiceSessionStarted());
      await pumpEventQueue();
      b.add(const VoiceSessionStopped());
      await pumpEventQueue();
    });

    // Le premier `Idle` est le rejeu du statut courant à l'abonnement.
    expect(states, const <VoiceSessionStatus>[
      Idle(),
      Connecting(),
      Active(),
      Stopping(),
      Idle(),
    ]);
  });

  test('échec : l\'état est le Failed de la session', () async {
    h.relay.createHook = (_) =>
        throw const RelayFailure(RelayFailureKind.rateLimited);
    final VoiceSessionBloc bloc = VoiceSessionBloc(h.session);

    final List<VoiceSessionStatus> states = await statesAfter(bloc, (b) async {
      b.add(const VoiceSessionSubscribed());
      b.add(const VoiceSessionStarted());
      await pumpEventQueue();
    });

    expect(states.last, const Failed(RateLimited(null)));
  });

  test('double Started : un seul start()', () async {
    final VoiceSessionBloc bloc = VoiceSessionBloc(h.session);
    final Completer<String> offer = Completer<String>();
    h.onNewTransport = (t) => t.offerHook = () => offer.future;

    bloc
      ..add(const VoiceSessionSubscribed())
      ..add(const VoiceSessionStarted())
      ..add(const VoiceSessionStarted());
    await pumpEventQueue();
    offer.complete('offer-1');
    await pumpEventQueue();

    expect(h.transports, hasLength(1));
    expect(h.relay.offers, <String>['offer-1']);
    await bloc.close();
  });

  test('double Stopped pendant l\'arrêt : un seul arrêt', () async {
    final VoiceSessionBloc bloc = VoiceSessionBloc(h.session);
    final Completer<void> deleted = Completer<void>();
    h.relay.deleteHook = (_) => deleted.future;
    bloc.add(const VoiceSessionSubscribed());
    bloc.add(const VoiceSessionStarted());
    await pumpEventQueue();

    bloc
      ..add(const VoiceSessionStopped())
      ..add(const VoiceSessionStopped());
    await pumpEventQueue();
    deleted.complete();
    await pumpEventQueue();

    expect(h.events.where((e) => e == 'relay.delete(s1)'), hasLength(1));
    await bloc.close();
  });

  test('un second Subscribed annule le premier abonnement', () async {
    final VoiceSessionBloc bloc = VoiceSessionBloc(h.session);

    final List<VoiceSessionStatus> states = await statesAfter(bloc, (b) async {
      b.add(const VoiceSessionSubscribed());
      await pumpEventQueue();
      b.add(const VoiceSessionSubscribed());
      await pumpEventQueue();
      await h.session.start();
      await pumpEventQueue();
    });

    // Un seul abonnement actif : chaque statut n'est émis qu'une fois.
    expect(states, const <VoiceSessionStatus>[Idle(), Connecting(), Active()]);
  });

  test('close() ne dispose pas la session', () async {
    final VoiceSessionBloc bloc = VoiceSessionBloc(h.session);
    bloc.add(const VoiceSessionSubscribed());
    bloc.add(const VoiceSessionStarted());
    await pumpEventQueue();

    await bloc.close();

    expect(h.session.current, const Active());
    expect(h.events, isNot(contains('t1.dispose')));
  });
}
