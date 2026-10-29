---
id: proto-a2a-go-executor-lifecycle
title: a2a-go v2 — cycle de vie d'un exécuteur et d'un client (annulation, flux, états)
tags: [a2a, go, executor, cancel, streaming, client]
status: verified
updated: 2026-10-29
sources: [https://github.com/a2aproject/a2a-go]
links: [proto-a2a-go-v03-compat, proto-a2a-task-lifecycle, proto-a2a-streaming-push, ma-backend-sdk-go]
---
# a2a-go v2.7.0 : annulation et flux, ce qui surprend

Vérifié le 2026-10-29 (code lu et tests en processus, `github.com/a2aproject/a2a-go/v2` v2.7.0) pour un orchestrateur Go client d'un agent Go, tous deux en A2A natif v1.0.

**Côté serveur (`a2asrv`)**
- Le contexte de l'exécuteur est **détaché de la requête HTTP** : fermer la connexion SSE n'annule rien. Seul `CancelTask` annule le contexte de l'exécuteur (publie `canceled`, puis annule via une table tâche → `cancel`). Un client qui abandonne un flux doit donc envoyer `CancelTask`.
- Si l'exécuteur rend la main **sans état final**, le flux reste ouvert (le serveur attend) : le client doit borner la tâche par un délai.
- Le serveur refuse un `taskId` différent de celui de la tâche en cours dans un même flux.
- Le magasin de tâches en mémoire n'a pas d'éviction ; il copie par `gob` : n'y mettre que `map[string]any` et `[]any` ([[proto-a2a-go-v03-compat]]).

**Côté client (`a2aclient`)**
- `SendStreamingMessage` renvoie un `iter.Seq2` : pas de goroutine à gérer ; arrêter l'itération ne suffit pas à annuler la tâche côté serveur.
- `agentcard.Resolver` sait lire `file://` : n'accepter que `http(s)` pour une URL configurée ; vérifier que l'interface JSON-RPC de la carte a **même schéma, hôte et port** que l'URL de carte (sinon SSRF par carte hostile) ; ne pas suivre les redirections.
- Une tâche peut arriver d'abord en `working` : l'identifiant de tâche, pas l'état `submitted`, signale le début.
- Libérer le client (`Destroy`) après chaque tâche.

**Convention A2UI sur A2A** : un message A2UI v0.9 par part `data` d'un `status-update` `working` ; le résumé factuel dans un artefact texte ; fin par `completed`.
