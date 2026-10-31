---
id: pdr-0081-rail-in-replay-and-ignore-stray-speech
title: "PDR-0081 — Rail des agents en rejeu (état réel documenté) et bruit parasite ignoré par l'IA"
area: decisions
status: validated
updated: 2026-10-31
sources: [p-sources]
links: [p-rm-open-questions, p-rm-backlog, p-fn-screen, p-ar-frontend-screen, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0037-voice-brise-delegated-instructions, pdr-0077-011b-overlap-interrupt-delegation-link]
tags: [pdr, decision, rail, rejeu, voix, bruit-parasite, 016]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Benoît FONTAINE (porteur), conversation Claude Code"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0081 — Rail des agents en rejeu (état réel documenté) et bruit parasite ignoré par l'IA

> **En bref.** D1 (Q-88) : en rejeu, le rail garde les tuiles du dernier direct ; on documente cet état, sans changement de code. D2 (Q-89) : l'IA ne traite pas un bruit parasite ni une parole sans rapport avec la release ; elle ne répond pas. Le moyen technique est choisi par la boucle (016, étape Définir).

## Contexte
- Q-88 : [p-fn-screen](../functional/screen.md) et [p-ar-frontend-screen](../architecture/frontend-screen.md) disaient le rail vide en rejeu ; l'écran garde les tuiles terminées d'un direct (acceptation L-04).
- Q-89 : à la répétition du 2026-10-31, « Papa Papa » (voix dans la pièce) a reçu la réponse « Je suis là. Tu es en sécurité ? » ([répétition](../sources/2026-10-31-repetition-micro.md)).

## Options
- Q-88 : (1) documenter l'état réel (retenue) ; (2) vider le rail à l'entrée en rejeu.
- Q-89 : (1) garde-fou dans les instructions vocales ; (2) filtre côté orchestrateur ; (3) accepter le risque. Le porteur a répondu sur le comportement attendu, pas sur le moyen.

## Décision
Parole du porteur, 2026-10-31 (conversation Claude Code) : « Q-88 : 1
Q-89 : Elle ne doit pas la traiter. C'est un bruit parrasite »

- **D1 (Q-88)** : option 1. Le rail des agents garde les tuiles du dernier direct pendant le rejeu (acte 4) ; aucune liaison n'y est affichée. Aucun changement de code ; l'écart documentation/écran est retiré.
- **D2 (Q-89)** : l'IA ne traite pas un bruit parasite ni une parole sans rapport avec la release (cas observé : « Papa Papa ») ; elle ne répond pas. Exigence pour 016, sujet (a). Le moyen (consigne vocale, filtrage côté orchestrateur ou autre) n'est pas décidé ici : la boucle le choisit à l'étape Définir.

## Raisons
Réponse du porteur citée ci-dessus. Pour D1, la reco de l'assistant était l'option 1.

## Conséquences
- Q-88 et Q-89 tranchées. [p-fn-screen](../functional/screen.md), [p-ar-frontend-screen](../architecture/frontend-screen.md) et le scénario L-04 décrivent l'état réel.
- 016 (a) ([backlog](../roadmap/backlog.md)) reprend D2 comme exigence ; critère à définir par la boucle : ne pas dégrader l'accusé de NFR-02 ni les demandes valides.
- ⚠️ La frontière entre « bruit » et « demande hors sujet adressée à l'IA » n'est pas précisée par le porteur : à cadrer par la boucle à l'étape Définir et à faire valider si elle comporte un arbitrage de produit.

## Réexaminer si
La répétition montre que des demandes valides sont ignorées, ou que le rail rejoué prête à confusion devant le public.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée sur la parole du porteur citée ci-dessus (conversation Claude Code) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
