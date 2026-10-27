---
id: proto-mcp-extensions
title: MCP — extensions Tasks et MCP Apps
tags: [mcp, extensions, task, mcp-apps, ui]
status: verified
updated: 2026-10-26
sources: [https://modelcontextprotocol.io/specification/latest, https://modelcontextprotocol.io/specification/2026-07-28/changelog, https://modelcontextprotocol.io/extensions/apps/overview]
links: [proto-mcp-overview, proto-a2ui-pointer, proto-agui-overview]
---
# Extensions MCP officielles utiles pour nous

Les extensions sont **opt-in** et négociées via le champ `extensions` de `ClientCapabilities` et `ServerCapabilities`.

## Tasks (`io.modelcontextprotocol/tasks`)
- Gère les opérations longues : handle durable, polling via `tasks/get`, saisie en cours de route via `tasks/update`.
- `tasks/result` (bloquant) et `tasks/list` ont été supprimés lors du passage en extension.
- Le serveur peut renvoyer un handle de task sans opt-in préalable de la requête.
- Usage pour nous : une génération de document ou une recherche lente, sans bloquer l'agent vocal.

## MCP Apps (UI dans MCP)
- Un tool déclare `_meta.ui.resourceUri`, qui pointe vers une resource `ui://` : une **page HTML** rendue par le host dans une **iframe sandboxée**.
- La communication passe par postMessage, dans un dialecte JSON-RPC (`ui/initialize`, `tools/call`…).
- Hosts compatibles : Claude, VS Code Copilot, M365 Copilot, Goose, etc.

## MCP Apps et A2UI (opinion)
- **MCP Apps** livre du **HTML/JS exécutable**, isolé par la sandbox. Il suppose un host web ou webview.
- **A2UI** livre du **JSON déclaratif**, limité à un catalogue de widgets natifs. C'est le format adapté à Flutter natif, via genui (voir proto-a2ui-pointer).
- Pour l'app Flutter, on privilégie donc A2UI. MCP Apps n'aurait de sens qu'au travers d'une WebView, au prix de la cohérence visuelle et de la sécurité.

⚠️ **Pièges**
- Le support des extensions varie selon le client. Il faut vérifier ce qui a été négocié avant de les utiliser.
