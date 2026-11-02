import 'package:feature_canvas/src/catalog/bound_item.dart'
    show CellFrame, NoDataCell;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Les cellules du catalogue n'ont plus de fond ni de rayon (017 T16,
/// pdr-0084 U9) : le fond est la décoration de panneau posée par le canevas.
/// Elles gardent leur marge pour qu'aucun contenu ne bouge.
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

  /// Décorations de boîte sous [root] qui peignent un fond ou un coin arrondi.
  List<BoxDecoration> paintedBackgrounds(WidgetTester tester, Finder root) =>
      <BoxDecoration>[
        for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
          find.descendant(of: root, matching: find.byType(DecoratedBox)),
        ))
          if (box.decoration is BoxDecoration)
            if ((box.decoration as BoxDecoration).color != null ||
                (box.decoration as BoxDecoration).borderRadius != null ||
                (box.decoration as BoxDecoration).gradient != null)
              box.decoration as BoxDecoration,
      ];

  testWidgets('CellFrame : ni fond ni rayon, marge de 16 px conservée', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const CellFrame(
          key: Key('frame'),
          child: SizedBox.expand(key: Key('inside')),
        ),
      ),
    );
    expect(paintedBackgrounds(tester, find.byKey(const Key('frame'))), isEmpty);
    expect(
      tester.getRect(find.byKey(const Key('frame'))).size,
      const Size(400, 300),
    );
    expect(
      tester.getRect(find.byKey(const Key('inside'))),
      const Rect.fromLTWH(16, 16, 368, 268),
    );
  });

  testWidgets('CellFrame : la marge personnalisée de la Barre d\'actions '
      'reste respectée', (tester) async {
    await tester.pumpWidget(
      host(
        const CellFrame(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox.expand(key: Key('inside')),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const Key('inside'))),
      const Rect.fromLTWH(16, 12, 368, 276),
    );
  });

  testWidgets('NoDataCell : remplit la cellule sans fond ni rayon', (
    tester,
  ) async {
    await tester.pumpWidget(host(const NoDataCell(key: Key('nodata'))));
    expect(
      paintedBackgrounds(tester, find.byKey(const Key('nodata'))),
      isEmpty,
    );
    expect(
      tester.getRect(find.byKey(const Key('nodata'))),
      const Rect.fromLTWH(0, 0, 400, 300),
    );
  });
}
