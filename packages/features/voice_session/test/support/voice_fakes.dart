/// Faux propres à la slice (internes de `VoiceSession` : flux qui fuit,
/// journal qui échoue). Les faux de frontière partagés sont dans
/// `testing_voice_fakes`.
library;

import 'dart:async';

import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Flux dont l'annulation est sans effet : simule un événement tardif d'une
/// ancienne connexion qui parviendrait quand même à la session.
class LeakyStream extends Stream<AppChannelEnvelope> {
  void Function()? onDone;
  void Function(AppChannelEnvelope event)? onData;

  @override
  StreamSubscription<AppChannelEnvelope> listen(
    void Function(AppChannelEnvelope event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    this.onDone = onDone;
    this.onData = onData;
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

/// Journal dont l'ouverture échoue.
class ThrowingOpenLog extends EnvelopeLog {
  ThrowingOpenLog() : super(path: null, nowUnixMs: () => 0);

  @override
  Future<void> open() async => throw StateError('journal');
}
