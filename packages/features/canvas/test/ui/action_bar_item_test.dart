import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Affichage de `ActionBar` seul sur la surface `actions` (le clic et la place
/// dans le plateau relèvent de T15/T16/T17).
void main() {
  late SurfaceController controller;

  Future<void> pumpActions(
    WidgetTester tester, {
    Object? Function(Map<String, dynamic> value)? alter,
  }) async {
    controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
    addTearDown(controller.dispose);
    final fixture = contractFixture(
      'actions',
      GenesisContract.defaultCatalogId,
      variant: 'act2',
    );
    for (final Map<String, dynamic> json in fixture) {
      if (alter != null && json.containsKey('updateDataModel')) {
        final body = json['updateDataModel'] as Map<String, dynamic>;
        body['value'] = alter(cloneJson(body['value'] as Map<String, dynamic>));
      }
      controller.handleMessage(a2ui.A2uiMessage.fromJson(json));
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
        ),
        home: Scaffold(
          body: SizedBox(
            width: 940,
            height: 200,
            child: Surface(surfaceContext: controller.contextFor('actions')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('la fixture act2-actions affiche le titre et les deux boutons', (
    tester,
  ) async {
    await pumpActions(tester);
    expect(find.text('Décision'), findsOneWidget);
    expect(find.text('Bloquer la release'), findsOneWidget);
    expect(find.text('Valider la release'), findsOneWidget);
    expect(find.byKey(const Key('neutral-actions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  final Map<String, Object? Function(Map<String, dynamic>)> bad =
      <String, Object? Function(Map<String, dynamic>)>{
        'sans title': (v) => v..remove('title'),
        'sans actions': (v) => v..remove('actions'),
        'tone hors enum': (v) {
          ((v['actions'] as List)[0] as Map)['tone'] = 'success';
          return v;
        },
        'id d action inconnu': (v) {
          ((v['actions'] as List)[0] as Map)['id'] = 'delete_release';
          return v;
        },
        'action sans label': (v) {
          ((v['actions'] as List)[1] as Map).remove('label');
          return v;
        },
      };
  for (final MapEntry<String, Object? Function(Map<String, dynamic>)> e
      in bad.entries) {
    testWidgets('${e.key} : état neutre, aucun bouton', (tester) async {
      await pumpActions(tester, alter: e.value);
      expect(find.byKey(const Key('neutral-actions')), findsOneWidget);
      expect(find.text('Bloquer la release'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
