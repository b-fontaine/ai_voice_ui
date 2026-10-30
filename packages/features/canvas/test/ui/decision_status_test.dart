import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, SurfaceController;
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';
import 'cell_height_real_fonts_test.dart' show gridCell, loadRealFonts;

/// Faux client réseau : mémorise les actions reçues, répond 202.
class _RecordingClient implements CanvasActionClient {
  final List<String> actions = <String>[];

  @override
  Future<CanvasActionResult> send({
    required String action,
    required String surface,
  }) async {
    actions.add(action);
    return CanvasActionResult.accepted;
  }
}

/// Statut de décision de la checklist (pastille) et bouton « fait » de la
/// Barre d'actions (011 T25, plan A7).
void main() {
  setUpAll(loadRealFonts);

  /// Cellule d'une colonne à 1366 px de large (1366 − 2 × 24 − 8, divisé par 2).
  const Size narrowCell = Size(655, 250);

  for (final (String name, Size cell) in <(String, Size)>[
    ('1366 x 768', narrowCell),
    ('1920 x 1080', gridCell),
  ]) {
    testWidgets('statut de décision en pastille, entier à $name', (
      tester,
    ) async {
      final h = CatalogHarness(
        'checklist',
        'checklist',
        size: cell,
        fontFamily: 'Noto Sans',
        fontFamilyFallback: const <String>['DejaVu Sans'],
      );
      await h.pump(tester);
      await h.sendFixtureTo(tester, 3);

      Finder chip(String text) => h.inCell(
        find.descendant(
          of: find.byKey(const Key('decision-status')),
          matching: find.text(text),
        ),
      );
      expect(chip('En attente de décision'), findsOneWidget);
      expect(
        h.inCell(
          find.descendant(
            of: find.byKey(const Key('decision-status')),
            matching: find.byType(DsStatusChip),
          ),
        ),
        findsOneWidget,
      );

      await h.send(
        tester,
        contractFixture(
          'block',
          GenesisContract.defaultCatalogId,
          variant: 'act3',
        ).single,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(chip('Bloquée'), findsOneWidget);
      final RenderParagraph p = tester.renderObject<RenderParagraph>(
        chip('Bloquée'),
      );
      expect(p.didExceedMaxLines, isFalse);
      final Rect cellRect = tester.getRect(
        find.byKey(const Key('surface-checklist')),
      );
      final Rect chipRect = tester.getRect(
        find.byKey(const Key('decision-status')),
      );
      expect(cellRect.contains(chipRect.topLeft), isTrue);
      expect(cellRect.contains(chipRect.bottomRight), isTrue);
      final RenderParagraph before = tester.renderObject<RenderParagraph>(
        h.inCell(find.text('Checklist go/no-go')),
      );
      expect(before.text.style?.fontSize, greaterThanOrEqualTo(24));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('le changement de statut est mis en avant (transition)', (
    tester,
  ) async {
    final h = CatalogHarness(
      'checklist',
      'checklist',
      size: narrowCell,
      fontFamily: 'Noto Sans',
      fontFamilyFallback: const <String>['DejaVu Sans'],
    );
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    await h.send(
      tester,
      contractFixture(
        'block',
        GenesisContract.defaultCatalogId,
        variant: 'act3',
      ).single,
    );
    // Les images à durée nulle n'avancent pas la transition : l'ancien et le
    // nouveau statut sont brièvement tous deux présents.
    expect(find.text('Bloquée'), findsOneWidget);
    expect(find.text('En attente de décision'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('En attente de décision'), findsNothing);
    expect(find.text('Bloquée'), findsOneWidget);
  });

  group('Barre d\'actions : en cours, fait, réactivé', () {
    late SurfaceController controller;
    late CanvasBloc canvas;
    late CanvasActionBloc actions;
    late _RecordingClient client;

    Future<void> send(WidgetTester tester, Map<String, dynamic> json) async {
      canvas.add(A2uiMessageReceived(a2ui.A2uiMessage.fromJson(json)));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
    }

    Future<void> pumpBoard(WidgetTester tester) async {
      controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
      canvas = CanvasBloc(controller);
      client = _RecordingClient();
      actions = CanvasActionBloc(
        client: client,
        settings: const CanvasActionSettings(
          retries: 0,
          retryInterval: Duration(milliseconds: 1),
          maxDuration: Duration(seconds: 30),
        ),
      );
      addTearDown(() async {
        await canvas.close();
        controller.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Noto Sans',
            fontFamilyFallback: const <String>['DejaVu Sans'],
            extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
          ),
          home: Scaffold(
            body: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<CanvasBloc>.value(value: canvas),
                BlocProvider<CanvasActionBloc>.value(value: actions),
              ],
              child: SizedBox(
                width: 1366,
                height: 568,
                child: CanvasActionScope(
                  enabled: true,
                  child: CanvasBoard(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );
      for (final Map<String, dynamic> m in contractFixture(
        'checklist',
        GenesisContract.defaultCatalogId,
      )) {
        await send(tester, m);
      }
      for (final Map<String, dynamic> m in contractFixture(
        'actions',
        GenesisContract.defaultCatalogId,
        variant: 'act2',
      )) {
        await send(tester, m);
      }
    }

    Finder button(String id) => find.byKey(Key('action-$id'));
    bool enabled(WidgetTester tester, String id) =>
        tester.widget<OutlinedButton>(button(id)).enabled;
    Finder spinner(String id) => find.descendant(
      of: button(id),
      matching: find.byType(CircularProgressIndicator),
    );

    Future<void> pendingStatus(WidgetTester tester) => send(
      tester,
      contractFixture('checklist', GenesisContract.defaultCatalogId)[2],
    );

    Future<void> blocked(WidgetTester tester) => send(
      tester,
      contractFixture(
        'block',
        GenesisContract.defaultCatalogId,
        variant: 'act3',
      ).single,
    );

    testWidgets('en cours : indicateur sur le bouton cliqué seulement', (
      tester,
    ) async {
      await pumpBoard(tester);
      expect(spinner('block_release'), findsNothing);
      await tester.tap(button('block_release'));
      await tester.pump();
      await tester.pump();
      expect(spinner('block_release'), findsOneWidget);
      expect(spinner('validate_release'), findsNothing);
      expect(enabled(tester, 'block_release'), isFalse);
      expect(find.text('Bloquer la release'), findsOneWidget);
      unawaited(actions.close());
      await tester.pump();
    });

    testWidgets('décision en place : bouton « fait », inactif, sans requête', (
      tester,
    ) async {
      await pumpBoard(tester);
      await tester.tap(button('block_release'));
      await tester.pump();
      await tester.pump();
      await blocked(tester);

      expect(
        find.descendant(
          of: button('block_release'),
          matching: find.textContaining('fait'),
        ),
        findsOneWidget,
      );
      expect(spinner('block_release'), findsNothing);
      expect(enabled(tester, 'block_release'), isFalse);

      // Fin de l'activité : le bouton « fait » reste inactif, l'autre revit.
      actions.add(const ActionActivityChanged(busy: true));
      actions.add(const ActionActivityChanged(busy: false));
      await tester.pump();
      await tester.pump();
      expect(enabled(tester, 'validate_release'), isTrue);
      expect(enabled(tester, 'block_release'), isFalse);

      await tester.tap(button('block_release'), warnIfMissed: false);
      await tester.pump();
      expect(client.actions, <String>['block_release']);
      expect(tester.takeException(), isNull);
      unawaited(actions.close());
      await tester.pump();
    });

    testWidgets('une réécriture de la checklist réactive le bouton', (
      tester,
    ) async {
      await pumpBoard(tester);
      await tester.tap(button('block_release'));
      await tester.pump();
      await tester.pump();
      await blocked(tester);
      actions.add(const ActionActivityChanged(busy: true));
      actions.add(const ActionActivityChanged(busy: false));
      await tester.pump();
      await tester.pump();
      expect(enabled(tester, 'block_release'), isFalse);

      await pendingStatus(tester);
      expect(enabled(tester, 'block_release'), isTrue);
      expect(
        find.descendant(
          of: button('block_release'),
          matching: find.text('Bloquer la release'),
        ),
        findsOneWidget,
      );
      await tester.tap(button('block_release'));
      await tester.pump();
      await tester.pump();
      expect(client.actions, <String>['block_release', 'block_release']);
      unawaited(actions.close());
      await tester.pump();
    });
  });
}
