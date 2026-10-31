import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

Widget _box(Widget child, {double width = 200}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: width, child: child),
  ),
);

const TextStyle _style = TextStyle(fontFamily: 'Noto Sans', fontSize: 24);

void main() {
  setUpAll(loadRealFonts);

  testWidgets('un texte trop long pour sa ligne unique est détecté', (
    tester,
  ) async {
    await tester.pumpWidget(
      _box(
        const Text(
          'Un libellé nettement trop long pour tenir sur une seule ligne',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style,
        ),
      ),
    );

    expect(paragraphsTruncated(tester), hasLength(1));
    expect(
      paragraphsTruncated(tester).single,
      contains('Un libellé nettement trop long'),
    );
  });

  testWidgets('un texte court n\'est pas signalé', (tester) async {
    await tester.pumpWidget(
      _box(const Text('Court', maxLines: 1, style: _style)),
    );

    expect(paragraphsTruncated(tester), isEmpty);
  });

  testWidgets('un texte qui passe à la ligne sans dépasser maxLines n\'est pas '
      'signalé', (tester) async {
    await tester.pumpWidget(
      _box(
        const Text(
          'Un libellé assez long pour passer à la ligne',
          maxLines: 5,
          style: _style,
        ),
      ),
    );

    expect(paragraphsTruncated(tester), isEmpty);
  });

  testWidgets('un libellé de crash (clé crash-label-*) est exclu : son '
      'ellipse est voulue', (tester) async {
    await tester.pumpWidget(
      _box(
        const Text(
          'Un libellé de crash nettement trop long pour sa ligne',
          key: Key('crash-label-1'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style,
        ),
      ),
    );

    expect(paragraphsTruncated(tester), isEmpty);
  });

  testWidgets('root limite la recherche à un sous-arbre', (tester) async {
    await tester.pumpWidget(
      _box(
        const Column(
          children: <Widget>[
            SizedBox(
              key: Key('inside'),
              width: 200,
              child: Text(
                'Un libellé nettement trop long pour tenir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style,
              ),
            ),
            SizedBox(
              key: Key('outside'),
              width: 200,
              child: Text('Court', maxLines: 1, style: _style),
            ),
          ],
        ),
      ),
    );

    expect(
      paragraphsTruncated(tester, root: find.byKey(const Key('outside'))),
      isEmpty,
    );
    expect(
      paragraphsTruncated(tester, root: find.byKey(const Key('inside'))),
      hasLength(1),
    );
  });

  testWidgets('un texte sans maxLines coupé verticalement par son parent est '
      'détecté', (tester) async {
    await tester.pumpWidget(
      _box(
        const SizedBox(
          height: 20,
          child: Text(
            'Un libellé assez long pour passer sur plusieurs lignes',
            style: _style,
          ),
        ),
      ),
    );

    expect(paragraphsTruncated(tester), hasLength(1));
  });

  testWidgets('un texte sans maxLines qui tient dans sa hauteur n\'est pas '
      'signalé', (tester) async {
    await tester.pumpWidget(
      _box(
        const Text(
          'Un libellé assez long pour passer sur plusieurs lignes',
          style: _style,
        ),
      ),
    );

    expect(paragraphsTruncated(tester), isEmpty);
  });

  testWidgets('un libellé de crash coupé verticalement reste exclu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _box(
        const SizedBox(
          height: 20,
          child: Text(
            'Un libellé de crash assez long pour passer sur plusieurs lignes',
            key: Key('crash-label-2'),
            style: _style,
          ),
        ),
      ),
    );

    expect(paragraphsTruncated(tester), isEmpty);
  });
}
