# SP-03 — Notes S1 (lecture du code) et S2 (agent Go)

Date : 2026-10-29. Versions résolues : `genui_a2a` 0.10.1 (`~/.pub-cache/hosted/pub.dev/genui_a2a-0.10.1`), `github.com/a2aproject/a2a-go/v2` **v2.7.0** (tire aussi `github.com/a2aproject/a2a-go` v0.3.15, utilisé par `a2acompat/a2av0` pour les types v0.3), Go **1.27.3** linux/amd64.

Les chemins `genui_a2a` ci-dessous sont relatifs à `lib/src/` ; ceux d'`a2a-go` sont relatifs au module `a2a-go/v2@v2.7.0`.

## S1 — Constats

### 1. Méthodes JSON-RPC et version A2A de `genui_a2a`
- Le transport est du **JSON-RPC 2.0 en nommage A2A v0.3** : `message/stream` (`a2a/client/a2a_client.dart:188`, journalisé aussi en `a2ui_agent_connector.dart:167`), `message/send` (`a2a_client.dart:146`, utilisé par `sendEvent`, `a2ui_agent_connector.dart:313`), `tasks/get` (:248), `tasks/list` (:270), `tasks/cancel` (:293), `tasks/resubscribe` (:318), `tasks/pushNotificationConfig/{set,get,list,delete}` (:357-446).
- Aucune méthode PascalCase (`SendStreamingMessage`…) n'est envoyée. Les enveloppes sont celles de la v0.3 : `kind` sur messages, parts et événements (`"message"`, `"text"`/`"data"`/`"file"`, `"task"`, `"status-update"`), rôles `user`/`agent` (`a2a/core/message.g.dart`), états `input-required`, `auth-required`… (`core/task.g.dart`, `_$TaskStateEnumMap`), `AgentCard.protocolVersion` obligatoire (`core/agent_card.g.dart`).
- Aucun en-tête `A2A-Version` n'est envoyé (recherche `A2A-Version` : 0 occurrence dans `lib/`).
- Les paramètres de `message/stream` sont `{configuration: null, metadata: null, message: {...}}` (`a2a_client.dart:185-190`) ; `extensions` est ajouté aux paramètres si le message en porte (:191).

### 2. Agent card
- Chemin : `/.well-known/agent-card.json` (`a2a_client.dart:90`), en GET sur `<url><path>` (`a2a/client/http_transport.dart:45`). `A2uiAgentConnector.getAgentCard()` (`a2ui_agent_connector.dart:84`) l'appelle ; `connectAndSend` **ne la lit pas** (aucune découverte préalable).
- Champs **obligatoires** à la désérialisation (`core/agent_card.g.dart`, `_$AgentCardFromJson`) : `protocolVersion`, `name`, `description`, `url`, `version`, `capabilities`, `defaultInputModes`, `defaultOutputModes`, `skills`. Optionnels : `preferredTransport` (`JSONRPC`/`GRPC`/`HTTP+JSON`), `additionalInterfaces[{url, transport}]`, `capabilities.{streaming,pushNotifications,extensions[]}`, `securitySchemes`…
- Le champ v1.0 `supportedInterfaces` n'est pas lu ; c'est `url` (racine de la carte) qui compte pour `A2AClient.fromAgentCardUrl` (`a2a_client.dart:85`). `A2uiAgentConnector` n'utilise pas ce chemin : il reçoit l'URL directement.

### 3. En-têtes envoyés
- `X-A2A-Extensions: https://a2ui.org/a2a-extension/a2ui/v0.9` sur **toutes** les requêtes du connecteur créé avec `url:` (`a2ui_agent_connector.dart:19-21, 51` ; fusion dans `a2a/client/sse_transport.dart:55-60`). Préfixe `X-` hérité de la v0.3 ; pas de `A2A-Extensions`.
- `Content-Type: application/json` et `Accept: text/event-stream` pour le stream (`sse_transport.dart:56-57`). Pas d'`Authorization` sauf `getAuthenticatedExtendedCard`.
- Pour `sendEvent`, l'en-tête est aussi posé par message (`a2a_client.dart:151-153`) avec `message.extensions`.
- **Point d'URL** : tous les POST partent vers `Uri.parse('$url$path')` avec `path = ''` (`http_transport.dart:69`, `sse_transport.dart:44`) : l'endpoint JSON-RPC est l'**URL de base elle-même** (pas `/rpc`), et la carte se lit en `<url>/.well-known/agent-card.json`. Une URL de base avec barre finale produirait `//.well-known/…`.

