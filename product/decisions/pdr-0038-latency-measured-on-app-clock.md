---
id: pdr-0038-latency-measured-on-app-clock
title: "PDR-0038 — Les latences des NFR se mesurent sur l'horloge de l'app"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p6, knowledge:rt-transcription]
links: [p-ar-quality, p-ar-replay, p-fn-nfr, p-rm-open-questions, rt-transcription]
tags: [pdr, decision, latence, mesure, horloge]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0038 — Mesure sur l'horloge de l'app

> **En bref.** Les chronos de NFR-01, NFR-02 et NFR-03 partent et s'arrêtent sur l'**horloge monotone de l'app**. Il n'y a pas d'alignement d'horloges client / serveur. Tranche Q-54.

Part de l'assistant : consignation.

## Contexte
- Q-54 : point de départ des chronos (fin de phrase vue par GPT-Live ou par l'app) et alignement des horloges ([p-ar-quality](../architecture/quality.md), [rt-transcription]).

## Hypothèses
- Aucune.

## Options
1. **Horloge de l'app** (retenue)
2. Horloge du backend + correction

## Décision
- Tous les horodatages de mesure (`t_ms` du journal, marqueur de fin de phrase, premier `createSurface` rendu, dernier `updateDataModel`) sont pris par l'app, sur une horloge monotone.
- La fin de phrase est l'instant où l'app reçoit l'événement de fin de tour du speaker.

## Raisons
- Parole du porteur (2026-10-29), Q-54 : « horloge de l'app ».

## Options écartées
- **Horloge du backend** : demande un alignement, inutile en local.

## Conséquences
- [p-ar-quality](../architecture/quality.md), [p-ar-replay](../architecture/replay.md) : instrumentation sur l'horloge de l'app.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-54 tranchée.

## Réexaminer si
- Les mesures doivent décomposer la latence par saut côté backend (SP-04) : spans serveur en complément, sans changer la référence.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « horloge de l'app » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
