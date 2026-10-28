---
id: genui-migration-from-0-7
title: Migrer de genui 0.6/0.7 (ContentGenerator) vers l'API 0.10
tags: [genui, migration, refactoring]
status: verified
updated: 2026-10-28
sources: [https://github.com/flutter/genui/blob/main/docs/usage/migration/migration_0.7.0_to_0.8.0.md, https://github.com/flutter/genui/blob/main/packages/genui/CHANGELOG.md]
links: [proj-avw-genui-bridge, genui-architecture, genui-custom-llm-adapter, genui-firebase-ai, genui-migration-0-10, genui-a2ui-messages]
---
# `ContentGenerator` a disparu en 0.8 : on écrit son propre client LLM et on pousse le texte dans `A2uiTransportAdapter`

Point de départ : `ai_voice_widget` (proj-avw-genui-bridge) utilise l'API 0.6/0.7.

| API 0.6/0.7 (ex. ai_voice_widget) | API 0.10.x |
|---|---|
| `CoreCatalogItems.asCatalog()` | `BasicCatalogItems.asCatalog()` |
| `A2uiMessageProcessor(catalogs:)` (ex-`GenUiManager`) | `SurfaceController(catalogs:)` |
| `GenUiConversation(a2uiMessageProcessor:, contentGenerator:)` | `Conversation(controller:, transport:)` |
| `GenUiSurface(host:, surfaceId:)` | `Surface(surfaceContext: controller.contextFor(id))` |
| `onSurfaceAdded` / `onSurfaceDeleted` | `conversation.events` → `ConversationSurfaceAdded` / `Removed` |
| `FirebaseAiContentGenerator` | `firebase_ai` direct + `A2uiTransportAdapter(onSend:)` |
| `ContentGenerator` OpenAI maison | `Transport` ou `onSend` maison (genui-custom-llm-adapter) |
| outil `surfaceUpdate` + `parseToolCall` | texte A2UI v0.9 parsé par `addChunk`, ou `addMessage(A2uiMessage.fromJson(args))` |
| `configureGenUiLogging` | `configureLogging` |
| `genui_a2ui` / `GenUiA2uiConnector` | `genui_a2a` / `A2uiAgentConnector` |

## Étapes
1. Supprimer les paquets `genui_firebase_ai`, `genui_google_generative_ai` et `genui_dartantic`, et dépendre des SDK directement.
2. Remplacer le générateur par `A2uiTransportAdapter` + `Conversation`. L'historique et la limite de cycles (20 dans ai_voice_widget, proj-avw-genui-bridge) passent dans votre `onSend`.
3. **Régénérer le prompt** avec `PromptBuilder` : A2UI v0.9 est « prompt first ». Sans le schéma dans le prompt, le JSON généré sera invalide.
4. Adapter tout JSON écrit à la main : `beginRendering` → `createSurface` (avec `catalogId`, et `theme` au lieu de `styles`) ; `{"Text": {...}}` → `{"component": "Text", ...}` ; `literalString`/`binding` → littéral ou `{"path": ...}` ; `userAction` → `action` ; `usageHint` → `variant` ; `distribution`/`alignment` → `justify`/`align`.
5. Les parts UI : `part is UiPart` → `part.isUiPart` / `part.asUiPart` (vues sur `DataPart` de `genai_primitives`).
6. Enchaîner avec genui-migration-0-10 (types `a2ui_core`).

⚠️ Pièges
- Le schéma de l'outil `surfaceUpdate` (v0.8) est **incompatible** avec v0.9 : le réécrire ou basculer vers la sortie texte.
- Garder la décision « état genui hors BLoC » : elle reste valide.
