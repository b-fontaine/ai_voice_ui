---
id: genui-a2ui-client-messages
title: A2UI v0.9 — messages client → agent (action, error, capabilities)
tags: [a2ui, protocol, events, capabilities]
status: verified
updated: 2026-10-26
sources: [https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md, https://a2ui.org/concepts/actions/]
links: [genui-user-actions, genui-error-reporting, genui-a2ui-messages, genui-a2a-connector, genui-catalog-ids]
---
# Le flux UI va de l'agent vers le client ; le retour passe par `action`, `error` et les métadonnées du transport

**`action`** : envoyé quand l'utilisateur déclenche un composant qui a `action.event`.
- `name`, `surfaceId`, `sourceComponentId`, `timestamp` (ISO 8601) et `context` (objet résolu depuis le data model) sont tous requis.

**`error`** : erreur côté client. Format standard pour la validation : `{code: "VALIDATION_FAILED", surfaceId, path, message}`.

**Métadonnées** (pas des messages A2UI de premier rang en v0.9) :
- `a2uiClientCapabilities` : `supportedCatalogIds[]` (requis) et `inlineCatalogs[]` (catalogues ad hoc fournis par le client).
- `a2uiClientDataModel` : `{surfaces: {id: dataModel}}`, envoyé avec chaque message si `createSurface.sendDataModel` vaut true.
- Côté serveur : `server_capabilities` (catalogues générables, acceptation des inline catalogs), via l'AgentCard A2A ou l'initialisation MCP.

**Actions locales :** `action.functionCall` (ex. `openUrl`) s'exécute sur le client et ne produit pas de message.

⚠️ Pièges
- `context` ne contient que ce que l'agent a déclaré. Pour récupérer tout le formulaire, mettre `sendDataModel: true` ou lister les `path` dans le contexte.
- En v1.0 RC, le schéma `client_to_server` devient `renderer_to_agent`. `action` gagne `userMessage` et `metadata`, et s'ajoutent `callAgentFunction` / `rendererFunctionResponse` (voir genui-a2ui-v1-rc).
