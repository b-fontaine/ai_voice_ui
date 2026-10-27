---
id: rt-openai-webrtc-package
title: Package openai_webrtc (communautaire)
tags: [openai, flutter, packages, webrtc, realtime-api]
status: sourced
updated: 2026-10-26
sources: [https://pub.dev/packages/openai_webrtc]
links: [rt-openai-realtime-vs-live, rt-flutter-webrtc-gpt-live-connect]
---
# `openai_webrtc` : référence, pas dépendance

`openai_webrtc` est un package Flutter **communautaire** (v0.5.0, MIT © TIMU LLC, éditeur pub.dev meshagent.com, publié le 2025-09-28).

**Ce qu'il fait :**
- Il encapsule `flutter_webrtc ^0.14.1` et `openai_core ^0.7.0`.
- Il cible l'**API Realtime**, pas GPT-Live.
- Il crée la PeerConnection, le data channel `oai-events` et la piste micro, puis joue l'audio distant.
- Le code appelle `createCall` d'`openai_core` (unified interface) avec la clé passée au client ; l'audio distant passe par un `RTCVideoRenderer` hors écran.
- En production, le README recommande un endpoint serveur qui renvoie un client secret éphémère.

**Pourquoi ne pas en dépendre** (opinion) :
- Il est antérieur à `gpt-live-1` et incompatible avec `/v1/live/sessions`.
- Il épingle `flutter_webrtc` 0.14.x, alors que la version actuelle est 1.6.3.
- Son exemple serveur (README) cible l'API bêta : `POST /v1/realtime/sessions`, `gpt-4o-realtime-preview`, `client_secret.value`. En GA : `POST /v1/realtime/client_secrets`, champ `value` au premier niveau.

**Ce qu'on en garde :** l'ordre des opérations WebRTC, utile comme lecture. On implémentera notre propre runner sur `flutter_webrtc` ([[rt-flutter-webrtc-gpt-live-connect]]).
