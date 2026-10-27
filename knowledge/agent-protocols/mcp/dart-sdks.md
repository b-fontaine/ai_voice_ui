---
id: proto-mcp-dart-sdks
title: MCP en Dart/Flutter — mcp_dart vs dart_mcp
tags: [mcp, dart, flutter, sdk, pub.dev]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/mcp_dart, https://pub.dev/packages/dart_mcp]
links: [proto-mcp-transports, proto-mcp-deprecations, proto-stack-recommendation]
---
# Deux SDK MCP Dart aux maturités très différentes

Versions observées sur pub.dev le 2026-10-26.

| | `mcp_dart` 2.4.3 | `dart_mcp` 0.5.2 |
|---|---|---|
| Éditeur | leehack.com (vérifié, communautaire) | labs.dart.dev (équipe Dart) |
| Statut | actif (dernière version il y a environ 12 jours) | **expérimental**, « likely to evolve quickly » |
| Spec | **2026-07-28** (cœur), plus repli sur 2025-11-25 et versions antérieures | jusqu'à la série 2025-11, rien en 2026-07-28 |
| Transports | stdio, **Streamable HTTP**, IO stream, custom | stdio uniquement, **pas de Streamable HTTP** |
| Elicitation / sampling | oui / oui | sampling et roots oui, elicitation non mentionnée |
| OAuth | découverte et hooks PKCE côté client, callbacks côté serveur | non supporté |
| Extensions | Tasks (expérimental), métadonnées MCP Apps | — |

## Plateformes avec `mcp_dart`
- **Flutter web** : client Streamable HTTP uniquement.
- **Mobile** : client distant en Streamable HTTP.
- **Desktop** : client et serveur, en stdio et en HTTP.

## Choix (opinion)
- Pour une **app Flutter cliente** d'un serveur MCP distant, prendre `mcp_dart`.
- `dart_mcp` est adapté à l'outillage Dart (serveur MCP local en stdio, par exemple pour un IDE). Il ne convient pas à une app.
- Alternative : laisser l'app ignorer MCP. C'est alors l'orchestrateur backend qui consomme MCP, et l'app ne parle qu'à l'orchestrateur.

⚠️ **Pièges**
- La page pub.dev de `dart_mcp` liste « 2025-11-05 » comme version, probablement une coquille pour 2025-11-25. À vérifier.
- `mcp_dart` revendique la conformité aux 25 scénarios d'autorisation 2026. C'est une auto-déclaration à valider par nos tests.
