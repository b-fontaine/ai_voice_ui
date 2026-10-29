/// Faux de frontière (transport WebRTC, relais HTTP, canal WSS) partagés par
/// les tests de la slice.
library;

import 'dart:async';

import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Faux transport : frontière WebRTC. Chaque appel est journalisé.
class FakeTransport implements VoiceTransport {
  FakeTransport(this.index, this._events);

  final int index;
  final List<String> _events;
  Future<String> Function()? offerHook;
  Future<void> Function(String sdp)? answerHook;

  void _log(String call) => _events.add('t$index.$call');

  @override
  Future<String> createOfferSdp() async {
    _log('createOfferSdp');
    return offerHook != null ? offerHook!() : 'offer-$index';
  }

  @override
  Future<void> applyAnswer(String sdp) async {
    _log('applyAnswer');
    await answerHook?.call(sdp);
  }

  @override
  Future<void> stop() async => _log('stop');

  @override
  Future<void> dispose() async => _log('dispose');
}

class FakeRelay implements VoiceRelay {
  FakeRelay(this._events);

  final List<String> _events;
  int _count = 0;
  final List<String> offers = <String>[];
  Future<RelayAnswer> Function(String offer)? createHook;
  Future<void> Function(String id)? deleteHook;

  @override
  Future<RelayAnswer> createSession(String offerSdp) async {
    _events.add('relay.create');
    offers.add(offerSdp);
    _count++;
    if (createHook != null) return createHook!(offerSdp);
    return RelayAnswer(answerSdp: 'answer-$_count', sessionId: 's$_count');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _events.add('relay.delete($sessionId)');
    await deleteHook?.call(sessionId);
  }
}

class FakeChannel implements AppChannel {
  FakeChannel(this._events);

  final List<String> _events;
  final List<StreamController<AppChannelEnvelope>> controllers =
      <StreamController<AppChannelEnvelope>>[];
  Stream<AppChannelEnvelope> Function(String id)? streamBuilder;
  int cancelCount = 0;

  StreamController<AppChannelEnvelope> get last => controllers.last;

  @override
  Stream<AppChannelEnvelope> open(String sessionId) {
    _events.add('channel.open($sessionId)');
    if (streamBuilder != null) return streamBuilder!(sessionId);
    final controller = StreamController<AppChannelEnvelope>(
      onCancel: () => cancelCount++,
    );
    controllers.add(controller);
    return controller.stream;
  }
}

/// Flux dont l'annulation est sans effet : simule un événement tardif d'une
/// ancienne connexion qui parviendrait quand même à la session.
class LeakyStream extends Stream<AppChannelEnvelope> {
  void Function()? onDone;

  @override
  StreamSubscription<AppChannelEnvelope> listen(
    void Function(AppChannelEnvelope event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    this.onDone = onDone;
    return LeakySubscription();
  }
}

class LeakySubscription implements StreamSubscription<AppChannelEnvelope> {
  @override
  Future<void> cancel() async {}
  @override
  void onData(void Function(AppChannelEnvelope data)? handleData) {}
  @override
  void onError(Function? handleError) {}
  @override
  void onDone(void Function()? handleDone) {}
  @override
  void pause([Future<void>? resumeSignal]) {}
  @override
  void resume() {}
  @override
  bool get isPaused => false;
  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;
}

AppChannelEnvelope envelopeOf(
  String type,
  Map<String, Object?> data, {
  String session = 's1',
}) => AppChannelEnvelope(
  version: 1,
  type: type,
  session: session,
  tMs: 10,
  data: data,
);

class VoiceHarness {
  VoiceHarness({
    Duration closeTimeout = const Duration(seconds: 2),
    this.logPath,
  }) {
    relay = FakeRelay(events);
    channel = FakeChannel(events);
    session = VoiceSession(
      transportFactory: () {
        final transport = FakeTransport(transports.length + 1, events);
        transports.add(transport);
        onNewTransport?.call(transport);
        return transport;
      },
      relay: relay,
      channel: channel,
      logFactory: () => EnvelopeLog(path: logPath, nowUnixMs: () => 1000),
      closeTimeout: closeTimeout,
    );
  }

  final String? logPath;
  final List<String> events = <String>[];
  final List<FakeTransport> transports = <FakeTransport>[];
  void Function(FakeTransport transport)? onNewTransport;
  late final FakeRelay relay;
  late final FakeChannel channel;
  late final VoiceSession session;
}
