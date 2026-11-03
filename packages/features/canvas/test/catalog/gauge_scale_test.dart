import 'package:feature_canvas/src/catalog/gauge_scale.dart';
import 'package:flutter_test/flutter_test.dart';

/// Domaine de la jauge : [⌊min(valeur, seuil, comparaison)⌋, 100] %
/// (pdr-0088 F3).
void main() {
  test('acte 1 : 99,57 / seuil 99,50 : domaine 99 à 100', () {
    final GaugeScale scale = GaugeScale.of(value: 99.57, threshold: 99.5);
    expect(scale.low, 99);
    expect(scale.high, 100);
    expect(scale.fraction(99.57), closeTo(0.57, 1e-9));
    expect(scale.fraction(99.5), closeTo(0.5, 1e-9));
  });

  test('acte 2 : 99,43 / 99,50 / 99,71 : 43 %, 50 %, 71 %', () {
    final GaugeScale scale = GaugeScale.of(
      value: 99.43,
      threshold: 99.5,
      comparison: 99.71,
    );
    expect(scale.low, 99);
    expect(scale.fraction(99.43), closeTo(0.43, 1e-9));
    expect(scale.fraction(99.5), closeTo(0.5, 1e-9));
    expect(scale.fraction(99.71), closeTo(0.71, 1e-9));
  });

  test('le plancher suit la plus petite des valeurs lues', () {
    expect(GaugeScale.of(value: 98.2, threshold: 99.5).low, 98);
    expect(GaugeScale.of(value: 99.9, threshold: 97.1).low, 97);
    expect(
      GaugeScale.of(value: 99.9, threshold: 99.5, comparison: 95.0).low,
      95,
    );
  });

  test('seuil et comparaison absents : seule la valeur compte', () {
    expect(GaugeScale.of(value: 96.4).low, 96);
  });

  test('valeur à 100 % : le domaine ne dégénère pas', () {
    final GaugeScale scale = GaugeScale.of(value: 100);
    expect(scale.low, lessThan(scale.high));
    expect(scale.fraction(100), 1);
  });

  test('une fraction hors domaine est bornée à 0..1', () {
    final GaugeScale scale = GaugeScale.of(value: 99.57);
    expect(scale.fraction(120), 1);
    expect(scale.fraction(10), 0);
  });
}
