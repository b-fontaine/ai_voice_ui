---
id: proto-mcp-primitives
title: MCP — tools, resources, prompts (qui contrôle quoi)
tags: [mcp, tools, resources, prompts]
status: verified
updated: 2026-10-28
sources: [https://modelcontextprotocol.io/specification/2026-07-28/server, https://modelcontextprotocol.io/specification/2026-07-28/changelog]
links: [proto-mcp-overview, proto-mcp-elicitation]
---
# Les trois primitives serveur MCP

Chaque primitive a un **maître** différent. Le choix de primitive détermine donc qui décide de l'invoquer.

| Primitive | Contrôlée par | Exemple | Méthodes |
|---|---|---|---|
| **Prompts** | l'utilisateur | commande slash, menu | `prompts/list`, `prompts/get` |
| **Resources** | l'application | contenu de fichier, historique | `resources/list`, `resources/read`, `resources/templates/list` |
| **Tools** | le modèle | appel d'API, écriture | `tools/list`, `tools/call` |

## Détails 2026-07-28
- `inputSchema` et `outputSchema` acceptent tout JSON Schema 2020-12. `structuredContent` accepte n'importe quelle valeur JSON.
- Les réponses de liste et `resources/read` portent `ttlMs` et `cacheScope` (`public` ou `private`) : c'est un cache côté client.
- `tools/list` **devrait** être renvoyé dans un ordre déterministe, ce qui aide le cache de prompt du LLM.
- Une resource introuvable renvoie maintenant l'erreur `-32602`, au lieu de `-32002`.

## Application à une architecture voix + GenUI + orchestrateur (opinion)
- Les **outils métier** (chez Septeo par exemple : lire un dossier, créer un RDV…) sont des tools MCP. L'orchestrateur les expose ensuite aux agents vocal et GenUI.
- Pour l'agent vocal temps réel, on traduit les tools MCP en déclarations de fonctions du modèle Live (OpenAI ou Gemini). Le modèle n'appelle pas MCP directement.

⚠️ **Pièges**
- La spec impose de traiter les descriptions et annotations de tools comme **non fiables**, sauf si le serveur est de confiance.
- La spec exige aussi un consentement utilisateur avant toute invocation de tool. En vocal, il faut prévoir une confirmation orale ou visuelle pour les actions à effet de bord.
