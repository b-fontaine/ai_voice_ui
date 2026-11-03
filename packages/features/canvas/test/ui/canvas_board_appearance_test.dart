import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:feature_canvas/feature_canvas.dart' show A2uiMessageReceived;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:shared_design_system/shared_design_system.dart' show DsSkeleton;

import '../support/catalog_harness.dart';

/// Apparition animée d'une surface (013 T21c, pdr-0075 D3) : squelette, puis
/// composants en fondu de 480 ms, puis valeurs en fondu de 160 ms. L'opacité
/// est mesurée sur l'écran rendu (produit des opacités des ancêtres).
///
/// Recalé par pdr-0087 / pdr-0088 F5 : l'apparition est celle de `DsRise`
/// (`gc-rise`), avec un flou de départ (σ 4 vers 0) et une échelle .985 vers 1,
/// au lieu du fondu sans flou de 017.
const ({bool disabled, double speed}) _live = (disabled: false, speed: 1);

double _opacityOf(Finder finder) {
  final Iterable<Element> elements = finder.evaluate();
  expect(elements, isNotEmpty, reason: '$finder est introuvable');
  double opacity = 1;
  RenderObject? render = elements.first.renderObject;
  while (render != null) {
    if (render is RenderOpacity) opacity *= render.opacity;
    if (render is RenderAnimatedOpacity) opacity *= render.opacity.value;
    render = render.parent;
  }
  return opacity;
}

/// Écart type du flou actif posé sur le contenu par un `ImageFiltered`.
double _blurOf(Finder finder) {
  var sigma = 0.0;
  finder.evaluate().first.visitAncestorElements((Element ancestor) {
    final Widget w = ancestor.widget;
    if (w is ImageFiltered && w.enabled) {
      final RegExpMatch? m = RegExp(r'blur\(([\d.]+)')
          .firstMatch(w.imageFilter.toString());
      if (m != null) sigma = double.parse(m.group(1)!);
    }
    return true;
  });
  return sigma;
}

Finder _content() => find.descendant(
  of: find.byKey(const Key('surface-kpi')),
  matching: find.byType(Surface),
);

Finder _value() => find.descendant(
  of: find.byKey(const Key('surface-kpi')),
  matching: find.text('99,57 %'),
);

/// Valeur affichée après la mise à jour de l'acte 2 (le « 99,57 % » de l'acte 1
/// y devient « 99,43 % »).
Finder _valueAct2() => find.descendant(
  of: find.byKey(const Key('surface-kpi')),
  matching: find.text('99,43 %'),
);

Finder _skeleton() => find.byKey(const Key('skeleton-kpi'));

