---
id: proto-a2a-agent-card
title: A2A — Agent Card et découverte
tags: [a2a, agent-card, discovery, well-known]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/specification/, https://a2a-protocol.org/latest/whats-new-v1/]
links: [proto-a2a-overview, proto-a2a-security, proto-a2a-bindings]
---
# Agent Card : la carte de visite d'un agent A2A

Un serveur A2A publie son Agent Card en JSON à l'URL `https://{domaine}/.well-known/agent-card.json`. La carte décrit l'identité de l'agent, ses skills, ses interfaces (endpoints et bindings), ses capacités et ses exigences d'authentification.

## Champs notables (spec 1.0)
- `supportedInterfaces[]` (requis, ordonné, la 1re entrée est préférée) : une entrée `AgentInterface` par binding, avec `url`, `protocolBinding` (`JSONRPC`, `GRPC`, `HTTP+JSON`) et `protocolVersion`. Ce champ remplace `url`, `preferredTransport` et `additionalInterfaces` de la v0.3.
- `capabilities` :
  - `streaming` : SSE supporté ;
  - `pushNotifications` : webhooks supportés ;
  - `extendedAgentCard` : une carte enrichie est accessible après authentification (ex-`supportsAuthenticatedExtendedCard` de la v0.3).
- `securitySchemes` et `securityRequirements` : schémas inspirés d'OpenAPI (voir proto-a2a-security).
- `skills` : capacités métier annoncées, que l'orchestrateur utilise pour router les tâches.
- `signatures` (optionnel) : signature JWS (RFC 7515) calculée sur la forme canonique JCS (RFC 8785), champ `signatures` exclu.

## Carte étendue
- Méthode `GetExtendedAgentCard`, ou `GET /extendedAgentCard` en REST.
- Elle exige les schémas d'authentification déclarés dans la carte publique.

## Usage dans notre app
L'orchestrateur lit les cartes des agents distants pour choisir à qui déléguer, par exemple un agent métier côté serveur Septeo. Côté Flutter, `genui_a2a` expose une classe `AgentCard` (voir proto-a2a-dart-sdk).

⚠️ **Pièges**
- En v0.3, les champs différaient (`url` + `preferredTransport` + `additionalInterfaces`). Il faut vérifier le `protocolVersion` annoncé par chaque interface.
- La carte publique ne doit contenir aucun secret. Les détails sensibles vont dans la carte étendue.
