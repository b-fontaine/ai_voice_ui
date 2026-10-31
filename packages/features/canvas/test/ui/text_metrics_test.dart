import 'package:feature_canvas/src/catalog/text_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

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

  test('lineHeightOf : taille de police fois hauteur de ligne', () {
    expect(lineHeightOf(_style.copyWith(fontSize: 20, height: 1.5)), 30);
  });

  test('lineHeightOf : hauteur de ligne absente = 1, taille absente = 24', () {
    expect(lineHeightOf(const TextStyle(fontSize: 20)), 20);
    expect(lineHeightOf(const TextStyle()), 24);
  });

  testWidgets(
    'MoreLine : texte et clé donnés, hauteur fixée, aligné à gauche',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
          ),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: MoreLine(
                  textKey: Key('more'),
                  text: '+ 3 autres',
                  height: 30,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('more')), findsOneWidget);
      expect(find.text('+ 3 autres'), findsOneWidget);
      expect(tester.getSize(find.byType(MoreLine)).height, 30);
      expect(tester.getTopLeft(find.byKey(const Key('more'))).dx, 0);
      final SceneTheme theme = SceneTheme.dark();
      final TextStyle style = tester
          .widget<Text>(find.byKey(const Key('more')))
          .style!;
      expect(style.color, theme.textSecondary);
      expect(style.fontSize, theme.body.fontSize);
    },
  );
}
