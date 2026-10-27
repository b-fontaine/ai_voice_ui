---
id: rt-gemini-ephemeral-tokens
title: Gemini Live — jetons éphémères
tags: [gemini, live-api, security, ephemeral-token, auth]
status: verified
updated: 2026-10-26
sources: [https://ai.google.dev/gemini-api/docs/ephemeral-tokens]
links: [rt-ephemeral-keys, rt-gemini-session-limits, rt-gemini-live-models]
---
# Jetons éphémères Gemini (API directe, hors Firebase)

Les jetons éphémères sont des jetons courts. Ils permettent au client de se connecter en WebSocket au Live API **sans clé API**. Ils ne fonctionnent **qu'avec le Live API**, en `v1beta`.

**Création côté backend :**
- REST `POST https://generativelanguage.googleapis.com/v1beta/auth_tokens`, ou SDK `client.auth_tokens.create` / `client.authTokens.create`.
- `uses` : par exemple 1. Le jeton reste réutilisable pour une reconnexion avec `sessionResumption`.
- `expireTime` : durée de validité des messages, **30 min** par défaut.
- `newSessionExpireTime` : délai pour ouvrir une session, **1 min** par défaut.
- `liveConnectConstraints` : verrouille le modèle et la config (modalités, reprise, instructions système). L'instruction système reste ainsi côté serveur.

**Utilisation côté client :**
- Avec le SDK JS : `new GoogleGenAI({ apiKey: token.name })`.
- Sans SDK : paramètre `access_token`, ou header `Authorization: Token <jeton>`.

**Pour Flutter** (opinion) :
- `firebase_ai` ne gère pas ces jetons (aucune classe d'auth token dans l'API Dart 5.1.0).
- Utiliser `gemini-3.8-live` en direct impose donc un client WebSocket Dart maison (protocole `BidiGenerateContent`), ou un relais serveur.
- Avec Firebase, la protection passe par **App Check**, obligatoire à partir du 2026-11-02.

## ⚠️ Pièges
- Un jeton n'est sûr que si le backend qui l'émet l'est : auth de l'utilisateur et quotas.
- Ne pas utiliser de jetons éphémères pour une connexion backend→Gemini : utiliser la clé.
