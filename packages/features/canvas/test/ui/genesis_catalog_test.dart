import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart';

const Map<String, Object> _kpi = <String, Object>{
  'label': 'Sessions sans crash',
  'value': '99,57 %',
  'trend': '−0,36 pt',
  'threshold': '≥ 99,50 %',
  'status': 'risk',
  'statusLabel': 'À risque',
};

/// Lit les lignes de la fixture du contrat et substitue le catalogId.
List<Map<String, dynamic>> _fixture(String catalogId) {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/contracts/a2ui/genesis/v1').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('contracts/ introuvable');
    dir = parent;
  }
  return File('${dir.path}/contracts/a2ui/genesis/v1/examples/act1-kpi.jsonl')
      .readAsLinesSync()
      .where((String l) => l.trim().isNotEmpty)
      .map(
        (String l) =>
            jsonDecode(l.replaceAll(r'${CATALOG_ID}', catalogId))
                as Map<String, dynamic>,
      )
      .toList();
}

a2ui.A2uiMessage _message(Map<String, dynamic> json) =>
    a2ui.A2uiMessage.fromJson(json);

a2ui.A2uiMessage _dataMessage(Object? value) => _message(<String, dynamic>{
  'version': 'v0.9',
  'updateDataModel': <String, dynamic>{
    'surfaceId': 'kpi',
    'path': '/kpi',
    'value': value,
  },
});

