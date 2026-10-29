---
id: pdr-0039-component-voice-interactions-via-fr07
title: "PDR-0039 — Les interactions vocales par composant sont couvertes par FR-07 uniquement"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p10]
links: [p-fn-catalog, p-fn-requirements, p-fn-business-rules, p-fn-dataset, p-rm-open-questions, pdr-0024-act2-android-only]
tags: [pdr, decision, catalogue, voix, perimetre]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0039 — Interactions vocales par composant = FR-07

> **En bref.** Les interactions vocales propres à chaque composant (colonne « Ce que l'utilisateur peut faire » de la fiche § 7) n'ajoutent **aucune exigence** : elles relèvent de **FR-07** (modification sur place à la voix), et rien de plus. Tranche Q-61.

Part de l'assistant : consignation.

## Contexte
- Fiche § 7 : « Demander le détail à la voix » (Indicateur clé), « Demander une autre période ou plateforme » (Courbe), « Filtrer par plateforme à la voix », « Demander les avis d'une plateforme » (Sentiment). Aucune FR, RG ni scénario ne les portait (Q-61).

## Hypothèses
- Aucune.

## Options
1. Must hors des 3 actes
2. **Couvertes par FR-07 uniquement** (retenue)
3. Illustratives, hors MVP

## Décision
- Pas de nouvelle FR, RG ni scénario. Une demande vocale sur un composant est une demande de modification traitée par FR-07 / RG-06 ; seul le déroulé de l'acte 2 (S-02) est vérifié.

## Raisons
- Parole du porteur (2026-10-29), Q-61 : « couvertes par FR-07 uniquement ».

## Options écartées
- **Must hors actes** et **hors MVP** : non retenues par le porteur.

## Conséquences
- [p-fn-catalog](../functional/catalog.md), [p-fn-business-rules](../functional/business-rules.md) : point ouvert clos (renvoi à FR-07).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-61 tranchée.

## Réexaminer si
- Le déroulé ajoute une demande vocale qui n'est pas une modification de surface.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « couvertes par FR-07 uniquement » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
