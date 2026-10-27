---
id: proto-a2a-task-lifecycle
title: A2A — Task et cycle de vie (TaskState)
tags: [a2a, task, lifecycle, state-machine]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/specification/]
links: [proto-a2a-overview, proto-a2a-streaming-push, proto-a2a-message-parts-artifacts]
---
# Task A2A : une machine à états explicite

Toute interaction de longue durée devient une **Task**, identifiée par `id`/`taskId` et regroupée dans un `contextId`, qui sert de fil de conversation. Son état suit l'enum `TaskState` de la spec 1.0.

| État | Type |
|---|---|
| `TASK_STATE_SUBMITTED`, `TASK_STATE_WORKING` | actif |
| `TASK_STATE_INPUT_REQUIRED`, `TASK_STATE_AUTH_REQUIRED` | **interrompu** : le client doit répondre |
| `TASK_STATE_COMPLETED`, `TASK_STATE_FAILED`, `TASK_STATE_CANCELED`, `TASK_STATE_REJECTED` | **terminal** |
| `TASK_STATE_UNSPECIFIED` | valeur par défaut, à ne pas utiliser |

## Opérations
- `SendMessage` : crée ou continue une task. La réponse est un `Task` ou un `Message` direct.
- `GetTask` et `ListTasks` (pagination par curseur : `pageSize` 1–100, défaut 50, `pageToken`/`nextPageToken`) : consultation.
- `CancelTask` : annulation.
- `SubscribeToTask` : se ré-abonner au flux SSE d'une task en cours. L'appel renvoie `UnsupportedOperationError` si la task est terminale.

## Mapping vers l'app (opinion)
- `INPUT_REQUIRED` : l'orchestrateur demande à l'agent vocal de poser la question à l'utilisateur, ou à l'agent GenUI d'afficher un formulaire.
- `AUTH_REQUIRED` : déclencher un flux OAuth côté app.
- Les états terminaux se traduisent en events BLoC (pas de Cubit), par exemple `RemoteTaskCompleted`.

⚠️ **Pièges**
- Un état terminal est **définitif** : pour poursuivre, il faut créer une nouvelle task dans le même `contextId`.
- Les résultats vont dans les **Artifacts**, pas dans les Messages (voir proto-a2a-message-parts-artifacts).
