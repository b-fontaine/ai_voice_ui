---
id: genui-a2ui-overview
title: A2UI — protocole Agent-to-UI (statut oct. 2026)
tags: [a2ui, protocol, google, versions]
status: verified
updated: 2026-10-26
sources: [https://a2ui.org/, https://github.com/google/A2UI]
links: [genui-a2ui-messages, genui-a2ui-client-messages, genui-a2ui-security, genui-a2ui-v1-rc, genui-a2ui-transports, genui-overview, proto-a2ui-pointer, proto-protocol-map]
---
# A2UI : l'agent envoie une description JSON déclarative, le client la rend avec ses propres widgets

A2UI (Agent-to-User Interface) est un standard ouvert créé par Google, sous licence Apache 2.0 (`github.com/google/A2UI`), avec des contributions de CopilotKit et de la communauté. L'agent décrit l'**intention** d'UI ; chaque client la rend nativement (Flutter via genui, Lit, Angular, etc.). Devise du README : « safe like data, but expressive like code ».

## Statut (README, consulté le 2026-10-26)
- Production : **v0.9.1** (patch de la famille stable v0.9).
- **v1.0** : release candidate.
- v0.8 : legacy.
- Le projet se décrit lui-même comme « Early stage public preview ».

## Principes
- **Liste plate de composants** reliés par id (liste d'adjacence) : simple à générer pour un LLM, et propice au rendu progressif.
- **Séparation structure / données :** `updateComponents` décrit l'arbre, `updateDataModel` les valeurs.
- **Agnostique du transport :** A2A, AG-UI, MCP, SSE, WebSocket, REST.
- **Catalogue côté client :** l'agent ne peut demander que des composants approuvés.

## Cas d'usage cités
Formulaires dynamiques, sous-agents distants qui renvoient de l'UI dans le chat d'un orchestrateur, tableaux de bord adaptatifs.

⚠️ Pièges
- genui 0.10.x parle **v0.9**. La spec dit que v0.9.1 est compatible au niveau payload (les schémas acceptent `"v0.9"` et `"v0.9.1"`), mais le parseur `a2ui_core` 0.1.0 utilisé par genui **rejette tout `version` différent de `"v0.9"`**. Or les exemples de la spec v0.9.1 utilisent `"v0.9.1"` : forcer `"v0.9"` côté agent.
- A2UI ne remplace pas A2A ni MCP : c'est le format de la charge utile UI qu'ils transportent.