void main() {
  late SurfaceController controller;
  late CanvasBloc bloc;
  late List<String> engineErrors;
  late List<Map<String, dynamic>> fixture;

  void createEngine() {
    controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
    bloc = CanvasBloc(controller);
    engineErrors = <String>[];
    final sub = controller.onSubmit.listen((message) {
      engineErrors.add(message.toString());
    });
    addTearDown(() async {
      await sub.cancel();
      await bloc.close();
      controller.dispose();
    });
    fixture = _fixture(GenesisContract.defaultCatalogId);
  }

  Future<void> pumpBoard(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
      ),
      home: Scaffold(
        body: BlocProvider<CanvasBloc>.value(
          value: bloc,
          child: SizedBox(
            width: 940,
            height: 255,
            child: CanvasBoard(controller: controller),
          ),
        ),
      ),
    ),
  );

  Future<void> send(WidgetTester tester, a2ui.A2uiMessage message) async {
    bloc.add(A2uiMessageReceived(message));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> sendFixtureTo(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await send(tester, _message(fixture[i]));
    }
  }

  Finder inCell(Finder finder) => find.descendant(
    of: find.byKey(const Key('surface-kpi')),
    matching: finder,
  );

  testWidgets('trois temps : squelette, sans données, valeur', (tester) async {
    createEngine();
    await pumpBoard(tester);

    await sendFixtureTo(tester, 1);
    expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
    expect(find.byKey(const Key('skeleton-kpi')), findsOneWidget);
    expect(find.byType(Surface), findsNothing);
    expect(find.textContaining('99,57'), findsNothing);

    final updateComponents = fixture[1];
    await send(tester, _message(updateComponents));
    expect(find.byType(Surface), findsOneWidget);
    expect(find.byKey(const Key('skeleton-kpi')), findsNothing);
    expect(find.byKey(const Key('neutral-kpi')), findsNothing);
    expect(find.byKey(const Key('nodata-kpi')), findsOneWidget);
    expect(find.textContaining('99,57'), findsNothing);
    expect(find.byType(DsStatusChip), findsNothing);

    await send(tester, _message(fixture[2]));
    expect(inCell(find.text('99,57 %')), findsOneWidget);
    expect(inCell(find.text('Sessions sans crash')), findsOneWidget);
    expect(inCell(find.text('−0,36 pt')), findsOneWidget);
    expect(inCell(find.text('≥ 99,50 %')), findsOneWidget);
    expect(inCell(find.text('À risque')), findsOneWidget);
    expect(inCell(find.byType(DsStatusChip)), findsOneWidget);
    expect(find.byKey(const Key('nodata-kpi')), findsNothing);
    expect(find.byKey(const Key('neutral-kpi')), findsNothing);
    expect(engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le chip porte la couleur du statut, pas du libellé', (
    tester,
  ) async {
    createEngine();
    await pumpBoard(tester);
    await sendFixtureTo(tester, 2);
    await send(tester, _dataMessage(<String, Object>{..._kpi, 'status': 'ok'}));

    final chip = tester.widget<DsStatusChip>(find.byType(DsStatusChip));
    expect(chip.status, SceneStatus.ok);
    expect(chip.label, 'À risque');
  });

  testWidgets('le champ optionnel comparison est toléré et ignoré', (
    tester,
  ) async {
    createEngine();
    await pumpBoard(tester);
    await sendFixtureTo(tester, 2);
    await send(
      tester,
      _dataMessage(<String, Object>{
        ..._kpi,
        'comparison': <String, String>{
          'label': 'Version précédente',
          'value': '99,93 %',
          'delta': '−0,36 pt',
        },
      }),
    );

    expect(inCell(find.text('99,57 %')), findsOneWidget);
    expect(find.text('99,93 %'), findsNothing);
    expect(find.byKey(const Key('neutral-kpi')), findsNothing);
  });

  testWidgets('un statut inconnu donne l état neutre', (tester) async {
    createEngine();
    await pumpBoard(tester);
    await sendFixtureTo(tester, 2);
    await send(
      tester,
      _dataMessage(<String, Object>{..._kpi, 'status': 'vert'}),
    );

    expect(find.byKey(const Key('neutral-kpi')), findsOneWidget);
    expect(find.text('Données indisponibles'), findsOneWidget);
    expect(find.textContaining('99,57'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final String field in _kpi.keys) {
    testWidgets('sans le champ requis $field : état neutre', (tester) async {
      createEngine();
      await pumpBoard(tester);
      await sendFixtureTo(tester, 2);
      await send(
        tester,
        _dataMessage(<String, Object>{..._kpi}..remove(field)),
      );

      expect(find.byKey(const Key('neutral-kpi')), findsOneWidget);
      expect(find.text('Données indisponibles'), findsOneWidget);
      expect(find.textContaining('99,57'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final MapEntry<String, Object?> bad in <String, Object?>{
    'objet de mauvais type': 'texte',
    'champ de mauvais type': <String, Object>{..._kpi, 'value': 99.57},
  }.entries) {
    testWidgets('${bad.key} : état neutre sans exception', (tester) async {
      createEngine();
      await pumpBoard(tester);
      await sendFixtureTo(tester, 2);
      await send(tester, _dataMessage(bad.value));

      expect(find.byKey(const Key('neutral-kpi')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(engineErrors, isEmpty);
    });
  }

  testWidgets('tout texte affiché fait au moins 24 px', (tester) async {
    createEngine();
    await pumpBoard(tester);
    await sendFixtureTo(tester, 3);

    final paragraphs = tester
        .renderObjectList<RenderParagraph>(
          find.descendant(
            of: find.byKey(const Key('surface-kpi')),
            matching: find.byType(RichText),
          ),
        )
        .toList();
    expect(paragraphs, isNotEmpty);
    for (final RenderParagraph p in paragraphs) {
      expect(
        p.text.style?.fontSize,
        greaterThanOrEqualTo(24),
        reason: '${p.text}',
      );
    }
  });

  testWidgets('le catalogId est configurable', (tester) async {
    final catalog = genesisCatalog(catalogId: 'https://example.test/c');
    expect(catalog.catalogId, 'https://example.test/c');
    expect(genesisCatalog().catalogId, GenesisContract.defaultCatalogId);
    expect(
      catalog.items.map((i) => i.name),
      GenesisContract.components,
      reason: 'les 5 composants validés, dans l ordre ; CrashList est hors catalogue',
    );
  });
}
