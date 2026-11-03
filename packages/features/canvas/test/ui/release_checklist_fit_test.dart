import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Non-débordement de la checklist dans sa cellule (polices réelles) : en-tête,
/// tableau et lignes, sans ellipse (risque « régression des 24 px » de 019).
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

void main() {
  setUpAll(loadRealFonts);

  for (final Size size in const <Size>[Size(624, 302), Size(936, 302)]) {
    for (final String act in <String>['act1', 'act2', 'act3']) {
      testWidgets('${size.width.toInt()} x ${size.height.toInt()}, $act : '
          'tout tient dans la cellule', (tester) async {
        tester.view.physicalSize = const Size(1200, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = CatalogHarness(
          'checklist',
          'checklist',
          size: size,
          fontFamily: realFontFamily,
          fontFamilyFallback: realFontFallback,
        );
        await h.pump(tester, motion: _still);
        await h.sendFixtureTo(tester, 3);
        if (act != 'act1') await h.sendVariant(tester, 'act2');
        if (act == 'act3') {
          final data = cloneJson(h.data);
          data['decisionStatus'] = 'Bloquée';
          await h.sendData(tester, data);
        }

        final Finder root = find.byKey(const Key('surface-checklist'));
        final Rect cell = tester.getRect(root);
        expect(cell.size, size);
        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow');
        expect(h.engineErrors, isEmpty);
        expect(paragraphsTruncated(tester, root: root), isEmpty);
        for (final RenderBox box in tester.renderObjectList<RenderBox>(
          find.descendant(
            of: root,
            matching: find.byWidgetPredicate(
              (Widget w) =>
                  w is RichText ||
                  (w.key is ValueKey<String> &&
                      (w.key! as ValueKey<String>).value.startsWith(
                        'checklist-row-',
                      )),
            ),
          ),
        )) {
          final Rect rect = MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          );
          final String what = box is RenderParagraph
              ? box.text.toPlainText()
              : box.runtimeType.toString();
          expect(
            rect.left,
            greaterThanOrEqualTo(cell.left + 15.5),
            reason: what,
          );
          expect(
            rect.right,
            lessThanOrEqualTo(cell.right - 15.5),
            reason: what,
          );
          expect(rect.top, greaterThanOrEqualTo(cell.top + 15.5), reason: what);
          expect(
            rect.bottom,
            lessThanOrEqualTo(cell.bottom - 15.5),
            reason: what,
          );
        }
        // Les trois critères tiennent dans la grande cellule.
        if (size.width == 936) {
          expect(find.byKey(const Key('checklist-more')), findsNothing);
          expect(find.byKey(const Key('checklist-row-2')), findsOneWidget);
        }
      });
    }
  }
}
