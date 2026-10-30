import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Faux relais HTTP : frontière réseau. Journalise `relay.create` et
/// `relay.delete(<id>)`.
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
