---
id: proto-a2a-go-v03-compat
title: a2a-go v2 face à un client A2A v0.3 (genui_a2a) — binding a2av0
tags: [a2a, go, a2acompat, json-rpc, genui, compat]
status: verified
updated: 2026-10-29
sources: [https://github.com/a2aproject/a2a-go, https://pub.dev/packages/genui_a2a]
links: [ma-backend-sdk-go, genui-a2a-connector, proto-a2a-bindings, proto-a2a-dart-sdk, proto-a2a-agent-card]
---
# Servir `genui_a2a` avec `a2a-go/v2` : monter le handler `a2av0`, pas le natif

Vérifié le 2026-10-29 (code lu et essai de bout en bout) avec `github.com/a2aproject/a2a-go/v2` **v2.7.0** (Go 1.27.3) et `genui_a2a` **0.10.1**. `genui_a2a` parle A2A **v0.3** : `message/stream` et `message/send`, `kind` sur messages/parts/événements, rôles `user`/`agent`, aucun en-tête `A2A-Version`.

| Handler | Méthodes servies | Face à `genui_a2a` |
|---|---|---|
| `a2asrv.NewJSONRPCHandler` (natif v1.0) | `SendMessage`, `SendStreamingMessage`… | ❌ `-32009 requested "0.3", served "1.0"` sans `A2A-Version` ; `message/stream` → `-32601` |
| `a2acompat/a2av0.NewJSONRPCHandler` | `message/send`, `message/stream`, `tasks/*` | ✅ à monter sur `POST /` (l'URL de base est l'endpoint JSON-RPC) |

- La carte se sert sur `/.well-known/agent-card.json` ; `genui_a2a` exige à la désérialisation `protocolVersion`, `name`, `description`, `url`, `version`, `capabilities`, `defaultInputModes`, `defaultOutputModes`, `skills`.
- Un flux A2UI valide : événement `task` (`submitted`), puis des `status-update` dont `status.message.parts` contient `{"kind":"data","data":{"version":"v0.9", …}}` (un message A2UI par part), puis `status-update` `completed` avec `final: true`. Les `artifact-update` sont ignorés par le connecteur.
- Une action utilisateur arrive comme part `data` ; la répondre en `message/stream` renvoie le `updateDataModel` au connecteur.

⚠️ Pièges
- `a2av0.NewStaticAgentCardProducer` n'écrit `url` ni `preferredTransport` si l'interface de la carte n'est pas en `ProtocolVersion` « 0.3 » : avec `a2a.NewAgentInterface` (1.0) `genui_a2a` ne décode pas la carte. Construire l'interface à la main avec `a2av0.Version`.
- Le magasin de tâches en mémoire copie les tâches par `gob` : un `[]map[string]any` dans une part fait passer la tâche en `failed` (`gob: type not registered…`). N'utiliser que `map[string]any` et `[]any`.
- `genui_a2a` ne pose jamais `message.taskId`, seulement `referenceTaskIds` : chaque tour crée une nouvelle tâche dans le même `contextId`.
- `A2uiAgentConnector.sendEvent` (`message/send`) jette la réponse : une mise à jour A2UI renvoyée par ce chemin n'atteint jamais `connector.stream`. Passer par `connectAndSend`.
