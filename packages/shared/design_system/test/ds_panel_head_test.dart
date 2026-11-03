import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

Widget _host(Widget child, {double width = 400}) => MaterialApp(
  theme: ThemeData(extensions: const [SceneTheme.dark()]),
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

const Key _right = Key('right');

void main() {
  testWidgets('étiquette en capitales à gauche, élément à droite', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DsPanelHead(
          label: 'Catalogue',
          trailing: SizedBox(key: _right, width: 60, height: 26),
        ),
      ),
    );
    final Rect label = tester.getRect(findTextIgnoringCase('Catalogue'));
    final Rect right = tester.getRect(find.byKey(_right));
    expect(find.text('Catalogue'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DsPanelHead),
        matching: find.byType(DsCaps),
      ),
      findsOneWidget,
    );
    expect(label.left, 0);
    expect(right.right, 400);
    expect(label.right, lessThan(right.left));
  });

  testWidgets('espacement de 12 px entre la partie gauche et la droite', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DsPanelHead(
          label: 'Une étiquette beaucoup trop longue pour tenir à côté',
          trailing: SizedBox(key: _right, width: 60, height: 26),
        ),
        width: 200,
      ),
    );
    final Rect left = tester.getRect(
      find.descendant(
        of: find.byType(DsPanelHead),
        matching: find.byType(DsCaps),
      ),
    );
    final Rect right = tester.getRect(find.byKey(_right));
    expect(right.left - left.right, 12);
  });

  testWidgets('marge basse de 14 px sous la ligne', (tester) async {
    await tester.pumpWidget(
      _host(
        const DsPanelHead(
          label: 'Catalogue',
          trailing: SizedBox(key: _right, width: 60, height: 26),
        ),
      ),
    );
    // Ligne = élément le plus haut (26 px), alignée au centre.
    expect(tester.getSize(find.byType(DsPanelHead)).height, 26 + 14);
    final Rect row = tester.getRect(find.byKey(_right));
    final Rect label = tester.getRect(findTextIgnoringCase('Catalogue'));
    expect(label.center.dy, closeTo(row.center.dy, 0.5));
  });

  testWidgets('un titre libre peut remplacer l\'étiquette, sans capitales', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DsPanelHead.title(title: 'Release 4.2.0')),
    );
    expect(find.text('Release 4.2.0'), findsOneWidget);
    expect(find.byType(DsCaps), findsNothing);
  });

  testWidgets('wrap : une longue étiquette passe à la ligne, sans ellipse', (
    tester,
  ) async {
    const String long =
        'Sessions sans crash sur Android pendant les sept derniers jours de '
        'la release, tous appareils et toutes versions confondus';
    await tester.pumpWidget(
      _host(
        const DsPanelHead(
          label: long,
          wrap: true,
          trailing: SizedBox(key: _right, width: 60, height: 26),
        ),
        width: 300,
      ),
    );
    final Finder text = findTextIgnoringCase(long);
    final Text widget = tester.widget(text);
    expect(widget.maxLines, isNull);
    expect(widget.overflow, isNot(TextOverflow.ellipsis));
    final double line = widget.style!.fontSize! * widget.style!.height!;
    expect(tester.getSize(text).height, greaterThan(line * 1.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('par défaut, une longue étiquette reste sur une ligne', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DsPanelHead(label: 'Une étiquette trop longue pour la place'),
        width: 120,
      ),
    );
    final Text widget = tester.widget(
      find.descendant(of: find.byType(DsCaps), matching: find.byType(Text)),
    );
    expect(widget.maxLines, 1);
    expect(widget.overflow, TextOverflow.ellipsis);
  });
}
