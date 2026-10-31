import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:feature_canvas/feature_canvas.dart' show A2uiMessageReceived;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:shared_design_system/shared_design_system.dart' show DsSkeleton;

import '../support/catalog_harness.dart';

/// Apparition animée d'une surface (013 T21c, pdr-0075 D3) : squelette, puis
/// composants en fondu de 200 ms, puis valeurs en fondu de 150 ms. L'opacité
/// est mesurée sur l'écran rendu (produit des opacités des ancêtres).
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

Finder _content() => find.descendant(
  of: find.byKey(const Key('surface-kpi')),
  matching: find.byType(Surface),
);

Finder _value() => find.descendant(
  of: find.byKey(const Key('surface-kpi')),
  matching: find.text('99,57 %'),
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

  testWidgets('après 200 ms les composants sont pleinement visibles', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);

    await tester.pump(const Duration(milliseconds: 100));
    final double half = _opacityOf(_content());
    expect(half, inExclusiveRange(0.3, 1.0));

    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('rejeu à 2 x : fondu des composants en 100 ms au plus', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: (disabled: false, speed: 2));
    await h.sendFixtureTo(tester, 2);
    expect(_opacityOf(_content()), lessThan(0.05));

    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacityOf(_content()), 1.0);
    expect(_skeleton(), findsNothing);
  });

  testWidgets('les valeurs apparaissent en 150 ms au passage aux données', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    await tester.pump(const Duration(milliseconds: 200));

    await h.send(tester, h.fixture[2]);
    expect(_opacityOf(_value()), lessThan(0.05));

    await tester.pump(const Duration(milliseconds: 75));
    expect(_opacityOf(_value()), inExclusiveRange(0.3, 1.0));

    await tester.pump(const Duration(milliseconds: 75));
    expect(_opacityOf(_value()), 1.0);
  });

  testWidgets('un updateDataModel ne rejoue aucune animation', (tester) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 3);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_opacityOf(_value()), 1.0);

    await h.sendVariant(tester, 'act2');

    expect(_opacityOf(_content()), 1.0);
    expect(_skeleton(), findsNothing);
    expect(find.byType(Surface), findsOneWidget);
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'aucune animation ne doit repartir',
    );
    expect(h.engineErrors, isEmpty);
  });

  testWidgets('la pastille de décision garde son State lors de l acte 2', (
    tester,
  ) async {
    final h = CatalogHarness('checklist', 'checklist');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 3);
    await tester.pump(const Duration(milliseconds: 400));
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

  testWidgets('la translation de 8 px se fait sous surface-<id>', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    final Finder cell = find.byKey(const Key('surface-kpi'));

    final double top = tester.getTopLeft(_content()).dy;
    expect(top - tester.getTopLeft(cell).dy, closeTo(8, 0.01));

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(_content()).dy, tester.getTopLeft(cell).dy);
  });

  testWidgets('le State de la Surface survit au fondu et aux données', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    final State before = tester.state(find.byType(Surface));

    await tester.pump(const Duration(milliseconds: 200));
    await h.send(tester, h.fixture[2]);
    await tester.pump(const Duration(milliseconds: 200));

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

    await tester.pump(const Duration(milliseconds: 200));
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
