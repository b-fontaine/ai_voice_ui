---
id: pdr-0072-design-ergonomics-013
title: "PDR-0072 — Design et ergonomie : fonctionnalité dédiée 013, après 011-012"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-rm-open-questions, p-rm-roadmap, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0011-adopt-knowledge-adrs, p-fn-requirements]
tags: [pdr, decision, design, ergonomie, widgetbook]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire après l'essai au micro)"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0072 — Design et ergonomie : fonctionnalité dédiée 013, après 011-012

> **En bref.** Le design et l'ergonomie forment une fonctionnalité dédiée (013) après 011 et 012 : design system et Widgetbook (ADR 0004-0008), animations d'apparition (FR-04, NFR-04), lisibilité 24 px (NFR-05), mise en page inspirée de la maquette (pdr-0017), corrections visuelles connues, régie.

Part de l'assistant : recommandation, mise en forme et consignation de la parole du porteur.

## Contexte
Les corrections visuelles connues (bande vide sous la barre du haut, titre de courbe tronqué) et le design ne sont pas traités dans les fonctionnalités actuelles.

Observations du porteur (conversation du 2026-10-30) : « Je n'ai pas vu la comparaison dans l'essai que tu m'as demandé ; Le composant Crashlist n'est jamais apparu, même après l'avoir demandé explicitement ; Lui dire stop ou essayer de lui couper la parole ne fonctionne pas ; Quand je dis stop, rien ne se passe ; Quand je m'interrompts, elle compte ça comme une fin de phrase ; par contre, elle ne repère que ma voix, les bruits autour n'ont pas d'impact ; C'est toujours écrit Acte 1/3 en haut à droite, même après avoir bloqué la release ; Cliquer sur "Bloquer la release" n'a eu un effet qu'après le discours de l'IA ».

Diagnostic complet (contre-vérifié sur les journaux des sessions) : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).

## Options
1. **Fonctionnalité dédiée après 011-012** (retenue).
2. Traiter au fil des autres fonctionnalités.

## Décision
Question posée : « Design et ergonomie : quand ? » Réponse : « Fonctionnalité dédiée après 011-012 (Recommandé) ».
Contenu de 013 : design system et Widgetbook (ADR 0004-0008) ; animations d'apparition (FR-04, NFR-04) ; lisibilité 24 px (NFR-05) ; mise en page inspirée de la maquette (la fiche fait foi, pdr-0017) ; bande vide sous la barre du haut ; titre de courbe tronqué ; régie.

## Raisons
Les Must fonctionnels (voix, composition) passent avant l'habillage.

## Options écartées
- Au fil de l'eau : disperse le travail visuel.

## Conséquences
- Fonctionnalité **013** avant J7 ; reprend une partie du périmètre visuel de J7.

## Réexaminer si
- Le calendrier impose une coupe : le design serait réduit aux corrections bloquantes.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Réponse : « Fonctionnalité dédiée après 011-012 (Recommandé) ». | Benoît FONTAINE (porteur), conversation |

Archive brute : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).