### 4. Format des parts A2UI attendu en réponse
- SSE : lignes `data: {...}` ; seul `result` du JSON-RPC est transmis, un `error` lève `A2AException.jsonRpc` (`a2a/client/sse_parser.dart:79-93`). Les lignes `:` sont ignorées (keep-alive).
- `A2AClient.messageStream` (`a2a_client.dart:216-228`) : événement sans `kind` ignoré ; `kind == 'task'` converti en `StatusUpdate` (avec `task.status`) ; sinon `Event.fromJson`, qui n'accepte que `status-update`, `task-status-update`, `artifact-update` (`core/events.dart:34-38`) et **lève `ArgumentError`** pour tout autre `kind`, notamment `"message"` : **un agent ne doit pas répondre par un `Message` nu**.
- Le connecteur ne lit les parts A2UI **que dans `status.message` d'un `StatusUpdate`/`TaskStatusUpdate`** (`a2ui_agent_connector.dart:189-223, 225-260`). Les `artifact-update` sont ignorés. Les parts `data` (`kind: "data"`, `data: {...}`) sont passées à `_processA2uiMessages` (:213-215), qui exige une des clés `createSurface`/`updateComponents`/`updateDataModel`/`deleteSurface` (:336-339) puis fait `A2uiMessage.fromJson(data)` (`a2ui_core`, `version` doit valoir `"v0.9"`). **Une part `data` = un message A2UI** (pas de tableau). Pas de `mimeType` requis ni lu sur la part (les `FilePart` ne sont pas traitées en entrée, :213-221). Les parts `text` non vides alimentent `textStream` (:216-221).
- Un statut `failed`/`canceled`/`rejected` alimente `errorStream` et saute le message (:194-204).
- Côté entrée : `metadata.a2uiClientCapabilities` (= `clientCapabilities.toJson()`) et `metadata.a2uiClientDataModel` sont posés sur le **Message** (pas sur les params) (:154-163). Le texte utilisateur est une part `text`. Une `UiInteractionPart` (clic) dont le JSON est un objet devient une part `data` `{ "version":"v0.9","action":{...} }` (:112-118), envoyée par le même `message/stream`.
- `contextId` et `taskId` sont retenus depuis les `status-update` (:190-191, 226-227) ; au message suivant, `contextId` est renvoyé et le `taskId` va dans `referenceTaskIds` (non dans `message.taskId`) (:146-152).
- **Limite pour S4** : `sendEvent` (:283-324, `message/send`) **jette le résultat** (simple journal, :313-320) et exige que `result` soit une `Task` (`Task.fromJson`). Une mise à jour A2UI renvoyée en réponse à `sendEvent` n'atteint donc jamais `connector.stream`. Le chemin utile est celui de `connectAndSend` avec la `UiInteractionPart` (cf. [genui-user-actions] : `Conversation` → `onSend` → `connectAndSend`).

### 5. `a2a-go` v2 : quel binding monter
- Le handler natif `a2asrv.NewJSONRPCHandler` (`a2asrv/jsonrpc.go:42`) sert les noms v1.0 : `SendMessage`, `SendStreamingMessage`, `GetTask`, `ListTasks`, `CancelTask`, `SubscribeToTask`, `GetExtendedAgentCard`, `*TaskPushNotificationConfig` (`internal/jsonrpc/jsonrpc.go:38-48`), et exige/valide `A2A-Version` (réponse `-32009 VERSION_NOT_SUPPORTED: requested "0.3", served "1.0"` sans en-tête).
- Le handler compat `a2av0.NewJSONRPCHandler` (`a2acompat/a2av0/jsonrpc_server.go:38`) sert les noms **v0.3** : `message/send`, `message/stream`, `tasks/get`, `tasks/cancel`, `tasks/resubscribe`, `tasks/pushNotificationConfig/*`, `agent/getAuthenticatedExtendedCard` (`a2acompat/a2av0/jsonrpc.go:3-14`). Il convertit `X-A2A-Extensions` en `A2A-Extensions` (`conversions.go:34-47`) et sérialise les événements via `FromV1Event` (`kind`, `role: "agent"`, parts `{kind:"data", data:{…}}`).
- Carte : `a2av0.NewStaticAgentCardProducer(card)` (`a2acompat/a2av0/agentcard.go:63`) émet une **union v1.0 + v0.3** (`protocolVersion:"0.3"`, `url`, `preferredTransport`, `skills[].tags`…). **Piège** : `url` et `preferredTransport` ne sont écrits que si une entrée de `SupportedInterfaces` a `ProtocolVersion == "0.3"` (`agentcard.go:273-288`) ; avec `a2a.NewAgentInterface(...)` (version `1.0`) ils sont absents et `genui_a2a` ne pourrait pas décoder la carte (`url` requis). Il faut construire l'interface à la main avec `ProtocolVersion: a2av0.Version`.
- Servir la carte : `a2asrv.NewAgentCardHandler(producer)` sur `a2asrv.WellKnownAgentCardPath` (`a2asrv/agentcard.go:26,109`) ; il utilise `CardJSON` du producteur compat.
- **Piège gob** : le magasin de tâches en mémoire copie les tâches par `gob`. Une `Part` de données contenant `[]map[string]any` fait échouer la tâche (`gob: type not registered for interface: []map[string]interface {}`) ; n'utiliser que `map[string]any` / `[]any` / scalaires.

