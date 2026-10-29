---
id: rt-latency
title: Latence perçue — leviers
tags: [pattern, latency, performance, ux]
status: opinion
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/voice-latency-cost?api=live, https://developers.openai.com/api/docs/guides/realtime-webrtc-warp, https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/WebRTC/initialize.html, https://developers.openai.com/api/docs/guides/live-delegation.md, https://ai.google.dev/gemini-api/docs/live-guide]
links: [rt-gpt-live-delegation-latency, rt-tool-calling-voice, rt-gemini-audio-vad, rt-gpt-live-delegation, ma-filler-acknowledgements, perf-audio-latency, rt-gemini-function-calling]
---
# Réduire la latence perçue d'un agent vocal

Recommandations internes, appuyées sur les docs citées.

1. **Transport :** WebRTC (UDP, jitter buffer, AEC) plutôt que WebSocket pour l'audio client. OpenAI le recommande même entre serveurs.
2. **Pré-chauffer :**
   - demander la permission micro et initialiser `WebRTC.initialize` / la session audio avant le clic « parler » ;
   - attention : chez OpenAI, la création de session WebRTC facture 15 s d'avance (créditées ensuite) ;
   - poignée de main : WARP (`WebRTC.initialize(options: {'enableWARP': true})` côté flutter_webrtc, guide OpenAI « WebRTC with WARP », valable pour GPT-Live et Realtime) — non testé avec flutter_webrtc.
3. **Fin de tour :**
   - Gemini : `silenceDurationMs` entre 500 et 800 ms ;
   - Realtime : `semantic_vad` ;
   - trop court, on fragmente ; trop long, l'IA semble lente.
4. **Outils lents :**
   - ne jamais bloquer la voix ;
   - GPT-Live : `acknowledgement_delay_ms` (accusé vocal automatique) et `session.commentary.append` pour la progression ;
   - Gemini 3.8 : `NON_BLOCKING` avec `scheduling` ([[rt-tool-calling-voice]]).
5. **UI optimiste :** l'agent GenUI peut afficher un squelette dès l'appel d'outil, sans attendre la phrase de l'IA.
6. **Lecture PCM (Gemini) :** les buffers de lecture doivent être petits (de l'ordre de la centaine de ms) mais stables. Vider le buffer à l'interruption.
7. **Région :** la latence réseau vers le fournisseur domine. Sur l'Agent Platform, choisir une région proche ; les modèles Live 2.5 n'existent pas en `global`.

## ⚠️ Pièges
- Mesurer de bout en bout, de la fin de parole utilisateur au premier son de l'IA. Ne pas se contenter du temps de connexion.
