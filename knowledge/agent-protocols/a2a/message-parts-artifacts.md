---
id: proto-a2a-message-parts-artifacts
title: A2A — Message, Part et Artifact
tags: [a2a, messages, part, artifact, data-model]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/specification/, https://a2a-protocol.org/latest/whats-new-v1/]
links: [proto-a2a-task-lifecycle, proto-a2ui-pointer]
---
# Message, Part et Artifact (spec 1.0)

Un **Message** est un tour de conversation (rôle `ROLE_USER` ou `ROLE_AGENT`). Un **Artifact** est un **produit** de la task, comme un document ou une donnée structurée. Les deux transportent des **Parts**.

## Message
Champs : `messageId`, `contextId`, `taskId`, `role`, `parts`, `metadata`, `extensions`, `referenceTaskIds`.

## Part : un type unique
Une Part contient **exactement un** des champs suivants :
- `text` (string) ;
- `raw` (bytes, encodés en base64 en JSON) ;
- `url` (lien vers un fichier) ;
- `data` (n'importe quel JSON structuré).

Champs optionnels, valables pour toutes les Parts : `mediaType` (ex-`mimeType`), `filename` et `metadata`.

```json
{"role":"ROLE_USER","messageId":"m1",
 "parts":[{"text":"Affiche le dossier 42"},
          {"data":{"dossierId":42},"mediaType":"application/json"}]}
```

## Artifact
Champs : `artifactId` (requis, unique dans la task), `name`, `description`, `parts` (au moins une), `metadata` et `extensions`.

## Pourquoi c'est utile ici
- Une Part `data` peut transporter du JSON A2UI : c'est la voie empruntée par `genui_a2a` (voir proto-a2ui-pointer).
- Les `extensions` permettent de déclarer ce type de contenu.

⚠️ **Pièges**
- En v0.3, on avait `TextPart`, `FilePart`, `DataPart` et `kind`. Ces noms n'existent plus en v1.0.
- Une Part ne doit pas avoir à la fois `text` et `data`.
