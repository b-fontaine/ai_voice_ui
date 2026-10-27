---
id: proto-mcp-authorization
title: MCP — autorisation OAuth 2.1 (transports HTTP)
tags: [mcp, oauth, auth, security, pkce]
status: verified
updated: 2026-10-26
sources: [https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization, https://modelcontextprotocol.io/specification/2026-07-28/changelog]
links: [proto-mcp-transports, proto-a2a-security, proto-mcp-elicitation, ma-mcp-security]
---
# Autorisation MCP : OAuth 2.1, le serveur MCP comme resource server

L'autorisation est **optionnelle**. Quand elle est présente, elle s'applique aux transports HTTP. En stdio, le serveur **ne devrait pas** suivre ce flux : il lit ses identifiants dans l'environnement.

## Exigences clés (2026-07-28)
- Le serveur MCP est un **resource server OAuth 2.1**. Il **doit** implémenter les *Protected Resource Metadata* (RFC 9728), annoncées via `resource_metadata` dans l'en-tête `WWW-Authenticate` d'une réponse 401.
- Le client découvre l'Authorization Server via RFC 8414 **ou** OIDC Discovery, et doit supporter les deux.
- Enregistrement du client, par ordre de préférence :
  1. **Client ID Metadata Documents** (le client_id est une URL HTTPS) ;
  2. pré-enregistrement ;
  3. DCR (RFC 7591), **dépréciée** dans cette révision.
- **PKCE** obligatoire, et paramètre `resource` (RFC 8707) obligatoire dans les requêtes authorize et token.
- Le serveur **doit** valider que l'audience du token est bien lui.
- Le client **doit** valider un `iss` présent dans la réponse d'autorisation (RFC 9207) contre l'issuer enregistré, avant d'échanger le code. L'AS **devrait** l'inclure.
- Le token passe dans `Authorization: Bearer` à **chaque** requête, jamais dans la query string.
- Une réponse 403 `insufficient_scope` déclenche un flux de **step-up** : redemander l'union des scopes déjà obtenus et des nouveaux.

## Pour Flutter (opinion)
- Utiliser un flux Authorization Code + PKCE dans un navigateur système, avec stockage sécurisé des tokens (keychain ou keystore).
- La doc de `mcp_dart` précise que son stockage d'exemple est en clair et n'est pas fait pour la production.

⚠️ **Pièges**
- **Token passthrough interdit** : un serveur MCP ne doit pas réutiliser le token client pour appeler une API tierce. Il passe plutôt par une elicitation en mode URL (voir proto-mcp-elicitation).
