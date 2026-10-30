---
id: rt-openai-tts-test-audio
title: Audio de test pour un essai vocal réel — TTS OpenAI en Ogg/Opus
tags: [openai, tts, testing, gpt-live, webrtc, cost]
status: sourced
updated: 2026-10-30
sources: [https://developers.openai.com/api/docs/guides/text-to-speech, essai réel du 2026-10-30]
links: [rt-gpt-live-webrtc-session, rt-gpt-live-delegation-latency, rt-gpt-live-overview, test-realtime-fake-runner]
---
# Générer la question d'un essai vocal réel avec le TTS

Pour tester une session GPT-Live sans micro ni présence humaine, générer la question avec l'API TTS : `gpt-4o-mini-tts`, `response_format: "opus"`. La réponse est un **Ogg/Opus** que le client de contrôle (Go, pion) a lu **tel quel**, sans ffmpeg ni conversion (essai réel du 2026-10-30, voix `alloy`).

```text
POST /v1/audio/speech
{"model":"gpt-4o-mini-tts","voice":"alloy","input":"Bonjour. Prépare la release trois point quatre.","response_format":"opus"}
```

- Écrire les nombres en toutes lettres (« trois point quatre ») : le modèle vocal les a transcrits correctement (« Bonjour, prépare la release 3.4 »). Si une prononciation est mauvaise, réécrire la phrase en chiffres.
- **Coût** : environ 0,01 € pour une phrase courte ; l'API TTS ne renvoie pas d'usage, donc estimer par prudence. La session GPT-Live se facture 0,05 $/min ([[rt-gpt-live-overview]]) : un essai de 45 s revient à ~0,04 €.
- Le fichier est joué sur la piste audio WebRTC après l'ouverture du data channel ; le client de contrôle attend 2 s avant de le jouer (réglage du client, pas du fournisseur ; session et relais SDP : [[rt-gpt-live-webrtc-session]]).

## ⚠️ Pièges
- La clé ne doit jamais passer en argument de ligne de commande ni dans un journal : la lire dans l'environnement d'un sous-shell et chercher sa valeur dans les sorties avant de conclure.
- Un essai réel est payant et non déterministe : en faire un par fonctionnalité, pas un par tentative ; le reste se teste avec un faux fournisseur ([[test-realtime-fake-runner]]).
- Un 401 sans coût arrive si la variable d'environnement n'est pas chargée dans le sous-shell qui lance l'appel.
