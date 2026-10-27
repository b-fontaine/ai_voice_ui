---
id: genui-a2ui-v1-rc
title: A2UI v1.0 RC — changements majeurs vs v0.9
tags: [a2ui, protocol, versions, migration]
status: verified
updated: 2026-10-26
sources: [https://github.com/google/A2UI/blob/main/specification/v1_0/docs/evolution_guide.md, https://github.com/google/A2UI]
links: [genui-a2ui-messages, genui-a2ui-client-messages, genui-catalog-ids, genui-data-model]
---
# v1.0 (release candidate au 2026-10-26) casse le format des bindings et ajoute le RPC bidirectionnel

Principaux changements (guide d'évolution v0.9 → v1.0) :
- **Préfixe `@` réservé :** `{"@path": ...}`, `{"@call": ...}`, `@index`. Un objet `{"path": ...}` sans `@` devient un **littéral**.
- **RPC bidirectionnel :** `callRendererFunction` / `rendererFunctionResponse` (agent → UI) et `callAgentFunction` / `agentFunctionResponse` (UI → agent). Le catalogue déclare `allowedCallers` et `requiresUserActivation`.
- **Catalogues mélangeables** dans une même surface : `catalogId` optionnel par composant, celui de `createSurface` sert de défaut.
- **`createSurface` peut embarquer composants et data model initiaux** : une UI complète en un seul message.
- Suppression de `theme` et `primaryColor` (le branding est séparé de la structure).
- Renommage « client/serveur » en **renderer/agent** (`agent_to_renderer`, `renderer_to_agent`).
- Contraintes de composition `allowedParents`/`allowedChildren`. `Surface` devient un nom de composant réservé.
- `Action.event.userMessage` : texte résolu par le renderer, puis joint à l'`action` (utile pour résumer un clic à un agent vocal).
- Accessibilité renforcée : `live` (ARIA) et `hidden`. Champ `instructions` dans le catalogue, et `protocolVersion`.

⚠️ Pièges
- **Ne pas migrer par rechercher/remplacer** `"path"` → `"@path"` : les templates de `ChildList` et le `path` de `updateDataModel` gardent leur forme.
- genui 0.10.x n'implémente pas v1.0 : rester en v0.9 tant que genui (ou `a2ui_flutter`) n'annonce pas le support.