void main() {
  testWidgets('squelette puis composants quasi invisibles à t = 0', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);

    await h.sendFixtureTo(tester, 1);
    expect(_skeleton(), findsOneWidget);
    expect(_opacityOf(_skeleton()), 1.0);

    await h.send(tester, h.fixture[1]);
    expect(_content(), findsOneWidget);
    expect(_opacityOf(_content()), lessThan(0.05));
    expect(_skeleton(), findsNothing, reason: 'le squelette part aussitôt');
  });

  testWidgets('après 480 ms les composants sont pleinement visibles', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);

    await tester.pump(const Duration(milliseconds: 240));
    final double half = _opacityOf(_content());
    expect(half, inExclusiveRange(0.3, 1.0));

    await tester.pump(const Duration(milliseconds: 240));
    expect(_opacityOf(_content()), 1.0);
    expect(_skeleton(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animations désactivées : tout est visible immédiatement', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: (disabled: true, speed: 1));

    await h.sendFixtureTo(tester, 2);
    expect(_opacityOf(_content()), 1.0);
    expect(_skeleton(), findsNothing);

    await h.send(tester, h.fixture[2]);
    expect(_opacityOf(_value()), 1.0);
  });

  testWidgets('rejeu à 2 x : fondu des composants en 240 ms au plus', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: (disabled: false, speed: 2));
    await h.sendFixtureTo(tester, 2);
    expect(_opacityOf(_content()), lessThan(0.05));

    await tester.pump(const Duration(milliseconds: 120));
    expect(_opacityOf(_content()), lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 120));
    expect(_opacityOf(_content()), 1.0);
    expect(_skeleton(), findsNothing);
  });

  testWidgets('les valeurs apparaissent en 160 ms au passage aux données', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    await tester.pump(const Duration(milliseconds: 480));

    await h.send(tester, h.fixture[2]);
    expect(_opacityOf(_value()), lessThan(0.05));

    await tester.pump(const Duration(milliseconds: 80));
    expect(_opacityOf(_value()), inExclusiveRange(0.3, 1.0));

    await tester.pump(const Duration(milliseconds: 80));
    expect(_opacityOf(_value()), 1.0);
  });

  testWidgets(
    'animations coupées en cours de fondu : tout est visible aussitôt',
    (tester) async {
      final h = CatalogHarness('kpi', 'kpi');
      await h.pump(tester, motion: _live);
      await h.sendFixtureTo(tester, 2);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacityOf(_content()), lessThan(1.0));
      expect(tester.hasRunningAnimations, isTrue);

      await h.pump(tester, motion: (disabled: true, speed: 1));

      expect(_opacityOf(_content()), 1.0);
      expect(
        tester.getTopLeft(_content()).dy,
        tester.getTopLeft(find.byKey(const Key('surface-kpi'))).dy,
      );
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('animations coupées en cours de fondu des valeurs', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    await tester.pump(const Duration(milliseconds: 480));
    await h.send(tester, h.fixture[2]);
    await tester.pump(const Duration(milliseconds: 40));
    expect(_opacityOf(_value()), lessThan(1.0));

    await h.pump(tester, motion: (disabled: true, speed: 1));

    expect(_opacityOf(_value()), 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('un updateDataModel ne rejoue aucune animation', (tester) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 3);
    // Composants (480 ms) puis valeurs (160 ms).
    await tester.pump(const Duration(milliseconds: 640));
    expect(_opacityOf(_value()), 1.0);
    final State surfaceBefore = tester.state(find.byType(Surface));

    await h.sendVariant(tester, 'act2');

    expect(tester.state(find.byType(Surface)), same(surfaceBefore));
    expect(_valueAct2(), findsOneWidget);
    expect(_opacityOf(_content()), 1.0);
    expect(_skeleton(), findsNothing);
    expect(find.byType(Surface), findsOneWidget);
    // Le point de Bloquant bat en continu (U7) : `hasRunningAnimations` ne
    // peut plus servir. Aucun fondu ni aucune translation ne repart : le
    // contenu et la valeur restent opaques et immobiles à plusieurs instants.
    final Offset contentTopLeft = tester.getTopLeft(_content());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacityOf(_content()), 1.0, reason: 'le fondu repart');
      expect(
        _opacityOf(_valueAct2()),
        1.0,
        reason: 'le fondu de valeur repart',
      );
      expect(
        tester.getTopLeft(_content()),
        contentTopLeft,
        reason: 'la translation repart',
      );
    }
    expect(h.engineErrors, isEmpty);
  });

  testWidgets('la pastille de décision garde son State lors de l acte 2', (
    tester,
  ) async {
    final h = CatalogHarness('checklist', 'checklist');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 3);
    // Composants (480 ms) puis valeurs (160 ms).
    await tester.pump(const Duration(milliseconds: 640));
    final Finder status = find.byKey(const Key('decision-status'));
    final State before = tester.state(status);
    final State surfaceBefore = tester.state(find.byType(Surface));

    await h.sendVariant(tester, 'act2');

    expect(tester.state(status), same(before));
    expect(tester.state(find.byType(Surface)), same(surfaceBefore));
    expect(
      find.descendant(of: status, matching: find.byType(FadeTransition)),
      findsWidgets,
    );
  });

  testWidgets('le rectangle de surface-<id> ne change à aucune image', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 1);
    final Rect noted = tester.getRect(find.byKey(const Key('surface-kpi')));

    await h.send(tester, h.fixture[1]);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getRect(find.byKey(const Key('surface-kpi'))),
        noted,
        reason: 'image $i',
      );
    }
    await h.send(tester, h.fixture[2]);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(find.byKey(const Key('surface-kpi'))), noted);
    }
  });

  testWidgets('la translation de 10 px se fait sous surface-<id>', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    final Finder cell = find.byKey(const Key('surface-kpi'));

    final double top = tester.getTopLeft(_content()).dy;
    expect(top - tester.getTopLeft(cell).dy, closeTo(10, 0.01));

    await tester.pump(const Duration(milliseconds: 480));
    expect(tester.getTopLeft(_content()).dy, tester.getTopLeft(cell).dy);
  });

  testWidgets(
    'l\'apparition porte le flou de 4 et l\'échelle .985 (pdr-0088 F5)',
    (tester) async {
      final h = CatalogHarness('kpi', 'kpi');
      await h.pump(tester, motion: _live);
      await h.sendFixtureTo(tester, 2);
      expect(_blurOf(_content()), closeTo(4, 0.01));
      expect(
        tester
            .renderObject<RenderBox>(_content())
            .getTransformTo(null)
            .storage[0],
        closeTo(0.985, 1e-6),
      );

      await tester.pump(const Duration(milliseconds: 240));
      expect(_blurOf(_content()), inExclusiveRange(0, 4));

      await tester.pump(const Duration(milliseconds: 241));
      expect(_blurOf(_content()), 0);
      expect(
        tester
            .renderObject<RenderBox>(_content())
            .getTransformTo(null)
            .storage[0],
        1,
      );
    },
  );

  testWidgets('animations coupées : aucun flou, même à la première image', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: (disabled: true, speed: 1));
    await h.sendFixtureTo(tester, 2);
    expect(_blurOf(_content()), 0);
  });

  testWidgets('le State de la Surface survit au fondu et aux données', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    final State before = tester.state(find.byType(Surface));

    await tester.pump(const Duration(milliseconds: 480));
    await h.send(tester, h.fixture[2]);
    await tester.pump(const Duration(milliseconds: 480));

    expect(tester.state(find.byType(Surface)), same(before));
  });

  testWidgets('une surface déjà complète au premier build ne rejoue rien', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.sendFixtureTo(tester, 3);

    await h.pump(tester, motion: _live);

    expect(_opacityOf(_content()), 1.0);
    expect(_opacityOf(_value()), 1.0);
    expect(_skeleton(), findsNothing);
    expect(find.byType(DsSkeleton), findsNothing);
  });

  testWidgets('une surface qui arrive déjà complète après le premier rendu '
      'apparaît en fondu', (tester) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);

    // Le rejeu reconstruit une surface d'un seul coup, à sa phase finale.
    for (var i = 0; i < 3; i++) {
      h.bloc.add(A2uiMessageReceived(a2ui.A2uiMessage.fromJson(h.fixture[i])));
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(_opacityOf(_content()), lessThan(0.05));

    await tester.pump(const Duration(milliseconds: 480));
    expect(_opacityOf(_content()), 1.0);
  });

  testWidgets('une surface supprimée puis recréée apparaît de nouveau', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.sendFixtureTo(tester, 3);
    await h.pump(tester, motion: _live);
    expect(_opacityOf(_content()), 1.0);

    h.bloc.add(
      A2uiMessageReceived(
        a2ui.A2uiMessage.fromJson(<String, dynamic>{
          'version': 'v0.9',
          'deleteSurface': <String, dynamic>{'surfaceId': 'kpi'},
        }),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await h.sendFixtureTo(tester, 2);

    expect(_opacityOf(_content()), lessThan(0.05));
  });
}
