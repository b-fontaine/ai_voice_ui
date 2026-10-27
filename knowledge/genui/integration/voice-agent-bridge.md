---
id: genui-voice-bridge
title: Piloter genui depuis un agent vocal temps réel (patron)
tags: [genui, realtime-voice, multi-agent, orchestration, architecture]
status: opinion
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/get-started, https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md]
links: [proj-avw-genui-bridge, genui-custom-llm-adapter, genui-user-actions, genui-multiple-surfaces, genui-conversation-events, genui-a2a-connector, ma-target-architecture, rt-tool-calling-voice, bloc-no-non-serializable-state]
---
# L'agent vocal délègue l'UI à un agent GenUI texte, par un outil

Recommandation interne, issue de l'analyse de `ai_voice_widget` (proj-avw-genui-bridge) et des contraintes de genui.

Les modèles voice-to-voice (gpt-live-1, Gemini Live) ne sont pas faits pour générer de longs JSON A2UI, et le prompt `PromptBuilder` (3 000 à 5 000+ tokens) alourdirait chaque session temps réel. On sépare donc les rôles :

1. **Agent vocal :** dispose d'un outil court, par exemple `show_ui(intent: string, data?: object)`. Il répond tout de suite à l'utilisateur.
2. **Orchestrateur (Dart) :** reçoit le tool call et appelle `conversation.sendRequest(ChatMessage.user(intent))` **sans bloquer** la réponse de l'outil vocal (renvoyer « affichage en cours »).
3. **Agent GenUI :** LLM texte rapide, avec le prompt `PromptBuilder` et le catalogue métier, dans un adaptateur custom, Firebase ou A2A.
4. **Retour des actions :** `controller.onSubmit` / `UiInteractionPart` part vers l'agent GenUI. Un **résumé textuel** de l'action est injecté dans la session vocale (événement de conversation ou réponse d'outil), pour que la voix sache ce que l'utilisateur a cliqué.

## Règles
- Garder l'état genui (controller, conversation) **hors du BLoC**. Le BLoC ne connaît que les ids de surface et l'état « waiting/error ».
- Une surface principale nommée (`main`), remplacée par `deleteSurface` + `createSurface`, ou mise à jour via `PromptBuilder.custom(allowedOperations: SurfaceOperations.all(dataModel: true))`.
- Pour des données déjà structurées (résultat d'API), envoyer directement `updateDataModel` via `addMessage`, sans passer par un LLM.
- Plafonner les tours de correction d'erreur et les annuler si l'utilisateur change de sujet à la voix.

⚠️ Pièges
- Latence : un aller-retour LLM complet par écran. Il faut un modèle texte rapide et un catalogue de widgets métier compacts.
- Risque de désynchronisation voix/écran : la voix ne doit pas décrire une UI qui n'est pas encore rendue (attendre `ConversationSurfaceAdded`).