### Verdict S1
**Compatible via `a2acompat/a2av0`** (binding JSON-RPC v0.3). `genui_a2a` 0.10.1 parle A2A **v0.3** (`message/stream`, `kind`, rôles minuscules, carte v0.3, `X-A2A-Extensions`) ; le handler natif v1.0 est incompatible (noms PascalCase, `A2A-Version`, formes de parts) ; le handler compat `a2av0` convient et se monte sur l'URL de base. Conditions : carte avec interface `ProtocolVersion "0.3"`, un message A2UI par `status-update` portant `status.message`, jamais de `Message` nu, données gob-compatibles. Limite : `sendEvent` (`message/send`) ne ramène pas de mise à jour A2UI ; passer par `connectAndSend`.

## S2 — Agent Go (`spikes/sp03-a2a/agent/`)

`go.mod` : module `sp03agent`, `go 1.27.3`, `github.com/a2aproject/a2a-go/v2 v2.7.0` (+ indirects, dont `github.com/a2aproject/a2a-go v0.3.15`, `grpc v1.83.2`).

Routes : `POST /` (compat v0.3, `a2av0`), `GET /.well-known/agent-card.json` (carte union), `POST /v1` (binding natif v1.0, monté seulement pour comparaison). Écoute `127.0.0.1:<port>` (`-port`, défaut 8765), arrêt propre sur SIGINT/SIGTERM.

Commandes et sorties :

```
$ go build ./... && go vet ./...        # aucune sortie, code 0
$ (sp03agent -port 8765 &) ; curl -si http://127.0.0.1:8765/.well-known/agent-card.json
HTTP/1.1 200 OK / Content-Type: application/json
... "url": "http://127.0.0.1:8765", "protocolVersion": "0.3", "preferredTransport": "JSONRPC",
    "capabilities": {"extensions":[{"uri":"https://a2ui.org/a2a-extension/a2ui/v0.9",...}],"streaming":true,...},
    "supportedInterfaces":[{"url":"http://127.0.0.1:8765","protocolBinding":"JSONRPC","protocolVersion":"0.3"}], ...

$ curl -sN -X POST http://127.0.0.1:8765/ -H 'Content-Type: application/json' -H 'Accept: text/event-stream' \
    -H 'X-A2A-Extensions: https://a2ui.org/a2a-extension/a2ui/v0.9' \
    -d '{"jsonrpc":"2.0","method":"message/stream","id":1,"params":{"configuration":null,"metadata":null,"message":{"role":"user","parts":[{"kind":"text","text":"x"}],"messageId":"m-1","kind":"message"}}}'
-> kind=task state=submitted
   kind=status-update state=working  message.parts=[{kind:data,data:{version:v0.9,createSurface:{surfaceId:main,catalogId:.../basic/catalog.json,sendDataModel:true}}}]
   kind=status-update state=working  message.parts=[{kind:data,data:{version:v0.9,updateComponents:{surfaceId:main,components:[Column root, Text label, Text value{path:/crashFree}, Text status{path:/status}, Text validate_label, Button validate{action.event.name:validate}]}}}]
   kind=status-update state=working  message.parts=[{kind:data,data:{version:v0.9,updateDataModel:{surfaceId:main,path:/crashFree,value:"99,57 %"}}}]
   kind=status-update state=completed final=true

# Action (part data {"version":"v0.9","action":{"name":"validate",...}}) via message/stream, contextId + referenceTaskIds fournis
-> task submitted ; status-update working + {updateDataModel:{surfaceId:main,path:/status,value:"validé"}} ; status-update completed
# Même action via message/send : result = Task completed (history 2), sans status.message
# SendMessage sur POST / (handler v0.3)          -> {"error":{"code":-32601,"message":"method not found"}}
# message/stream sur POST /v1 (handler natif)    -> -32601 method not found
# SendStreamingMessage sur /v1 sans A2A-Version  -> -32009 "requested \"0.3\", served \"1.0\""
```

Arrêt : `kill <pid>` du seul PID lancé ; le journal affiche « arrêt propre ».

Premier essai raté (gob) : réponse `kind=task state=failed` et journal `failed to save task state: gob: type not registered for interface: []map[string]interface {}` ; corrigé en utilisant `[]any`.

## Questions ouvertes pour S3 (client Flutter)
- Vérifier avec le vrai `A2uiAgentConnector` que `a2ui_core` 0.9 accepte `Button.child` + `action.event` et `Text.text` lié par `{path}` tels que produits (spécification v0.9 ; non vérifié côté Dart).
- Les clics doivent passer par `connectAndSend` (via `A2uiTransportAdapter.onSend`) et non `sendEvent` ; à confirmer en test.
- Le connecteur reçoit `kind: task` (`submitted`) en tête de flux, converti en `StatusUpdate` sans message : sans effet attendu.
- `X-A2A-Extensions` n'est pas exigé par l'agent du spike (aucune vérification) ; décider si l'agent de production doit refuser/ignorer l'absence de l'extension.
- Le `message.taskId` n'est jamais posé par `genui_a2a` (seulement `referenceTaskIds`) : chaque tour crée une nouvelle tâche dans le même `contextId`.
