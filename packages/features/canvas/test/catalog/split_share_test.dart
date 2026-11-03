import 'package:feature_canvas/src/catalog/split_share.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parts de la barre de répartition des avis : fonction pure (T23, 019).
void main() {
  group('splitShares : parts lues des pourcentages', () {
    test('76 % et 24 % : 0,76 et 0,24', () {
      expect(splitShares(76, 24), (positive: 0.76, negative: 0.24));
    });

    test('70 % et 30 %', () {
      expect(splitShares(70, 30), (positive: 0.7, negative: 0.3));
    });

    test('une somme inférieure à 100 laisse un reste neutre', () {
      expect(splitShares(50, 20), (positive: 0.5, negative: 0.2));
    });

    test('0 % et 100 % sont lisibles', () {
      expect(splitShares(0, 100), (positive: 0.0, negative: 1.0));
      expect(splitShares(100, 0), (positive: 1.0, negative: 0.0));
    });

    for (final (int, int) bad in <(int, int)>[
      (-1, 20),
      (20, -1),
      (101, 0),
      (0, 101),
      (60, 60),
    ]) {
      test('${bad.$1} / ${bad.$2} : illisible, pas de barre', () {
        expect(splitShares(bad.$1, bad.$2), isNull);
      });
    }
  });

  group('splitWidths : largeurs de la barre', () {
    const double track = 600;

    test('état final : proportionnel, et l\'écart de 2 px est pris sur les '
        'deux parts', () {
      final ({double positive, double negative}) w = splitWidths(
        track: track,
        shares: (positive: 0.76, negative: 0.24),
        positiveProgress: 1,
        negativeProgress: 1,
      );
      expect(w.positive + w.negative + splitGap, closeTo(track, 1e-9));
      expect(w.positive / w.negative, closeTo(0.76 / 0.24, 1e-9));
    });

    test('somme inférieure à 100 : aucune réduction', () {
      final ({double positive, double negative}) w = splitWidths(
        track: track,
        shares: (positive: 0.5, negative: 0.2),
        positiveProgress: 1,
        negativeProgress: 1,
      );
      expect(w.positive, 300);
      expect(w.negative, 120);
    });

    test('progression à zéro : largeurs nulles', () {
      final ({double positive, double negative}) w = splitWidths(
        track: track,
        shares: (positive: 0.76, negative: 0.24),
        positiveProgress: 0,
        negativeProgress: 0,
      );
      expect(w.positive, 0);
      expect(w.negative, 0);
    });

    test('chaque part suit sa propre progression', () {
      final ({double positive, double negative}) w = splitWidths(
        track: track,
        shares: (positive: 0.5, negative: 0.2),
        positiveProgress: 0.5,
        negativeProgress: 0,
      );
      expect(w.positive, 150);
      expect(w.negative, 0);
    });
  });

  group('splitProgress : progression de chaque part dans le contrôleur', () {
    test('le négatif démarre 200 ms après le positif', () {
      // Contrôleur de 1 600 ms (1 400 ms de remplissage + 200 ms de retard).
      expect(splitPositiveProgress(0), 0);
      expect(splitNegativeProgress(0), 0);
      expect(splitPositiveProgress(0.1), greaterThan(0));
      expect(splitNegativeProgress(0.1), 0);
      expect(splitNegativeProgress(0.125), 0);
      expect(splitPositiveProgress(0.875), 1);
      expect(splitNegativeProgress(0.875), lessThan(1));
      expect(splitPositiveProgress(1), 1);
      expect(splitNegativeProgress(1), 1);
    });
  });
}
