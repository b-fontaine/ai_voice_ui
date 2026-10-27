---
id: ma-mcp-security
title: Sécurité MCP pour l'orchestrateur
tags: [multi-agent, security, mcp, oauth]
status: verified
updated: 2026-10-26
sources: [https://modelcontextprotocol.io/specification/latest/basic/security_best_practices]
links: [ma-prompt-injection-tools, rt-ephemeral-keys, ma-where-to-run-agents, ma-otel-genai-spans, proto-mcp-authorization, proto-mcp-overview]
---
# Points MCP qui concernent un orchestrateur backend

Source : *Security Best Practices* de la spec MCP (`latest`, qui référence la révision `2026-07-28`).

- **Token passthrough interdit.** Un serveur MCP **MUST NOT** accepter un token qui n'a pas été émis pour lui. Vérifier l'audience.
- **Confused deputy.** Pour un proxy MCP vers une API tierce avec client ID statique : consentement par client obligatoire, `redirect_uri` en correspondance exacte, `state` à usage unique.
- **SSRF.** Un client MCP côté serveur **MUST** prendre en compte le SSRF et **SHOULD** :
  - exiger HTTPS ;
  - bloquer les plages privées et link-local (`169.254.0.0/16`, les métadonnées cloud) ;
  - revalider chaque redirection ;
  - de préférence, passer par un proxy de sortie (egress).
- **Handles d'état.** MCP est désormais *stateless*. Un handle (panier, workflow) n'est **pas** une authentification. Le lier côté serveur à `<user_id>:<handle>`, avec un `user_id` issu du token vérifié.
- **Minimisation des scopes.** Partir d'un scope minimal, élever au besoin (`WWW-Authenticate scope=…`), sans scopes `*`.
- **Serveurs locaux.** Consentement, commande affichée en entier, sandbox. Hors de notre périmètre mobile/web.

**Pour nous (opinion) :**
- Les clients MCP vivent dans l'orchestrateur, avec une liste blanche de serveurs et un token par utilisateur et par serveur.
- Chaque appel est journalisé (span `execute_tool`, voir [[ma-otel-genai-spans]]).

Versions Dart observées le 2026-10-26 : `mcp_dart` 2.4.3, `dart_mcp` 0.5.2. Utile seulement si une partie de l'orchestrateur est en Dart.
