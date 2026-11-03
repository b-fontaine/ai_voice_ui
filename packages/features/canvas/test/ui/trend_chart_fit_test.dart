import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Non-débordement du graphique dans sa cellule (polices réelles) : titre,
/// légende, valeurs de l'axe, jours, valeur de tête et annotation, sans ellipse
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
          'trend',
          'trend',
          size: size,
          fontFamily: realFontFamily,
          fontFamilyFallback: realFontFallback,
        );
        await h.pump(tester, motion: _still);
        await h.sendFixtureTo(tester, 3);
        if (act == 'act2') await h.sendVariant(tester, 'act2');

        final Finder root = find.byKey(const Key('surface-trend'));
        final Rect cell = tester.getRect(root);
        expect(cell.size, size);
        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow');
        expect(paragraphsTruncated(tester, root: root), isEmpty);
        for (final RenderParagraph paragraph
            in tester.renderObjectList<RenderParagraph>(
              find.descendant(of: root, matching: find.byType(RichText)),
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
        // Le tracé garde de la place, sous la légende ; les jours sont sous
        // le tracé et dans la cellule.
        final Rect plot = tester.getRect(find.byKey(const Key('trend-plot')));
        expect(plot.height, greaterThan(100));
        final Rect legend = tester.getRect(
          find.byKey(const Key('trend-threshold-legend')),
        );
        expect(plot.top, greaterThanOrEqualTo(legend.bottom));
        final Rect lastDay = tester.getRect(
          find.descendant(of: root, matching: find.text('J7')),
        );
        expect(lastDay.top, greaterThanOrEqualTo(plot.bottom));
        expect(lastDay.bottom, lessThanOrEqualTo(cell.bottom - 16 + 0.5));
        // La valeur de tête et l'annotation restent dans le tracé élargi.
        for (final String key in <String>[
          'trend-head-value',
          'trend-callout',
        ]) {
          final Rect r = tester.getRect(find.byKey(Key(key)));
          expect(r.left, greaterThanOrEqualTo(plot.left), reason: key);
          expect(r.right, lessThanOrEqualTo(plot.right + 0.5), reason: key);
          expect(r.top, greaterThanOrEqualTo(plot.top - 0.5), reason: key);
          expect(r.bottom, lessThanOrEqualTo(plot.bottom), reason: key);
        }
        // Valeur de tête et annotation ne se chevauchent pas.
        expect(
          tester
              .getRect(find.byKey(const Key('trend-head-value')))
              .overlaps(tester.getRect(find.byKey(const Key('trend-callout')))),
          isFalse,
        );
      });
    }
  }
}
