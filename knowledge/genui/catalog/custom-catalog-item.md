---
id: genui-custom-catalog-item
title: Créer un CatalogItem personnalisé (schéma + builder)
tags: [genui, catalog, widgets, json-schema]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/get-started, https://github.com/flutter/genui/blob/main/packages/genui/lib/src/model/catalog_item.dart, https://github.com/flutter/genui/tree/main/packages/genui/skills]
links: [genui-catalog-ids, genui-prompt-builder, genui-data-model, genui-user-actions, genui-test-catalog-items, ux-genui-catalog-as-ds]
---
# Un CatalogItem = nom + schéma JSON + widgetBuilder

Le LLM ne peut produire que des composants déclarés dans le catalogue. Un item se compose d'un `name` (la valeur de `"component"`), d'un `dataSchema` (`json_schema_builder`) et d'un `widgetBuilder`.

```dart
final riddleCard = CatalogItem(
  name: 'RiddleCard',
  dataSchema: S.object(properties: {
    'question': S.string(description: 'La question.'),
    'answer': S.string(description: 'La réponse.'),
  }, required: ['question', 'answer']),
  widgetBuilder: (ctx) {
    final json = ctx.data as Map<String, Object?>;
    return RiddleCard(question: json['question'] as String,
                      answer: json['answer'] as String);
  },
  exampleData: [() => '[{"id":"root","component":"RiddleCard","question":"…","answer":"…"}]'],
);
final catalog = BasicCatalogItems.asCatalog().copyWith(newItems: [riddleCard]);
```

`CatalogItemContext` fournit : `data`, `id`, `type`, `buildChild(id)` pour les enfants par référence, `dispatchEvent`, `dataContext`, `buildContext`, `getComponent`, `surfaceId` et `reportError`.

- Les descriptions du schéma sont injectées dans le prompt : les écrire pour le LLM (le quoi et le quand).
- `exampleData` sert à `DebugCatalogView` et aux tests de validation (voir genui-test-catalog-items).
- Le package livre des « skills » d'agent de code (`create-catalog-item`, `integrate-genui-firebase`) dans `packages/genui/skills`.
- Pour les valeurs liables, résoudre via `BoundString`/`dataContext` plutôt que de caster `ctx.data` (sinon `{"path":…}` casse le cast).

⚠️ Pièges
- `CatalogItem.dataSchema` ajoute automatiquement `component` (enum = `name`) et `additionalProperties: true`.
- Ajouter un item ne suffit pas : il faut aussi le nommer dans `systemPromptFragments`.
- Préférer des widgets métier de haut niveau (`AppointmentCard`) aux primitives : moins de tokens, rendu plus fiable (opinion).
