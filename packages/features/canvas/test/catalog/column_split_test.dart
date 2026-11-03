import 'package:feature_canvas/src/catalog/column_split.dart';
import 'package:flutter_test/flutter_test.dart';

/// Partage des largeurs de la checklist : le seuil et la puce gardent leur
/// largeur naturelle ; le critère et la valeur se partagent le reste.
void main() {
  const natural = (label: 200.0, threshold: 80.0, value: 120.0);
  const chip = 60.0;
  // 460 de contenu naturel : 80 + 60 de seuil et de puce, 320 pour les deux.
  const mins = (label: 40.0, value: 30.0);

  // Hauteur des lignes : le critère (texte de 4 000 px de surface) et la
  // valeur (texte de 1 000 px) passent à la ligne selon leur largeur.
  double rows(double label, double value) =>
      (4000 / label).ceilToDouble() + (1000 / value).ceilToDouble();

  ColumnWidths split(double available, {int steps = 32}) => splitColumns(
    available: available,
    natural: natural,
    chip: chip,
    minimums: () => mins,
    rowsHeight: rows,
    steps: steps,
  );

  test('tient d\'emblée : le critère prend le surplus', () {
    final ColumnWidths w = split(500);
    expect(w.label, 240);
    expect(w.threshold, 80);
    expect(w.value, 120);
  });

  test('tient exactement : aucune largeur ne change', () {
    final ColumnWidths w = split(460);
    expect((w.label, w.threshold, w.value), (200.0, 80.0, 120.0));
  });

  test('largeur infinie : largeurs naturelles', () {
    final ColumnWidths w = split(double.infinity);
    expect((w.label, w.threshold, w.value), (200.0, 80.0, 120.0));
  });

  test('ne tient pas : le partage qui donne les lignes les moins hautes', () {
    final ColumnWidths w = split(400);
    // Reste pour le critère et la valeur : 400 - 80 - 60 = 260.
    expect(w.label + w.value, closeTo(260, 1e-9));
    expect(w.threshold, 80);
    // Aucun des 33 partages essayés ne donne des lignes moins hautes.
    final double best = rows(w.label, w.value);
    for (int step = 0; step <= 32; step++) {
      final double label = 40 + (260 - 30 - 40) * step / 32;
      expect(rows(label, 260 - label), greaterThanOrEqualTo(best));
    }
    expect(w.label, greaterThanOrEqualTo(40));
    expect(w.value, greaterThanOrEqualTo(30));
  });

  test('à égalité de hauteur, le plus proche du partage proportionnel', () {
    final ColumnWidths w = splitColumns(
      available: 400,
      natural: natural,
      chip: chip,
      minimums: () => mins,
      rowsHeight: (double label, double value) => 1,
    );
    // Proportionnel : 260 x 200 / 320 = 162,5 ; le pas le plus proche.
    expect((w.label - 162.5).abs(), lessThanOrEqualTo(190 / 32 / 2));
  });

  test('borne basse : juste de quoi garder les mots entiers', () {
    // 80 + 60 + 40 + 30 : le critère et la valeur sont à leur plus petit.
    final ColumnWidths w = splitColumns(
      available: 210,
      natural: natural,
      chip: chip,
      minimums: () => mins,
      rowsHeight: (double label, double value) => value,
    );
    expect(w.label, 40);
    expect(w.value, 30);
  });

  test('trop étroit : tout rétrécit proportionnellement, la puce reste', () {
    final ColumnWidths w = split(160);
    // Reste : 160 - 60 = 100 pour 400 de contenu : k = 0,25.
    expect(w.label, 50);
    expect(w.threshold, 20);
    expect(w.value, 30);
  });

  test('moins de place que la puce : les colonnes s\'annulent', () {
    final ColumnWidths w = split(50);
    expect((w.label, w.threshold, w.value), (0.0, 0.0, 0.0));
  });

  test('les minimums ne sont demandés que si la ligne ne tient pas', () {
    int asked = 0;
    splitColumns(
      available: 500,
      natural: natural,
      chip: chip,
      minimums: () {
        asked++;
        return mins;
      },
      rowsHeight: rows,
    );
    expect(asked, 0);
  });
}
