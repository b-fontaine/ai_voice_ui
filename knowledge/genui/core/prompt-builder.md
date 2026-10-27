---
id: genui-prompt-builder
title: PromptBuilder — prompt système généré depuis le catalogue
tags: [genui, prompt, llm, tokens]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/get-started, https://github.com/flutter/genui/blob/main/packages/genui/lib/src/facade/prompt_builder.dart, https://github.com/flutter/genui/blob/main/docs/usage/migration/migration_0.7.0_to_0.8.0.md]
links: [genui-architecture, genui-multiple-surfaces, genui-custom-catalog-item, genui-custom-llm-adapter]
---
# Le prompt système porte le schéma A2UI et les règles du catalogue

A2UI v0.9 est « prompt first » : le LLM ne produit du JSON valide que si le prompt système contient le schéma des messages, celui du catalogue et les règles de base. `PromptBuilder` génère tout cela.

```dart
final pb = PromptBuilder.chat(
  catalog: catalog,
  systemPromptFragments: ['Tu es l’agent UI. Utilise RiddleCard pour…'],
);
final systemInstruction = pb.systemPromptJoined();
```

- `PromptBuilder.chat(...)` autorise seulement **`SurfaceOperations.createOnly(dataModel: false)`** : chaque tour crée une nouvelle surface et ne met pas à jour les surfaces existantes.
- `PromptBuilder.custom(catalog:, allowedOperations:, technicalPossibilities:, clientDataModel:)` règle les opérations : `createOnly`, `updateOnly`, `createAndUpdate` ou `all({required bool dataModel})`.
- Les fragments utilitaires sont des méthodes statiques : `PromptBuilder.acknowledgeUser()`, `requireAtLeastOneSubmitElement()`, `currentDate()`, `uiGenerationRestriction()`.

⚠️ Pièges
- La doc prévient : `PromptBuilder.chat()` peut produire **3 000 à 5 000+ tokens**. C'est trop pour un petit modèle et coûteux sur chaque tour d'un modèle temps réel.
- Le CHANGELOG 0.10.0 annonce le passage à `createChat`/`createCustom` asynchrones, mais le code `main` (oct. 2026) expose toujours `chat`/`custom` synchrones. Il faut vérifier sur la version épinglée.
- Un widget custom n'est utilisé que si le prompt le mentionne explicitement (one-shot ou few-shot).
