import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// `DsSkeleton` et `DsNeutralState` ne peignent plus le fond ni le rayon du
/// panneau (017 T16, pdr-0084 U9) : la décoration posée par le canevas est le
/// fond. Ils gardent leur marge de 16 px.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(
      extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
    ),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, height: 300, child: child),
    ),
  );

  testWidgets('DsNeutralState : aucun fond ni rayon de panneau, marge de '
      '16 px', (tester) async {
    await tester.pumpWidget(host(const DsNeutralState(key: Key('neutral'))));
    expect(
      find.descendant(
        of: find.byKey(const Key('neutral')),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    // Le contenu ne bouge pas : 16 px du bord gauche, centré en hauteur
    // comme avant (la rangée est centrée dans la cellule de 300 px).
    expect(tester.getTopLeft(find.byType(Icon)).dx, 16);
    expect(tester.getCenter(find.byType(Icon)).dy, 150);
  });

  testWidgets('DsSkeleton : couvre la cellule sans fond de panneau ; seul le '
      'bloc grisé, à 16 px du bord, pulse', (tester) async {
    await tester.pumpWidget(host(const DsSkeleton(key: Key('sk'))));
    expect(
      tester.getRect(find.byKey(const Key('sk'))),
      const Rect.fromLTWH(0, 0, 400, 300),
    );
    final Finder blocks = find.descendant(
      of: find.byKey(const Key('sk')),
      matching: find.byType(DecoratedBox),
    );
    expect(blocks, findsOneWidget);
    expect(
      tester.getRect(blocks),
      const Rect.fromLTWH(16, 16, 368, 268),
      reason: 'bloc grisé, à la marge de 16 px',
    );
    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(blocks).decoration as BoxDecoration;
    expect(
      decoration.borderRadius,
      SceneRadius.borderMd,
      reason: 'ni le rayon 12 d\'avant ni le rayon 16 du panneau',
    );
  });
}
