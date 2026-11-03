import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Non-débordement du KeyIndicator dans sa cellule (polices réelles) : en-tête,
/// valeur de 76 px, jauge avec l'étiquette de la marque, deltas, sans ellipse
/// (risque « régression des 24 px » du plan 019).
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

void main() {
  setUpAll(loadRealFonts);

  for (final Size size in const <Size>[Size(624, 302), Size(936, 302)]) {
    for (final String act in <String>['act1', 'act2']) {
      testWidgets('${size.width.toInt()} x ${size.height.toInt()}, $act : '
          'tout tient dans la cellule', (tester) async {
        tester.view.physicalSize = const Size(1200, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = CatalogHarness(
          'kpi',
          'kpi',
          size: size,
          fontFamily: realFontFamily,
          fontFamilyFallback: realFontFallback,
        );
        await h.pump(tester, motion: _still);
        await h.sendFixtureTo(tester, 3);
        if (act == 'act2') await h.sendVariant(tester, 'act2');

        final Rect cell = tester.getRect(find.byKey(const Key('surface-kpi')));
        expect(cell.size, size);
        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow');
        expect(
          paragraphsTruncated(
            tester,
            root: find.byKey(const Key('surface-kpi')),
          ),
          isEmpty,
        );
        for (final RenderParagraph paragraph
            in tester.renderObjectList<RenderParagraph>(
              find.descendant(
                of: find.byKey(const Key('surface-kpi')),
                matching: find.byType(RichText),
              ),
            )) {
          final Rect box = MatrixUtils.transformRect(
            paragraph.getTransformTo(null),
            Offset.zero & paragraph.size,
          );
          final String what = paragraph.text.toPlainText();
          expect(box.left, greaterThanOrEqualTo(cell.left), reason: what);
          expect(box.right, lessThanOrEqualTo(cell.right + 0.5), reason: what);
          expect(box.top, greaterThanOrEqualTo(cell.top), reason: what);
          expect(box.bottom, lessThanOrEqualTo(cell.bottom), reason: what);
        }
        final Rect deltas = tester.getRect(
          find.byKey(const Key('kpi-delta-trend-value')),
        );
        expect(deltas.bottom, lessThanOrEqualTo(cell.bottom - 16 + 0.5));
        for (final String name in <String>[
          'kpi-gauge-mark-label',
          'kpi-gauge-mark',
          'kpi-gauge',
        ]) {
          final Rect r = tester.getRect(find.byKey(Key(name)));
          expect(r.left, greaterThanOrEqualTo(cell.left));
          expect(r.right, lessThanOrEqualTo(cell.right));
          expect(r.top, greaterThanOrEqualTo(cell.top));
        }
        // Les parties ne se chevauchent pas : valeur, puis jauge, puis deltas.
        final Rect value = tester.getRect(find.byKey(const Key('kpi-value')));
        final Rect markLabel = tester.getRect(
          find.byKey(const Key('kpi-gauge-mark-label')),
        );
        expect(value.bottom, lessThanOrEqualTo(markLabel.top + 0.5));
        expect(
          tester.getRect(find.byKey(const Key('kpi-gauge'))).bottom,
          lessThanOrEqualTo(deltas.top),
        );
      });
    }
  }
}
