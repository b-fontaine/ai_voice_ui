import 'dart:async';

import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Faux canal WSS : frontière réseau, piloté par le test via [last]
/// (`add`, `addError`, `close`) ou par [streamBuilder].
class FakeChannel implements AppChannel {
  FakeChannel(this._events);

  final List<String> _events;
  final List<StreamController<AppChannelEnvelope>> controllers =
      <StreamController<AppChannelEnvelope>>[];
  Stream<AppChannelEnvelope> Function(String id)? streamBuilder;
  int cancelCount = 0;

  StreamController<AppChannelEnvelope> get last => controllers.last;

  /// Pousse [envelope] sur le dernier canal ouvert.
  void emit(AppChannelEnvelope envelope) => last.add(envelope);

  /// Fait échouer le dernier canal ouvert.
  void fail(Object error) => last.addError(error);

  /// Ferme le dernier canal ouvert (fin de flux).
  Future<void> close() => last.close();

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
