---
id: proto-a2ui-pointer
title: A2UI — format d'UI déclaratif (renvoi vers genui-*)
tags: [a2ui, genui, ui, protocol]
status: verified
updated: 2026-10-26
sources: [https://a2ui.org/, https://pub.dev/packages/genui, https://pub.dev/packages/genui_a2a, https://docs.flutter.dev/ai/genui/get-started]
links: [proto-agui-overview, proto-a2a-message-parts-artifacts, proto-mcp-extensions, proj-avw-genui-bridge, proto-protocol-map, genui-overview, genui-a2ui-overview, genui-a2ui-messages, genui-a2a-connector, genui-a2ui-security]
---
# A2UI dans la carte des protocoles

A2UI (Agent-to-UI) est un **format** et non un transport. L'agent envoie du **JSON déclaratif**, et non du code exécutable, qui décrit des surfaces construites **uniquement à partir d'un catalogue de composants approuvé par le client**. Le rendu est natif : Flutter via genui, Lit, Angular…

## Résumé
- Créé par Google, avec des contributions de CopilotKit. Licence Apache 2.0.
- Versions au 2026-10-26 : **v0.9.1 « Current »**, v1.0 en release candidate (ajoute `actionResponse` client→serveur), v0.9 « Previous Stable », v0.8 legacy.
- Messages v0.9 : `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`.
- Il peut circuler sur plusieurs transports :
  - **A2A** : Part `data` dans un Message ou un Artifact. C'est ce que fait `genui_a2a` 0.10.1.
  - **AG-UI** : payload de génération d'UI.
  - Texte LLM direct, parsé par `A2uiTransportAdapter` dans genui 0.10.4.

## Où lire la suite
- **genui-overview**, **genui-a2ui-overview**, **genui-a2ui-messages**, **genui-a2a-connector** : intégration Flutter (`Catalog`, `SurfaceController`, `Conversation`, `Surface`), catalogues et pièges de l'alpha.
- **proj-avw-genui-bridge** : pattern existant, l'outil vocal `show_screen` qui pilote un agent GenUI.

## Pourquoi A2UI plutôt que MCP Apps pour Flutter (opinion)
- Rendu natif et cohérent avec le design system.
- Aucune exécution de code distant.
- Fonctionne sur mobile et desktop sans WebView.

⚠️ **Pièges**
- La garantie « pas d'injection d'UI » est affirmée par le projet lui-même : il reste à valider les données liées (data model) côté app.
- genui est en **alpha** et son API a déjà changé (voir domaine genui).
