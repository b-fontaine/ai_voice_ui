import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';

void main() {
  const table = <(String, VoiceFailure, String)>[
    ('BackendUnreachable', BackendUnreachable(), 'Backend injoignable'),
    ('RateLimited sans délai', RateLimited(null), 'Trop de demandes'),
    (
      'RateLimited avec délai',
      RateLimited(Duration(seconds: 12)),
      'Trop de demandes, réessayez dans 12 s',
    ),
    ('RelayFailed', RelayFailed(), 'Le relais a échoué'),
    ('MicUnavailable', MicUnavailable(), 'Micro indisponible'),
    ('IceTimeout', IceTimeout(), 'Connexion WebRTC trop lente'),
    ('ConnectionLost', ConnectionLost(), 'Connexion perdue'),
    ('SessionClosed expired', SessionClosed('expired'), 'Session expirée'),
    ('SessionClosed sans raison', SessionClosed(null), 'Session terminée'),
    (
      'SessionClosed autre raison',
      SessionClosed('quota'),
      'Session terminée (quota)',
    ),
  ];

  for (final (name, failure, expected) in table) {
    test('$name -> « $expected »', () {
      expect(voiceFailureMessage(failure), expected);
    });
  }

  test("un délai inférieur à la seconde s'arrondit à 1 s", () {
    expect(
      voiceFailureMessage(const RateLimited(Duration(milliseconds: 200))),
      'Trop de demandes, réessayez dans 1 s',
    );
  });
}
