/// Faux de frontière de la session voix, partagés par les tests des slices et
/// de l'app : transport WebRTC, relais HTTP, canal WSS, banc `VoiceSession`.
library;

export 'src/envelope_of.dart' show envelopeOf;
export 'src/fake_channel.dart' show FakeChannel;
export 'src/fake_relay.dart' show FakeRelay;
export 'src/fake_transport.dart' show FakeTransport, FakeTransportFactory;
export 'src/voice_harness.dart' show VoiceHarness;
