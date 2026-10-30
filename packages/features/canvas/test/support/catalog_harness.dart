import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart';

/// Lit les lignes de la fixture `act1-<name>.jsonl` du contrat, en
/// substituant `${CATALOG_ID}` textuellement.
List<Map<String, dynamic>> contractFixture(String name, String catalogId) {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/contracts/a2ui/genesis/v1').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('contracts/ introuvable');
    dir = parent;
  }
  return File('${dir.path}/contracts/a2ui/genesis/v1/examples/act1-$name.jsonl')
      .readAsLinesSync()
      .where((String l) => l.trim().isNotEmpty)
      .map(
        (String l) =>
            jsonDecode(l.replaceAll(r'${CATALOG_ID}', catalogId))
                as Map<String, dynamic>,
      )
      .toList();
}

/// Moteur + Bloc + plateau pour tester un composant du catalogue sur sa
/// fixture. Les erreurs du moteur (`onSubmit`) sont collectées.
class CatalogHarness {
  CatalogHarness(
    this.surface,
    String fixtureName, {
    this.size = const Size(940, 255),
  }) {
    controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
    bloc = CanvasBloc(controller);
    _sub = controller.onSubmit.listen((m) => engineErrors.add(m.toString()));
    fixture = contractFixture(fixtureName, GenesisContract.defaultCatalogId);
    addTearDown(() async {
      await _sub.cancel();
      await bloc.close();
      controller.dispose();
    });
  }

  final String surface;
  final Size size;
  late final SurfaceController controller;
  late final CanvasBloc bloc;
  late final StreamSubscription<dynamic> _sub;
  late final List<Map<String, dynamic>> fixture;
  final List<String> engineErrors = <String>[];

  /// Objet du data model de la fixture (3e message).
  Map<String, dynamic> get data =>
      ((fixture[2]['updateDataModel'] as Map<String, dynamic>)['value']
          as Map<String, dynamic>);

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
      ),
      home: Scaffold(
        body: BlocProvider<CanvasBloc>.value(
          value: bloc,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CanvasBoard(controller: controller),
          ),
        ),
      ),
    ),
  );

  Future<void> send(WidgetTester tester, Map<String, dynamic> json) async {
    bloc.add(A2uiMessageReceived(a2ui.A2uiMessage.fromJson(json)));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> sendFixtureTo(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await send(tester, fixture[i]);
    }
  }

  /// Remplace l'objet du data model par [value].
  Future<void> sendData(WidgetTester tester, Object? value) =>
      send(tester, <String, dynamic>{
        'version': 'v0.9',
        'updateDataModel': <String, dynamic>{
          'surfaceId': surface,
          'path': '/$surface',
          'value': value,
        },
      });

  Finder inCell(Finder finder) => find.descendant(
    of: find.byKey(Key('surface-$surface')),
    matching: finder,
  );

  /// Vérifie que tous les textes de la cellule font au moins 24 px.
  void expectTextAtLeast24(WidgetTester tester) {
    final paragraphs = tester
        .renderObjectList<RenderParagraph>(inCell(find.byType(RichText)))
        .toList();
    expect(paragraphs, isNotEmpty);
    for (final RenderParagraph p in paragraphs) {
      expect(
        p.text.style?.fontSize,
        greaterThanOrEqualTo(24),
        reason: '${p.text}',
      );
    }
  }
}

/// Copie profonde modifiable d'un objet JSON.
Map<String, dynamic> cloneJson(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

/// Tests communs aux trois composants : squelette, sans données, neutre.
void defineCommonStateTests({
  required String component,
  required String surface,
  required String fixtureName,
  required String completeText,
  Map<String, Object?> badValues = const <String, Object?>{},
}) {
  testWidgets('$component : squelette puis sans données puis complet', (
    tester,
  ) async {
    final h = CatalogHarness(surface, fixtureName);
    await h.pump(tester);

    await h.sendFixtureTo(tester, 1);
    expect(find.byKey(Key('skeleton-$surface')), findsOneWidget);
    expect(find.textContaining(completeText), findsNothing);

    await h.send(tester, h.fixture[1]);
    expect(find.byKey(Key('nodata-$surface')), findsOneWidget);
    expect(find.byKey(Key('skeleton-$surface')), findsNothing);
    expect(find.byKey(Key('neutral-$surface')), findsNothing);
    expect(find.textContaining(completeText), findsNothing);

    await h.send(tester, h.fixture[2]);
    expect(find.byKey(Key('nodata-$surface')), findsNothing);
    expect(find.byKey(Key('neutral-$surface')), findsNothing);
    expect(h.inCell(find.textContaining(completeText)), findsWidgets);
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final String field in GenesisContract.requiredFields[component]!) {
    testWidgets('$component sans le champ requis $field : état neutre', (
      tester,
    ) async {
      final h = CatalogHarness(surface, fixtureName);
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendData(tester, cloneJson(h.data)..remove(field));

      expect(find.byKey(Key('neutral-$surface')), findsOneWidget);
      expect(find.text('Données indisponibles'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });
  }

  for (final MapEntry<String, Object?> bad in <String, Object?>{
    'objet de mauvais type': 'texte',
    'objet vide': <String, Object>{},
    ...badValues,
  }.entries) {
    testWidgets('$component, ${bad.key} : état neutre sans exception', (
      tester,
    ) async {
      final h = CatalogHarness(surface, fixtureName);
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendData(tester, bad.value);

      expect(find.byKey(Key('neutral-$surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });
  }

  testWidgets('$component : textes >= 24 px, sans débordement à 940 x 255', (
    tester,
  ) async {
    final h = CatalogHarness(surface, fixtureName);
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    h.expectTextAtLeast24(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  testWidgets('$component : l état neutre ne déborde pas non plus', (
    tester,
  ) async {
    final h = CatalogHarness(surface, fixtureName);
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, cloneJson(h.data)..remove('title'));
    expect(tester.takeException(), isNull);
  });
}
