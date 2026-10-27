---
id: proto-a2a-security
title: A2A — authentification et schémas de sécurité
tags: [a2a, auth, oauth2, oidc, mtls, security]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/specification/, https://a2a-protocol.org/latest/whats-new-v1/]
links: [proto-a2a-agent-card, proto-mcp-authorization, rt-ephemeral-keys]
---
# Sécurité A2A : déclarée dans la carte, appliquée par le serveur

A2A ne réinvente pas l'authentification. L'Agent Card déclare des `securitySchemes` dans le style d'OpenAPI, et le serveur **doit rejeter** les identifiants absents ou invalides.

## Schémas (§4.5, spec 1.0)
- `APIKeySecurityScheme`
- `HTTPAuthSecurityScheme` (Bearer, Basic…)
- `OAuth2SecurityScheme`, avec les flows `AuthorizationCodeOAuthFlow`, `ClientCredentialsOAuthFlow` et `DeviceCodeOAuthFlow`
- `OpenIdConnectSecurityScheme`
- `MutualTlsSecurityScheme`

La v1.0 a **retiré** les flows OAuth implicit et password.

## Autres mécanismes
- L'état `TASK_STATE_AUTH_REQUIRED` permet de demander une authentification en cours de task.
- La carte étendue (`GetExtendedAgentCard`) exige l'authentification déclarée.
- Une Agent Card signée (JWS) prouve l'origine de la carte.
- Les push notifications portent leurs propres identifiants via `AuthenticationInfo` (voir proto-a2a-streaming-push).

## Recommandation (opinion)
- **App vers orchestrateur** : OAuth2 Authorization Code + PKCE (identité utilisateur).
- **Orchestrateur vers agents distants** : client credentials ou mTLS (identité de service).
- Ne jamais embarquer de clé d'agent tiers dans l'app Flutter. C'est le même principe que pour les clés OpenAI (voir proj-avw-risks).

⚠️ **Pièges**
- Le SDK Dart communautaire `a2a` **ne gère pas** l'authentification, hormis HTTPS (voir proto-a2a-dart-sdk).
