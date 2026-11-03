import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Verbatims en cartes (`gc-quote`, pdr-0088 F1/F5, T23 de 019) : carte
/// `surface-300`, rayon `md`, padding 12 × 14, note et plateforme à gauche,
/// texte à droite, 10 px entre cartes, apparition sans flou.
const ({bool disabled, double speed}) _live = (disabled: false, speed: 1);
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);
const SceneTheme _theme = SceneTheme.dark();

final Finder _cell = find.byKey(const Key('surface-reviews'));

Future<CatalogHarness> _start(
  WidgetTester tester, {
  Size size = const Size(936, 500),
  ({bool disabled, double speed}) motion = _still,
  int messages = 3,
  String? variant,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = CatalogHarness(
    'reviews',
    'reviews',
    size: size,
    fontFamily: realFontFamily,
    fontFamilyFallback: realFontFallback,
  );
  await h.pump(tester, motion: motion);
  await h.sendFixtureTo(tester, messages);
  if (variant != null) await h.sendVariant(tester, variant);
  return h;
}

Finder _card(int n) => find.byKey(Key('reviews-card-$n'));
Finder _meta(int n) => find.byKey(Key('reviews-card-$n-meta'));
Finder _text(int n) => find.byKey(Key('reviews-card-$n-text'));

String _plain(WidgetTester tester, Finder finder) {
  final Text text = tester.widget(finder);
  return text.data ?? text.textSpan!.toPlainText();
}

/// Opacité propre à la carte (celle de la surface exclue).
double _opacity(WidgetTester tester, int n) {
  double of(RenderObject? start) {
    var opacity = 1.0;
    for (RenderObject? r = start; r != null; r = r.parent) {
      if (r is RenderOpacity) opacity *= r.opacity;
      if (r is RenderAnimatedOpacity) opacity *= r.opacity.value;
    }
    return opacity;
  }

  return of(tester.renderObject(_card(n))) /
      of(tester.renderObject(find.byType(Surface)));
}

/// Nombre de `N` de « + N avis », ou `null`.
int? _hidden(WidgetTester tester) {
  for (final Text text in tester.widgetList<Text>(
    find.descendant(of: _cell, matching: find.byType(Text)),
  )) {
    final RegExpMatch? m = RegExp(r'^\+ (\d+) avis$')
        .firstMatch(text.data ?? '');
    if (m != null) return int.parse(m.group(1)!);
  }
  return null;
}

int _shown(WidgetTester tester) {
  var n = 0;
  while (_card(n).evaluate().isNotEmpty) {
    n++;
  }
  return n;
}

void main() {
  setUpAll(loadRealFonts);

  group('carte', () {
    testWidgets('acte 1, cellule haute : trois cartes, texte intégral', (
      tester,
    ) async {
      await _start(tester);
      expect(_shown(tester), 3);
      expect(_hidden(tester), isNull);
      expect(_plain(tester, _meta(0)), '1★ Android');
      expect(_plain(tester, _meta(1)), '5★ iOS');
      expect(_plain(tester, _meta(2)), '2★ Android');
      expect(
        _plain(tester, _text(0)),
        "L'app se ferme dès que je valide mon panier. "
        'Impossible de payer depuis la mise à jour.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('surface-300, rayon md, padding 12 x 14', (tester) async {
      await _start(tester);
      final DecoratedBox box = tester.widget(
        find.descendant(
          of: _card(0),
          matching: find.byType(DecoratedBox),
          matchRoot: true,
        ),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      expect(decoration.color, _theme.surface300);
      expect(decoration.borderRadius, SceneRadius.borderMd);

      expect(
        tester.getTopLeft(_meta(0)).dx - tester.getTopLeft(_card(0)).dx,
        14,
      );
      expect(
        tester.getTopLeft(_meta(0)).dy - tester.getTopLeft(_card(0)).dy,
        12,
      );
      expect(
        tester.getTopLeft(_text(0)).dy - tester.getTopLeft(_card(0)).dy,
        12,
      );
      expect(
        tester.getRect(_card(0)).right - tester.getRect(_text(0)).right,
        greaterThanOrEqualTo(14),
      );
    });

    testWidgets('méta à gauche du texte, espace de 12 px, cartes à 10 px '
        'l\'une de l\'autre', (tester) async {
      await _start(tester);
      expect(
        tester.getTopLeft(_text(0)).dx - tester.getRect(_meta(0)).right,
        closeTo(12, 1),
      );
      for (var n = 1; n < 3; n++) {
        expect(
          tester.getTopLeft(_card(n)).dy - tester.getRect(_card(n - 1)).bottom,
          10,
          reason: 'carte $n',
        );
      }
      // Les textes sont alignés en colonne comme dans la grille de la source
      // (une colonne par carte : chaque méta a sa propre largeur).
      expect(tester.getSize(_card(0)).width, tester.getSize(_card(1)).width);
    });

    testWidgets('méta : note en nogo, plateforme en ink-muted (quoteMeta)', (
      tester,
    ) async {
      await _start(tester);
      final Text meta = tester.widget(_meta(0));
      expect(meta.style?.fontSize, _theme.micro.quoteMeta.fontSize);
      expect(meta.style?.color, _theme.textSecondary);
      final TextSpan root = meta.textSpan! as TextSpan;
      final TextSpan stars = root.children!.first as TextSpan;
      expect(stars.text, '1★');
      expect(stars.style?.color, _theme.blockingForeground);
      expect(meta.softWrap, isFalse);
    });

    testWidgets('texte : micro.quote (15 px), jamais coupé', (tester) async {
      await _start(tester);
      final Text text = tester.widget(_text(0));
      expect(text.style?.fontSize, _theme.micro.quote.fontSize);
      expect(text.style?.height, _theme.micro.quote.height);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });

  group('apparition (gc-rise sans flou)', () {
    testWidgets('aucun flou dans la surface des avis', (tester) async {
      await _start(tester, motion: _live);
      await tester.pump(const Duration(milliseconds: 100));
      // Seul le flou d'apparition de la surface (DsRise) existe : ni les
      // cartes ni rien dans la cellule n'en ajoutent.
      expect(
        find.descendant(of: _cell, matching: find.byType(ImageFiltered)),
        findsOneWidget,
      );
      for (var n = 0; n < 3; n++) {
        expect(
          find.descendant(of: _card(n), matching: find.byType(ImageFiltered)),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: _cell, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('les cartes arrivent l\'une après l\'autre : opacité et '
        'glissement de 10 px', (tester) async {
      await _start(tester, motion: _live);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacity(tester, 0), greaterThan(0.05));
      expect(_opacity(tester, 0), lessThan(1));
      expect(_opacity(tester, 2), lessThan(0.01));
      // Les cartes 1 et 2 n'ont pas commencé (elles gardent 10 px de
      // retard) ; la carte 0 en a déjà rattrapé une partie.
      final double early =
          tester.getTopLeft(_card(1)).dy - tester.getTopLeft(_card(0)).dy;

      await tester.pump(const Duration(seconds: 3));
      for (var n = 0; n < 3; n++) {
        expect(_opacity(tester, n), 1, reason: 'carte $n');
      }
      final double settled =
          tester.getTopLeft(_card(1)).dy - tester.getTopLeft(_card(0)).dy;
      expect(early - settled, inInclusiveRange(1, 10));
    });

    testWidgets('sous disableAnimations : cartes en place aussitôt', (
      tester,
    ) async {
      await _start(tester);
      for (var n = 0; n < 3; n++) {
        expect(_opacity(tester, n), 1, reason: 'carte $n');
      }
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('une mise à jour du texte ne rejoue pas l\'apparition', (
      tester,
    ) async {
      final h = await _start(tester, motion: _live);
      await tester.pump(const Duration(seconds: 3));
      final data = cloneJson(h.data);
      (data['excerpts'] as List)[1]['text'] = 'Très bien.';
      await h.sendData(tester, data);
      await tester.pump(const Duration(milliseconds: 20));
      for (var n = 0; n < 3; n++) {
        expect(_opacity(tester, n), 1, reason: 'carte $n');
      }
      expect(_plain(tester, _text(1)), 'Très bien.');
    });
  });

  group(
    'cellules réelles : ni débordement, ni troncature, extraits entiers',
    () {
      for (final Size size in <Size>[
        const Size(624, 302),
        const Size(936, 302),
      ]) {
        for (final String? variant in <String?>[null, 'act2']) {
          testWidgets('${size.width.toInt()} x ${size.height.toInt()}, '
              '${variant == null ? 'acte 1' : 'acte 2'}', (tester) async {
            final h = await _start(tester, size: size, variant: variant);
            final int shown = _shown(tester);
            expect(shown, inInclusiveRange(1, 3));
            expect(_hidden(tester), shown == 3 ? isNull : 3 - shown);
            expect(paragraphsTruncated(tester, root: _cell), isEmpty);
            h.expectTextAtLeastScaleMinimum(tester);
            // Tout reste dans la cellule (marge de 16 px comprise).
            final Rect cell = tester.getRect(_cell);
            for (var n = 0; n < shown; n++) {
              expect(
                tester.getRect(_card(n)).bottom,
                lessThanOrEqualTo(cell.bottom - 16 + 0.01),
                reason: 'carte $n dans la cellule',
              );
              expect(
                tester.getRect(_card(n)).right,
                lessThanOrEqualTo(cell.right - 16 + 0.01),
              );
            }
            expect(tester.takeException(), isNull);
            expect(h.engineErrors, isEmpty);
          });
        }
      }

      testWidgets(
        'un extrait trop long n\'est pas affiché : jamais d\'ellipse',
        (tester) async {
          final h = await _start(tester, size: const Size(624, 302));
          final data = cloneJson(h.data);
          (data['excerpts'] as List)[0]['text'] = 'très long ' * 80;
          await h.sendData(tester, data);
          expect(h.inCell(find.textContaining('très long')), findsNothing);
          expect(_hidden(tester), 3 - _shown(tester));
          expect(paragraphsTruncated(tester, root: _cell), isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );
}
