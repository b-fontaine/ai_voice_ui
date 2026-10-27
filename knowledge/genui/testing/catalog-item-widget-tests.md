---
id: genui-test-catalog-items
title: Tester un CatalogItem (widget test + validation des exemples)
tags: [genui, testing, widget-test, catalog]
status: verified
updated: 2026-10-26
sources: [https://github.com/flutter/genui/blob/main/packages/genui/test/catalog_test.dart, https://github.com/flutter/genui/tree/main/packages/genui/test/test_infra]
links: [genui-custom-catalog-item, genui-test-surface-controller, test-pyramid-flutter, test-golden-alchemist]
---
# Un CatalogItem se teste sans LLM : `catalog.buildWidget(CatalogItemContext(...))` dans un `testWidgets`

C'est le patron des tests du package lui-même (`test/catalog_test.dart`) :

```dart
testWidgets('AppointmentCard affiche la date', (tester) async {
  final catalog = Catalog([appointmentCard]);
  final events = <UiEvent>[];
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
    builder: (context) => catalog.buildWidget(CatalogItemContext(
      id: 'card1', type: 'AppointmentCard',
      data: {'title': 'RDV', 'date': '2026-11-02'},
      buildChild: (_, [_]) => const SizedBox(),
      dispatchEvent: events.add,
      buildContext: context,
      dataContext: DataContext(InMemoryDataModel(), DataPath.root),
      getComponent: (_) => null, getCatalogItem: (_) => null,
      surfaceId: 's', reportError: (e, s) => fail('$e'),
    )),
  ))));
  expect(find.text('RDV'), findsOneWidget);
  await tester.tap(find.byType(ElevatedButton));
  expect(events.single.isUserAction, isTrue);
});
```

- **Valider `exampleData` contre le schéma :** `package:genui/test.dart` exporte `validateCatalogItemExamples(item, catalog)` (async, renvoie une `List<ExampleValidationError>` vide si OK), basé sur `A2uiSchemas.updateComponentsSchema(catalog)`. Le wrapper `validateCatalogExamples` de `test/test_infra/`, lui, n'est pas exporté.
- **Contrôle visuel :** `DebugCatalogView` (exporté) affiche tous les items qui ont un `exampleData`. Utile pour des golden tests ou une page de debug.
- Pour du BDD, encapsuler `pumpCatalogItem(tester, item, data)` dans une étape réutilisable (opinion).

⚠️ Pièges
- `CatalogItemContext` a beaucoup de paramètres requis et peut changer à chaque mineure alpha : centraliser sa construction dans un helper de test.
- Les items avec `Image`/`Video` réseau nécessitent un mock (`network_image_mock` dans l'exemple `simple_chat`).
