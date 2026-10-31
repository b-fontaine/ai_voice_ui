import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('actif seulement en session Active et hors Interrupted', () {
    expect(canSilence(const Active(), const Listening()), isTrue);
    expect(canSilence(const Active(), const Speaking()), isTrue);
    expect(canSilence(const Active(), const Interrupted()), isFalse);
    expect(canSilence(const Idle(), const Speaking()), isFalse);
    expect(canSilence(const Connecting(), const Listening()), isFalse);
  });
}
