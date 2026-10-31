import 'package:feature_canvas/src/catalog/text_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Police de test (Ahem) : chaque glyphe fait la taille de la police, donc la
/// largeur et le nombre de lignes se calculent de tête.
const TextStyle _style = TextStyle(fontSize: 10, height: 1, fontFamily: 'Ahem');

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('measureTextHeight : une ligne quand la largeur suffit', (
    tester,
  ) async {
    final BuildContext context = await _pumpContext(tester);
    expect(measureTextHeight(context, 'aaaa', _style, 100), 10);
  });

  testWidgets(
    'measureTextHeight : le texte passe à la ligne à largeur donnée',
    (tester) async {
      final BuildContext context = await _pumpContext(tester);
      // « aaaa » (40 px) tient sur 50 px, pas « aaaa bbbb » : deux lignes.
      expect(measureTextHeight(context, 'aaaa bbbb', _style, 50), 20);
      // Trois mots de quatre glyphes, un par ligne.
      expect(measureTextHeight(context, 'aaaa bbbb cccc', _style, 50), 30);
    },
  );

  testWidgets(
    'measureTextHeight : la hauteur de ligne du style est respectée',
    (tester) async {
      final BuildContext context = await _pumpContext(tester);
      final TextStyle tall = _style.copyWith(height: 1.5);
      expect(measureTextHeight(context, 'aaaa bbbb', tall, 50), 30);
    },
  );
}
