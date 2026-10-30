---
id: pdr-0071-act2-focus-memory-act-indicator-click-feedback
title: "PDR-0071 — Acte 2 : mémoire de focus, indicateur d'acte automatique, retour au clic"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-rm-open-questions, p-rm-roadmap, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0063-007-stage-ui-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0054-stage-screen-orb-acts-checklist, pdr-0024-act2-android-only]
tags: [pdr, decision, acte-2, indicateur, clic]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire après l'essai au micro)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0071 — Acte 2 : mémoire de focus, indicateur d'acte automatique, retour au clic

> **En bref.** Mémoire de focus par canevas transmise aux agents (une comparaison sans plateforme hérite de la plateforme affichée) ; indicateur d'acte automatique (acte 2 à l'apparition de la barre d'actions, acte 3 au clic, clic manuel pour corriger) ; au clic sur « Bloquer », la voix confirme après sa phrase en cours mais l'écran change aussitôt et nettement. Tranche Q-74 et Q-75.

Part de l'assistant : recommandation, mise en forme et consignation de la parole du porteur.

## Contexte
Essai : la demande « compare avec la 3.3 » arrive dans un second tour sans plateforme et est refusée (hors périmètre) ; l'indicateur reste « Acte 1/3 » ; le clic n'a d'effet visible qu'après le discours de l'IA. Q-74 (demande coupée en deux) est observée ; Q-75 : la voix parle hors délégation, après la phrase en cours (observé).

Observations du porteur (conversation du 2026-10-30) : « Je n'ai pas vu la comparaison dans l'essai que tu m'as demandé ; Le composant Crashlist n'est jamais apparu, même après l'avoir demandé explicitement ; Lui dire stop ou essayer de lui couper la parole ne fonctionne pas ; Quand je dis stop, rien ne se passe ; Quand je m'interrompts, elle compte ça comme une fin de phrase ; par contre, elle ne repère que ma voix, les bruits autour n'ont pas d'impact ; C'est toujours écrit Acte 1/3 en haut à droite, même après avoir bloqué la release ; Cliquer sur "Bloquer la release" n'a eu un effet qu'après le discours de l'IA ».

Diagnostic complet (contre-vérifié sur les journaux des sessions) : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).

## Options
1. **Valider toutes les recommandations** (retenue).
2. Les arbitrer une à une.

## Décision
Question posée : « Valides-tu les autres recommandations ? (mémoire du contexte à l'acte 2 ; indicateur d'acte automatique : acte 2 quand la barre d'actions apparaît, acte 3 au clic, clic manuel pour corriger ; au clic sur « Bloquer », la voix confirme après sa phrase en cours mais l'écran change aussitôt et nettement) » Réponse : « Oui, toutes (Recommandé) ».
- **Q-74** : mémoire de focus par canevas transmise aux agents ; une demande de comparaison sans plateforme hérite de la plateforme affichée.
- **Q-75** : la voix parle hors délégation, après la phrase en cours (observé) ; politique de 009 conservée.
- **Indicateur** : avance automatique (complète pdr-0063 D1) ; le clic manuel reste possible.
- **Clic** : retour visuel fort et immédiat (statut de décision bien visible, bouton marqué « fait », idempotence du clic).

## Raisons
Recommandations de l'assistant validées en bloc par le porteur.

## Options écartées
- Aucune alternative documentée dans la source.

## Conséquences
- Contenu de la fonctionnalité **011** ; [p-ar-stage-runtime](../architecture/stage-runtime.md) : indicateur d'acte.
- Q-74 et Q-75 tranchées.

## Réexaminer si
- Une répétition montre une comparaison attribuée à la mauvaise plateforme.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Q-74 et Q-75 tranchées ; complète pdr-0063 D1. Réponse : « Oui, toutes (Recommandé) ». | Benoît FONTAINE (porteur), conversation |

Archive brute : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).
