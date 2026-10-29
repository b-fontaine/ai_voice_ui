---
id: ma-filler-acknowledgements
title: Réponses de remplissage (« je regarde ») et accusés de réception
tags: [multi-agent, latency, realtime-voice, gpt-live, ux]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/live-delegation, https://developers.openai.com/api/docs/guides/live-prompting, https://openai.github.io/openai-agents-js/guides/voice-agents/build/]
links: [rt-gpt-live-delegation-latency, rt-gpt-live-delegation, rt-gemini-function-calling, ma-real-tool-results, rt-latency]
---
# Combler l'attente sans mentir

**GPT-Live :**
- Par défaut, le modèle peut prononcer un **accusé de réception automatique** pendant l'exécution d'un outil.
- Pour le supprimer :
  1. régler `delegation.acknowledgement_delay_ms` (exemple de la doc : 800) ;
  2. en délégation `client`, dès `session.delegation.created`, envoyer `session.thinking.append` avec un `content` vide.
- Tout append (thinking ou commentary) annule **tous** les accusés en attente de la session, même ceux des autres délégations.
- Progrès silencieux → `session.thinking.append`. Résultat vérifié à dire → `session.commentary.append`.
- Prompting : un bref accusé (« Got it », « sure ») suffit ; ne pas répéter le statut ni meubler l'attente. Éviter les accusés répétés et les « merci de patienter ».
- Dire « je vérifie » **ne confirme pas** que le travail backend a démarré : la délégation se demande via `<|SpawnThinking|>` (politique de délégation du prompt).

**OpenAI Agents SDK (API Realtime) :**
- Pendant un outil, l'agent ne traite pas de nouvelle demande.
- La doc suggère de faire annoncer l'appel ou de dire des phrases qui « achètent du temps ».
- `backgroundResult()` renvoie le résultat sans relancer de réponse.

**Gemini Live :** utiliser `NON_BLOCKING` plus `scheduling` ([[rt-gemini-function-calling]]).

## Règle interne (opinion)
- Le remplissage doit être **générique** (« je regarde ça »), jamais une hypothèse sur le résultat.
- Le résultat parlé ne vient que du vrai retour d'outil ([[ma-real-tool-results]]).
- Afficher en parallèle un indicateur visuel `DelegationProgress`.
