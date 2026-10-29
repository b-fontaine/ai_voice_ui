---
id: pdr-0051-orb-level-from-sideband-rms-recommended
title: "PDR-0051 — Niveau audio de l'orbe : RMS de la copie sideband poussé par le backend (proposition)"
area: decisions
status: proposed
updated: 2026-10-29
sources: [specs/002-sp-02-gpt-live-sdp-relay/notes-s1.md, knowledge:rt-gpt-live-sideband, knowledge:rt-barge-in, AGENTS.md#voix]
links: [p-rm-open-questions, p-rm-spikes, p-ar-frontend, p-ar-backend, p-ar-agents-protocols, pdr-0045-app-backend-channel-wss-recommended, rt-gpt-live-sideband, rt-barge-in, rt-gpt-live-webrtc-session]
tags: [pdr, decision, orbe, audio, sideband]
decision_status: proposée
decided_on: 2026-10-29
decided_by: "À décider par Benoît FONTAINE (porteur) ; proposition de l'assistant issue du spike SP-02"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0051 — Niveau audio de l'orbe : RMS de la copie sideband

> **En bref.** **Proposée, non acquise** : tranche Q-43 si le porteur l'accepte. Le backend calcule le RMS de la copie sideband de l'audio de sortie et le pousse à 5 Hz sur l'app-channel ; l'orbe interpole à 60 i/s côté client. Une seule capture micro est conservée (AGENTS.md § 2).

Part de l'assistant : recommandation seule ; Q-43 reste ouverte.

## Contexte
- Q-43 : d'où vient le niveau audio de l'orbe sans seconde capture micro ? ([p-ar-frontend](../architecture/frontend.md)).
- Mesuré en SP-02 (2026-10-29) : la copie sideband de l'audio de sortie (PCM16 24 kHz, blocs de 200 ms, continue, temps réel à ±150 ms) donne un RMS exploitable : 0 au silence, 0,05 à 0,17 en parole ([rt-gpt-live-sideband]). Indice côté piste WebRTC : taille des paquets Opus (72 octets au silence, ≥ 105 en parole).
- Le niveau côté client par statistiques WebRTC (`audioLevel`) **n'a pas été testé**.
- Le canal app ↔ backend est un WSS maison ([pdr-0045](pdr-0045-app-backend-channel-wss-recommended.md)).

## Hypothèses
- ✅ Le RMS sideband distingue silence et parole (SP-02).
- ⚠️ Hypothèse non confirmée : 5 Hz interpolés à 60 i/s suffisent visuellement pour l'orbe → à valider avec le porteur sur l'orbe réelle (Q-43).
- ⚠️ Hypothèse non confirmée : `audioLevel` des statistiques WebRTC serait une alternative viable (non testée) → Q-43.

## Options
1. **RMS sideband côté backend, poussé à 5 Hz** (recommandée).
2. `audioLevel` des statistiques WebRTC côté client (non testée).
3. Seconde capture micro : exclue d'emblée par AGENTS.md § 2 (une seule source de capture).

## Décision
**Proposition (non acquise)** : le backend calcule le RMS par bloc de 200 ms de la copie sideband de sortie et le publie à 5 Hz sur l'app-channel ; l'orbe interpole à 60 i/s.

## Raisons
- Mesuré et exploitable ; aucune seconde capture ; la logique reste au backend, testable sans Flutter.
- Le niveau suit l'audio réellement émis par le modèle (±150 ms).

## Options écartées
- `audioLevel` WebRTC : non testée ; reste l'alternative si 5 Hz s'avère insuffisant ou si le décalage gêne.

## Conséquences
- [p-ar-backend](../architecture/backend.md) : le `sideband-supervisor` calcule et publie le niveau ; message d'état d'orbe sur l'app-channel ([p-ar-agents-protocols](../architecture/agents-protocols.md)).
- [p-ar-frontend](../architecture/frontend.md) : l'orbe interpole le niveau reçu.
- J2 dépend de la décision (Q-43, avant le 31/10).

## Réexaminer si
- le rendu à 5 Hz interpolés paraît saccadé au porteur ;
- le décalage de ±150 ms est visible face à la parole ;
- `audioLevel` testé donne un niveau plus fidèle à moindre coût.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Proposée, après SP-02 (aucune parole du porteur) | Assistant |

Pas d'archive brute.
