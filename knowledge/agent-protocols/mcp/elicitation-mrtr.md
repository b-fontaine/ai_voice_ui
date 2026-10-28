---
id: proto-mcp-elicitation
title: MCP — elicitation et Multi Round-Trip Requests
tags: [mcp, elicitation, mrtr, ux, human-in-the-loop]
status: verified
updated: 2026-10-28
sources: [https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation, https://modelcontextprotocol.io/specification/2026-07-28/changelog]
links: [proto-mcp-primitives, proto-mcp-authorization, proto-a2a-task-lifecycle]
---
# Elicitation : le serveur demande une info à l'utilisateur

Depuis la révision 2026-07-28, un serveur qui a besoin d'une saisie utilisateur **ne fait plus de requête** vers le client. Il renvoie un `InputRequiredResult` dont `inputRequests` contient un `elicitation/create`. Le client rejoue ensuite l'appel d'origine avec `inputResponses` (pattern MRTR).

## Deux modes
- **form** : schéma plat de primitives uniquement (string avec format email/uri/date/date-time, number/integer, boolean, enum simple ou multiple).
  - **Interdit** pour les secrets : mots de passe, clés, tokens, paiement.
- **url** : le client ouvre une URL hors bande, après consentement et en affichant l'URL complète. Les données saisies ne transitent pas par le client.
  - Ce mode sert aux flux OAuth tiers et au paiement.
  - Sur iOS, utiliser `SFSafariViewController` et non `WKWebView`.

Les réponses possibles sont `accept` (avec `content` en mode form), `decline` ou `cancel`.

```json
{"method":"elicitation/create","params":{"mode":"form",
 "message":"Quel dossier ?","requestedSchema":{"type":"object",
 "properties":{"ref":{"type":"string"}},"required":["ref"]}}}
```

## Lien avec une app voix + GenUI (opinion)
- Une elicitation de type form se rend bien comme **surface GenUI**, ou comme question posée par l'**agent vocal**.
- Analogie : c'est l'équivalent MCP de `TASK_STATE_INPUT_REQUIRED` côté A2A.

⚠️ **Pièges**
- `notifications/elicitation/complete` et `elicitationId` ont été **supprimés** en 2026-07-28. Pour corréler, on utilise `requestState`.
- Le serveur doit vérifier que l'utilisateur qui ouvre l'URL est bien celui qui a déclenché l'elicitation, sinon il s'expose à du phishing.
