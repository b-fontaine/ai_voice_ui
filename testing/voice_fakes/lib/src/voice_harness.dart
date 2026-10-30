import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

import 'fake_channel.dart';
import 'fake_relay.dart';
import 'fake_transport.dart';

/// Vraie [VoiceSession] construite sur les faux de frontière, avec un journal
/// d'événements commun (`events`).
class VoiceHarness {
  VoiceHarness({
    Duration closeTimeout = const Duration(seconds: 2),
    this.logPath,
  }) {
    relay = FakeRelay(events);
    channel = FakeChannel(events);
    transportFactory = FakeTransportFactory(events.add);
    session = VoiceSession(
      transportFactory: () {
        if (transportFactoryError != null) throw transportFactoryError!;
        final transport = transportFactory();
        onNewTransport?.call(transport);
        return transport;
      },
      relay: relay,
      channel: channel,
      logFactory: () {
        if (logFactoryOverride != null) return logFactoryOverride!();
        return EnvelopeLog(path: logPath, nowUnixMs: () => 1000);
      },
      closeTimeout: closeTimeout,
    );
  }

  final String? logPath;
  final List<String> events = <String>[];
  void Function(FakeTransport transport)? onNewTransport;
  Object? transportFactoryError;
  EnvelopeLog Function()? logFactoryOverride;
  late final FakeTransportFactory transportFactory;
  late final FakeRelay relay;
  late final FakeChannel channel;
  late final VoiceSession session;

  /// Transports créés, dans l'ordre.
  List<FakeTransport> get transports => transportFactory.created;
}
