import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Barre de répartition des avis (`gc-split`, pdr-0088 F1/F13, T23 de 019) :
/// 10 px, rayon 5, fond `surface-300`, part positive à gauche, part négative à
/// droite, remplissage en 1,4 s (le négatif avec 200 ms de retard).
const ({bool disabled, double speed}) _live = (disabled: false, speed: 1);
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);
const SceneTheme _theme = SceneTheme.dark();

Future<CatalogHarness> _start(
  WidgetTester tester, {
  ({bool disabled, double speed}) motion = _still,
  int messages = 3,
}) async {
  final h = CatalogHarness(
    'reviews',
    'reviews',
    size: const Size(624, 302),
    fontFamily: realFontFamily,
    fontFamilyFallback: realFontFallback,
  );
  await h.pump(tester, motion: motion);
  await h.sendFixtureTo(tester, messages);
  return h;
}

Finder _key(String name) => find.byKey(Key(name));

double _percent(WidgetTester tester, String part) =>
    tester.getSize(_key(part)).width /
    tester.getSize(_key('reviews-split')).width *
    100;

Color? _fill(String name) {
  for (final Element e
      in find
          .descendant(
            of: _key(name),
            matching: find.byWidgetPredicate(
              (Widget w) => w is ColoredBox || w is DecoratedBox,
            ),
            matchRoot: true,
          )
          .evaluate()) {
    final Widget w = e.widget;
    if (w is ColoredBox) return w.color;
    final Decoration d = (w as DecoratedBox).decoration;
    if (d is BoxDecoration && d.color != null) return d.color;
  }
  return null;
}

