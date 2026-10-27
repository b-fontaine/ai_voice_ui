---
id: rt-gemini-session-limits
title: Gemini Live — durée, reprise de session, compression
tags: [gemini, live-api, session-resumption, context-compression, goaway]
status: verified
updated: 2026-10-26
sources: [https://ai.google.dev/gemini-api/docs/live-session]
links: [rt-gemini-firebase-ai-dart, rt-gemini-ephemeral-tokens, rt-graceful-close]
---
# Gemini Live : limites de session et reprise

Sans compression, une session est limitée à **15 min en audio seul** et **2 min en audio + vidéo**. Une **connexion** WebSocket dure **environ 10 min**. Une session longue exige donc deux mécanismes : la compression et la reprise de session.

**Compression de contexte**
- Champ `contextWindowCompression: { slidingWindow: {} }`, avec un seuil `trigger_tokens`.
- Elle permet des sessions de durée illimitée.

**Reprise de session**
- Champ `sessionResumption` (`SessionResumptionConfig`) dans le setup.
- Le serveur envoie des `SessionResumptionUpdate` : garder le dernier handle.
- À la reconnexion, passer ce handle dans `SessionResumptionConfig.handle`.
- Le handle reste valable **2 h** après la fin de la session.

**GoAway**
- Le message `GoAway` (`GoingAwayNotice` en Dart) contient `timeLeft`.
- Il annonce la coupure de la connexion, qui se termine en statut ABORTED.
- C'est le signal pour se reconnecter avec le handle.

**Fin de génération**
- `generationComplete` signale que le modèle a fini de générer.
- Ce champ n'est pas exposé dans `LiveServerContent` en Dart 5.1.0.

En Dart : `model.connect(sessionResumption: …)` ou `session.resumeSession(sessionResumption: …)`.

## ⚠️ Pièges
- La reconnexion doit être transparente pour l'UI : ne pas remettre l'état BLoC à zéro et garder le transcript.
- L'audio capté pendant la reconnexion est perdu, sauf s'il est mis en tampon (opinion).
