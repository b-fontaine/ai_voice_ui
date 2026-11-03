import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:feature_canvas/src/ui/action_availability.dart'
    show ActionAvailability;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Apparence des boutons de la Barre d'actions (T24, `gc-btn`) : visuel de
/// 44 px dans une cible de 48 pt, rayon `md`, danger avec lueur, désactivé en
/// tirets, étiquette issue du `title` de `/actions`. Le clic reste un clic.
void main() {
  const SceneTheme theme = SceneTheme.dark();
  late SurfaceController controller;

  Future<void> pumpBar(
    WidgetTester tester, {
    void Function(String name, String surfaceId)? onAction,
    bool enabled = true,
    Set<String> done = const <String>{},
    String? title,
  }) async {
    controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
    addTearDown(controller.dispose);
    for (final Map<String, dynamic> json in contractFixture(
      'actions',
      GenesisContract.defaultCatalogId,
      variant: 'act2',
    )) {
      if (title != null && json.containsKey('updateDataModel')) {
        final body = json['updateDataModel'] as Map<String, dynamic>;
        body['value'] = cloneJson(body['value'] as Map<String, dynamic>)
          ..['title'] = title;
      }
      controller.handleMessage(a2ui.A2uiMessage.fromJson(json));
    }
    Widget surface = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 940,
        height: CanvasBoard.actionsBandHeight,
        child: Surface(surfaceContext: controller.contextFor('actions')),
      ),
    );
    if (onAction != null) {
      surface = ActionAvailability(
        enabled: enabled,
        onAction: onAction,
        doneActions: done,
        child: surface,
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
        ),
        home: Scaffold(body: surface),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder visual(String id) => find.byKey(Key('action-$id-visual'));
  Finder dashes(String id) => find.byKey(Key('action-$id-dashes'));

  BoxDecoration decoration(WidgetTester tester, String id) {
    final Finder boxes = find.descendant(
      of: visual(id),
      matching: find.byType(DecoratedBox),
    );
    return tester.widget<DecoratedBox>(boxes.first).decoration as BoxDecoration;
  }

  Color textColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;

  testWidgets('visuel de 44 px de haut, rayon md, dans une cible de 48 pt', (
    tester,
  ) async {
    await pumpBar(tester, onAction: (_, _) {});
    for (final String id in <String>['block_release', 'validate_release']) {
      expect(tester.getSize(visual(id)).height, 44, reason: id);
      expect(
        tester.getSize(find.byKey(Key('action-$id'))).height,
        greaterThanOrEqualTo(48),
        reason: id,
      );
      expect(decoration(tester, id).borderRadius, SceneRadius.borderMd);
    }
  });

  testWidgets('neutre actif : fond surface-300, bordure ink-muted, texte ink, '
      'ni lueur ni tirets', (tester) async {
    await pumpBar(tester, onAction: (_, _) {});
    final BoxDecoration d = decoration(tester, 'validate_release');
    // Le serveur de test laisse « Valider » actif : aucun critère ne bloque.
    expect(d.color, theme.surface300);
    expect((d.border! as Border).top.color, theme.textSecondary);
    expect((d.border! as Border).top.width, 1);
    expect(d.boxShadow, isNull);
    expect(dashes('validate_release'), findsNothing);
    expect(textColor(tester, 'Valider la release'), theme.textPrimary);
  });

  testWidgets('danger actif : texte et bordure nogo, fond nogo-ghost, lueur '
      'nogo', (tester) async {
    await pumpBar(tester, onAction: (_, _) {});
    final BoxDecoration d = decoration(tester, 'block_release');
    expect(d.color, theme.blockingBackground);
    expect((d.border! as Border).top.color, theme.blockingForeground);
    expect(d.boxShadow, SceneShadow.glowNogo);
    expect(textColor(tester, 'Bloquer la release'), theme.blockingForeground);
    expect(dashes('block_release'), findsNothing);
  });

  testWidgets('désactivé : bordure en tirets, texte ink-muted, pas de lueur', (
    tester,
  ) async {
    await pumpBar(tester);
    for (final String id in <String>['block_release', 'validate_release']) {
      expect(dashes(id), findsOneWidget, reason: id);
      final BoxDecoration d = decoration(tester, id);
      expect(d.border, isNull, reason: id);
      expect(d.boxShadow, isNull, reason: id);
    }
    expect(textColor(tester, 'Bloquer la release'), theme.textSecondary);
    expect(textColor(tester, 'Valider la release'), theme.textSecondary);
    expect(textColor(tester, 'Valider la release'), isNot(theme.inkFaint));
  });

  testWidgets('décision en place : désactivé, tirets', (tester) async {
    await pumpBar(
      tester,
      onAction: (_, _) {},
      done: const <String>{'block_release'},
    );
    expect(dashes('block_release'), findsOneWidget);
    expect(dashes('validate_release'), findsNothing);
  });

  testWidgets('un clic envoie l\'action, désactivé n\'envoie rien', (
    tester,
  ) async {
    final List<String> calls = <String>[];
    await pumpBar(
      tester,
      onAction: (name, surface) => calls.add('$name@$surface'),
    );
    await tester.tap(find.byKey(const Key('action-block_release')));
    expect(calls, <String>['block_release@actions']);
    await pumpBar(
      tester,
      onAction: (name, _) => calls.add(name),
      enabled: false,
    );
    await tester.tap(
      find.byKey(const Key('action-validate_release')),
      warnIfMissed: false,
    );
    expect(calls, hasLength(1));
  });

  testWidgets('l\'étiquette du bandeau vient du title de /actions, en '
      'capitales', (tester) async {
    await pumpBar(tester, onAction: (_, _) {}, title: 'Verdict final');
    final Finder label = find.byKey(const Key('actions-label'));
    expect(label, findsOneWidget);
    expect(
      tester
          .widget<Text>(find.descendant(of: label, matching: find.byType(Text)))
          .data,
      'VERDICT FINAL',
    );
  });
}