void main() {
  setUpAll(loadRealFonts);

  group('état final', () {
    testWidgets('76 % et 24 % de la barre, 10 px de haut, positif à gauche', (
      tester,
    ) async {
      await _start(tester);
      expect(_percent(tester, 'reviews-split-pos'), closeTo(76, 1));
      expect(_percent(tester, 'reviews-split-neg'), closeTo(24, 1));
      expect(tester.getSize(_key('reviews-split')).height, 10);
      expect(
        tester.getRect(_key('reviews-split-pos')).left,
        tester.getRect(_key('reviews-split')).left,
      );
      expect(
        tester.getRect(_key('reviews-split-neg')).right,
        closeTo(tester.getRect(_key('reviews-split')).right, 0.01),
      );
      expect(
        tester.getRect(_key('reviews-split-neg')).left -
            tester.getRect(_key('reviews-split-pos')).right,
        closeTo(2, 0.01),
        reason: 'gap de 2 px entre les deux parts',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('fond surface-300, rayon 5 (arrondi), couleurs go et nogo', (
      tester,
    ) async {
      await _start(tester);
      expect(_fill('reviews-split'), _theme.surface300);
      expect(_fill('reviews-split-pos'), _theme.okForeground);
      expect(_fill('reviews-split-neg'), _theme.blockingForeground);
      final ClipRRect clip = tester.widget(
        find.descendant(
          of: _key('reviews-split'),
          matching: find.byType(ClipRRect),
        ),
      );
      final BorderRadius radius = clip.borderRadius as BorderRadius;
      expect(radius.topLeft.x, greaterThanOrEqualTo(5));
    });

    testWidgets('sous disableAnimations : l\'état final est aussitôt là, '
        'sans animation en cours', (tester) async {
      await _start(tester);
      expect(_percent(tester, 'reviews-split-pos'), closeTo(76, 1));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('remplissage animé', () {
    testWidgets('part de 0, positif en avance, négatif retardé de 200 ms', (
      tester,
    ) async {
      await _start(tester, motion: _live);
      expect(_percent(tester, 'reviews-split-pos'), 0);
      expect(_percent(tester, 'reviews-split-neg'), 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(_percent(tester, 'reviews-split-pos'), greaterThan(0));
      expect(_percent(tester, 'reviews-split-pos'), lessThan(50));
      expect(
        _percent(tester, 'reviews-split-neg'),
        0,
        reason: 'le négatif attend 200 ms',
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(_percent(tester, 'reviews-split-neg'), greaterThan(0));
      expect(_percent(tester, 'reviews-split-pos'), lessThan(76));
    });

    testWidgets('au bout de 1,6 s : 76 % et 24 %', (tester) async {
      await _start(tester, motion: _live);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(_percent(tester, 'reviews-split-pos'), closeTo(76, 1));
      expect(_percent(tester, 'reviews-split-neg'), closeTo(24, 1));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('la vitesse de rejeu accélère le remplissage', (tester) async {
      await _start(tester, motion: (disabled: false, speed: 2));
      await tester.pump(const Duration(milliseconds: 850));
      expect(_percent(tester, 'reviews-split-pos'), closeTo(76, 1));
    });

    testWidgets('un seul contrôleur pour la barre et les cartes', (
      tester,
    ) async {
      await _start(tester, motion: _live);
      // Comme la cascade de la checklist : les contrôleurs de la surface et
      // celui des avis, jamais un par carte ni par part.
      expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(3));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('mise à jour des données', () {
    testWidgets('premier data seulement : une mise à jour change les largeurs '
        'sur place, sans nouveau remplissage', (tester) async {
      final h = await _start(tester, motion: _live);
      await tester.pump(const Duration(seconds: 3));
      await h.sendData(
        tester,
        cloneJson(h.data)
          ..['positivePct'] = 60
          ..['negativePct'] = 40,
      );
      expect(_percent(tester, 'reviews-split-pos'), closeTo(60, 1));
      expect(_percent(tester, 'reviews-split-neg'), closeTo(40, 1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(h.inCell(find.textContaining('60 % positifs')), findsOneWidget);
    });

    testWidgets('pourcentage illisible : barre absente, textes tels quels', (
      tester,
    ) async {
      final h = await _start(tester);
      await h.sendData(
        tester,
        cloneJson(h.data)
          ..['positivePct'] = 150
          ..['negativePct'] = 24,
      );
      expect(_key('reviews-split'), findsNothing);
      expect(_key('reviews-split-pos'), findsNothing);
      expect(h.inCell(find.textContaining('150 % positifs')), findsOneWidget);
      expect(h.inCell(find.textContaining('24 % négatifs')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('légende et en-tête', () {
    testWidgets('légende : 76 % positifs en go, 24 % négatifs en nogo, à '
        'gauche et à droite', (tester) async {
      await _start(tester);
      final Text pos = tester.widget(_key('reviews-legend-pos'));
      final Text neg = tester.widget(_key('reviews-legend-neg'));
      expect(pos.data, '76 % positifs');
      expect(neg.data, '24 % négatifs');
      expect(pos.style?.color, _theme.okForeground);
      expect(neg.style?.color, _theme.blockingForeground);
      expect(pos.style?.fontSize, _theme.micro.delta.fontSize);
      expect(pos.style?.fontWeight, FontWeight.w600);
      expect(
        tester.getTopLeft(_key('reviews-legend-pos')).dx,
        lessThan(tester.getTopLeft(_key('reviews-legend-neg')).dx),
      );
      expect(
        tester.getRect(_key('reviews-legend-neg')).right,
        closeTo(tester.getRect(_key('reviews-split')).right, 0.01),
      );
    });

    testWidgets('en-tête : titre à gauche, « 1164 avis · 4,0 ★ » en mono '
        'ink-muted à droite', (tester) async {
      final h = await _start(tester);
      final Finder summary = h.inCell(find.text('1164 avis · 4,0 ★'));
      expect(summary, findsOneWidget);
      final Text text = tester.widget(summary);
      expect(text.style?.color, _theme.textSecondary);
      expect(text.style?.fontSize, _theme.micro.legend.fontSize);
      expect(
        tester.getTopLeft(h.inCell(find.text('Sentiment des avis'))).dx,
        lessThan(tester.getTopLeft(summary).dx),
      );
    });
  });
}
