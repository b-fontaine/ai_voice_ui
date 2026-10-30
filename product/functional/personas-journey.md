---
id: p-fn-personas-journey
title: Personas et parcours en 3 actes
area: functional
status: validated
updated: 2026-10-30
sources: [product/sources/product-description.pdf#p2, product/sources/design-example.pdf]
links: [p-fn-vision, p-fn-scope, p-fn-requirements, p-fn-mockups, p-fn-dataset, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, p-rm-open-questions, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0035-no-third-party-agent]
tags: [personas, parcours, actes, demo]
---
# Personas et parcours de la démo

**En bref.** Trois personas : le speaker qui pilote la démo, le développeur Flutter et le lead tech dans la salle. Le parcours tient en 3 actes (Créer, Transformer, Interagir), plus un rejeu optionnel.

## Personas (fiche § 2, p. 2)

| Persona | Objectif | Ce qu'il doit repartir en ayant compris | Point de friction |
|---|---|---|---|
| **Speaker** (Benoît), opérateur de la démo | Dérouler 3 actes sans incident, piloter à la voix | — | Bruit de salle, réseau, latence, stress du direct |
| **Développeur Flutter** dans la salle | Voir si GenUI est utilisable chez lui | Catalogue = contrôle du rendu ; A2UI = donnée, pas code | Texte illisible au fond, jargon protocolaire |
| **Lead tech / architecte** dans la salle | Évaluer la maturité et l'architecture | Où vivent les agents, comment sécuriser, quoi figer | Doute sur la maturité « expérimentale » |

Conséquences fonctionnelles directes :
- friction « texte illisible » → NFR-05 (24 px, WCAG AA) ([p-fn-nfr](nfr.md)) ;
- friction « stress du direct, réseau » → mode secours en un raccourci ([pdr-0006](../decisions/pdr-0006-replay-fallback-must.md)), remplacé par une vidéo de secours gérée par le porteur ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) ;
- attente « où vivent les agents » → rail des agents et flux du protocole visibles ([p-fn-screen](screen.md)).

## Parcours en 3 actes (fiche § 2)

| Acte | Déclencheur | Ce qui se passe | Exigences |
|---|---|---|---|
| 1. **Créer** | Le speaker dit « Prépare la release 3.4 » | Trois agents s'allument ; **quatre surfaces** se construisent progressivement ; le panneau JSON se déplie **une fois** | FR-02, FR-03, FR-04, FR-05, NFR-02, NFR-03 |
| 2. **Transformer** | « Concentre-toi sur Android et compare avec la 3.3 » | Les surfaces existantes **mutent sur place** au lieu d'être recréées | FR-07 |
| 3. **Interagir** | Clic sur le bouton généré « Bloquer la release » | L'événement repart vers l'agent, qui confirme à la voix et met à jour la checklist | FR-08 |
| 4. **Rejouer** (optionnel) | Curseur de rejeu | La génération de l'acte 1 repasse au ralenti, synchronisée avec le JSON | FR-09 |

Le parcours fixe le périmètre du MVP : [pdr-0004-mvp-three-acts](../decisions/pdr-0004-mvp-three-acts.md).

## Phrases clés du speaker

| Moment | Phrase (fiche) | Source |
|---|---|---|
| Acte 1 | « Prépare la release 3.4 » | § 2, § 4 (BDD) |
| Acte 2 | « Concentre-toi sur Android et compare avec la 3.3 » | § 2, § 4 (BDD) |
| Correction | « Non, plutôt iOS » | § 4 (FR-17, BDD) |
| Annulation | « Stop » ou « annule » | § 4 (FR-16) |

La parade au bruit de salle demande des **phrases clés courtes et rodées** (fiche § 8).

## Écarts avec les maquettes

Les maquettes numérotent trois **étapes** (« 1 / 3 · VIDE », « 2 / 3 · CONSTRUCTION », « 3 / 3 · TRANSFORMATION ») qui ne recouvrent pas les trois actes de la fiche : l'acte 3 n'a pas de maquette dédiée, et le bouton « Bloquer la release » apparaît dès la transformation (écarts E9 · Q-22 et E7 · Q-20 : tranchés, un indicateur « Acte n/3 » reprend les 3 actes de la fiche, pdr-0054 ; la Barre d'actions arrive à la fin de l'acte 2, pdr-0061). La maquette montre aussi 4 agents au lieu de 3 (écart E1 · Q-01). Détails : [p-fn-mockups](mockups.md) ; arbitrages ouverts : [p-rm-open-questions](../roadmap/open-questions.md).

## Question ouverte (fiche § 3)

Faut-il montrer un **agent d'un autre éditeur**, qui s'intègre sans adaptation ? C'est l'argument le plus fort de l'approche multi-agents, mais il ajoute un acte à la démo (écart E6 · Q-10, [p-rm-open-questions](../roadmap/open-questions.md)). Tranché : **non** ([pdr-0035](../decisions/pdr-0035-no-third-party-agent.md)).
