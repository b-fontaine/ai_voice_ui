---
id: proj-avw-genui-bridge
title: ai_voice_widget — pont voix → GenUI/A2UI
tags: [project, genui, a2ui, multi-agent]
status: verified
updated: 2026-10-26
sources: ["~/septeo/ai_voice_widget (analyse locale du code, 2026-10-26)"]
links: [proj-avw-overview, genui-voice-bridge, genui-migration-from-0-7, bloc-no-non-serializable-state, ma-target-architecture]
---
# Pont « l'agent voix délègue l'UI à un second LLM »

- `VoiceAi.start` démarre `GenUiService` en parallèle (`domain/voice_ai.dart:59-73`).
- L'outil vocal `show_screen(description)` appelle `GenUiService.sendMessage(description)`.
- `GenUiService` utilise :
  - `CoreCatalogItems.asCatalog()`, `A2uiMessageProcessor`, `GenUiConversation`
  - le suivi des `surfaceIds` via `onSurfaceAdded` / `onSurfaceDeleted`
  - le rendu par `GenUiSurface(host, surfaceId)`
- **Générateurs de contenu :**
  - Gemini : `FirebaseAiContentGenerator`.
  - OpenAI : `ContentGenerator` maison sur Chat Completions `gpt-4o` (`catalogToFunctionDeclaration` → outil `surfaceUpdate` → `parseToolCall` → `A2uiMessage`), boucle limitée à 20 cycles.
- **Décision de conception :** l'état GenUI reste **hors du BLoC**, car ses objets ne sont pas sérialisables (`agent-os/specs/2026-03-12-1000-genui-widget-integration/plan.md`).
- C'est un pattern réutilisable pour une architecture orchestrateur / agent vocal / agent GenUI.
