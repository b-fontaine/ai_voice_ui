---
id: proto-mcp-deprecations
title: MCP — sampling, roots, logging et DCR dépréciés, ping et logging/setLevel supprimés
tags: [mcp, deprecation, sampling, roots, migration]
status: verified
updated: 2026-10-26
sources: [https://modelcontextprotocol.io/specification/2026-07-28/changelog]
links: [proto-mcp-overview, proto-mcp-dart-sdks]
---
# Ce qu'il ne faut plus adopter dans MCP (révision 2026-07-28)

La révision 2026-07-28 introduit une politique de cycle de vie des fonctionnalités (états Active, Deprecated, Removed) avec une fenêtre de dépréciation minimale de 12 mois. Les fonctions dépréciées marchent encore, mais **les nouvelles implémentations ne devraient pas les supporter**.

| Fonction dépréciée | Migration conseillée |
|---|---|
| **Sampling** (`sampling/createMessage`) | appeler directement l'API du fournisseur LLM |
| **Roots** | passer répertoires et fichiers en paramètres de tool, en URIs de resources ou en configuration |
| **Logging** (`notifications/message`) | écrire sur stderr en stdio, ou utiliser OpenTelemetry |
| Transport HTTP+SSE (2024-11-05) | Streamable HTTP |
| `includeContext: thisServer/allServers` | omettre le champ ou mettre `none` |
| OAuth DCR (RFC 7591) | Client ID Metadata Documents |

Ont aussi été **supprimés** (pas seulement dépréciés) : `ping`, `logging/setLevel` (le niveau se règle désormais par requête via `_meta` `io.modelcontextprotocol/logLevel`), `notifications/roots/list_changed`, `initialize`, les sessions, `Last-Event-ID` et le flux GET.

## Impact
- Les SDK Dart affichent encore « sampling/roots supported ». C'est vrai, mais il ne faut pas bâtir dessus (voir proto-mcp-dart-sdks).
- Pour un agent qui a besoin d'un LLM côté serveur, c'est l'orchestrateur qui détient la clé du fournisseur. On ne passe pas par le sampling du client.

⚠️ **Pièges**
- Les tutoriels de 2025 présentent le sampling comme la manière idiomatique de faire des « agents dans MCP ». Ce n'est plus vrai en 2026.
