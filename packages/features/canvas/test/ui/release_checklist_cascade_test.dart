import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Cascade des lignes de la checklist (`gc-row`, pdr-0088 F13) : chaque ligne
/// apparaît en 480 ms (opacité et glissement de 12 px sur X), la suivante 180 ms
/// plus tard, dans l'ordre des critères ; un seul contrôleur.
const ({bool disabled, double speed}) _live = (disabled: false, speed: 1);
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

Future<CatalogHarness> _start(
  WidgetTester tester, {
  ({bool disabled, double speed}) motion = _live,
  int messages = 3,
}) async {
  final h = CatalogHarness(
    'checklist',
    'checklist',
    size: const Size(936, 302),
    fontFamily: realFontFamily,
    fontFamilyFallback: realFontFallback,
  );
  await h.pump(tester, motion: motion);
  await h.sendFixtureTo(tester, messages);
  return h;
}

Finder _row(int n) => find.byKey(Key('checklist-row-$n'));

/// Opacité propre à la ligne : celle des ancêtres de la ligne jusqu'au
/// contenu de la surface (le fondu d'apparition de la surface est exclu).
double _opacity(WidgetTester tester, int n) {
  double of(RenderObject? start) {
    var opacity = 1.0;
    for (RenderObject? r = start; r != null; r = r.parent) {
      if (r is RenderOpacity) opacity *= r.opacity;
      if (r is RenderAnimatedOpacity) opacity *= r.opacity.value;
    }
    return opacity;
  }

  final double surface = of(tester.renderObject(find.byType(A2uiSurface)));
  return of(tester.renderObject(_row(n))) / surface;
}

double _dx(WidgetTester tester, int n) =>
    tester.getTopLeft(_row(n)).dx - tester.getTopLeft(_row(0)).dx;

void main() {
  setUpAll(loadRealFonts);

  testWidgets('les lignes apparaissent l\'une après l\'autre, à 180 ms '
      'd\'écart', (tester) async {
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, 0), greaterThan(0.05));
    expect(_opacity(tester, 1), lessThan(0.01));
    expect(_opacity(tester, 2), lessThan(0.01));

    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, 1), greaterThan(0.05));
    expect(_opacity(tester, 2), lessThan(0.01));

    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester, 2), greaterThan(0.05));

    await tester.pump(const Duration(milliseconds: 1000));
    for (var n = 0; n < 3; n++) {
      expect(_opacity(tester, n), 1, reason: 'ligne $n');
    }
  });

  testWidgets('chaque ligne glisse de -12 px sur X vers sa place', (
    tester,
  ) async {
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    // Les lignes 1 et 2 n'ont pas commencé : 12 px à gauche de leur place ;
    // la ligne 0 a parcouru la part de la courbe à 100 / 480 ms.
    final double done = SceneMotion.curve.transform(100 / 480);
    expect(_dx(tester, 2), closeTo(_dx(tester, 1), 0.01));
    expect(
      _dx(tester, 1) - _dx(tester, 0),
      closeTo(-12 * done, 0.3),
      reason: 'la ligne 0 est en avance de ${12 * done} px',
    );
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_dx(tester, 1), 0);
    expect(_dx(tester, 2), 0);
  });

  testWidgets('un seul contrôleur pour toute la cascade', (tester) async {
    await _start(tester);
    // Un ticker pour la cascade, un pour DsRise de la surface : jamais un par
    // ligne. Le nombre de transitions actives reste donc petit.
    final int withCascade = tester.binding.transientCallbackCount;
    await tester.pump(const Duration(milliseconds: 2000));
    expect(tester.binding.transientCallbackCount, lessThan(withCascade));
    expect(withCascade, lessThanOrEqualTo(3));
  });

  testWidgets('l\'état final est immédiat sous disableAnimations', (
    tester,
  ) async {
    await _start(tester, motion: _still);
    for (var n = 0; n < 3; n++) {
      expect(_opacity(tester, n), 1, reason: 'ligne $n');
      expect(_dx(tester, n), 0);
    }
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('aucun libellé tronqué pendant ni après la cascade', (
    tester,
  ) async {
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      paragraphsTruncated(
        tester,
        root: find.byKey(const Key('surface-checklist')),
      ),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      paragraphsTruncated(
        tester,
        root: find.byKey(const Key('surface-checklist')),
      ),
      isEmpty,
    );
  });

  testWidgets('l\'ordre des critères est celui de la donnée', (tester) async {
    final h = await _start(tester);
    await tester.pump(const Duration(seconds: 2));
    final List<String> labels = <String>[
      for (final Map<String, dynamic> item in (h.data['items'] as List).cast())
        item['label'] as String,
    ];
    for (var n = 0; n < labels.length; n++) {
      expect(
        find.descendant(of: _row(n), matching: find.text(labels[n])),
        findsOneWidget,
        reason: 'ligne $n',
      );
    }
  });

  testWidgets('la mise à jour d\'une valeur ne relance pas la cascade', (
    tester,
  ) async {
    final h = await _start(tester);
    await tester.pump(const Duration(seconds: 2));
    final data = cloneJson(h.data);
    (data['items'] as List)[0]['value'] = '12 PR';
    await h.sendData(tester, data);
    await tester.pump(const Duration(milliseconds: 50));
    for (var n = 0; n < 3; n++) {
      expect(_opacity(tester, n), 1, reason: 'ligne $n');
    }
    expect(
      find.descendant(of: _row(0), matching: find.text('12 PR')),
      findsOneWidget,
    );
  });

  testWidgets('la vitesse de rejeu accélère la cascade', (tester) async {
    await _start(tester, motion: (disabled: false, speed: 2));
    // À 2 ×, la ligne 1 débute à 90 ms.
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, 1), greaterThan(0.05));
    expect(_opacity(tester, 2), lessThan(0.01));
  });

  testWidgets('une surface restaurée affiche l\'état final aussitôt', (
    tester,
  ) async {
    final h = CatalogHarness(
      'checklist',
      'checklist',
      size: const Size(936, 302),
      fontFamily: realFontFamily,
      fontFamilyFallback: realFontFallback,
    );
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 3);
    expect(h.engineErrors, isEmpty);
    // La restauration passe par DsRise.settled, vérifiée en acceptation (A-07) :
    // ici, la durée de la cascade est celle de 3 lignes (480 + 2 x 180 ms).
    await tester.pump(SceneMotion.row + SceneMotion.stagger * 2);
    expect(_opacity(tester, 2), 1);
  });
}
