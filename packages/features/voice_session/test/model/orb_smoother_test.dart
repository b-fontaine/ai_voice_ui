import 'package:feature_voice_session/src/model/orb_smoother.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const OrbSmoother smoother = OrbSmoother();
  const Duration frame = Duration(milliseconds: 16);

  test('monte plus vite qu\'il ne descend', () {
    final double up = smoother.step(0.0, 1.0, frame);
    final double down = smoother.step(1.0, 0.0, frame);
    expect(up, greaterThan(1.0 - down));
  });

  test('applique alpha = 1 - exp(-dt/tau)', () {
    final double up = smoother.step(0.0, 1.0, const Duration(milliseconds: 80));
    expect(up, closeTo(1 - 0.36787944117, 1e-6));
    final double down = smoother.step(
      1.0,
      0.0,
      const Duration(milliseconds: 250),
    );
    expect(down, closeTo(0.36787944117, 1e-6));
  });

  test('converge vers la cible', () {
    double v = 0;
    for (int i = 0; i < 200; i++) {
      v = smoother.step(v, 0.7, frame);
    }
    expect(v, 0.7);
  });

  test('accroche exactement la cible sous epsilon', () {
    expect(smoother.step(0.5, 0.5015, frame), 0.5015);
    expect(smoother.step(0.001, 0.0, frame), 0.0);
  });

  test('dt nul ou négatif laisse la valeur inchangée', () {
    expect(smoother.step(0.3, 1.0, Duration.zero), 0.3);
    expect(smoother.step(0.3, 1.0, const Duration(milliseconds: -5)), 0.3);
  });

  test('le résultat reste dans 0..1', () {
    expect(smoother.step(2.0, 5.0, frame), inInclusiveRange(0.0, 1.0));
    expect(smoother.step(-2.0, -5.0, frame), inInclusiveRange(0.0, 1.0));
  });

  test('NaN et infini en entrée ne produisent jamais NaN', () {
    for (final double bad in <double>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final double a = smoother.step(bad, 0.5, frame);
      final double b = smoother.step(0.5, bad, frame);
      expect(a.isNaN, isFalse);
      expect(b.isNaN, isFalse);
      expect(a, inInclusiveRange(0.0, 1.0));
      expect(b, inInclusiveRange(0.0, 1.0));
    }
  });
}
