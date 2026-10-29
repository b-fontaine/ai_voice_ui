---
id: pdr-0020-act1-four-surfaces
title: "PDR-0020 — L'acte 1 compose 4 surfaces : Indicateur clé, Courbe de tendance, Sentiment des avis, Checklist go/no-go"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p10]
links: [p-rm-open-questions, p-fn-mockups, p-fn-catalog, p-fn-personas-journey, p-fn-dataset, p-fn-feature-voice-screen-generation, p-rm-roadmap, pdr-0014-six-component-catalog, pdr-0016-validate-release-action, pdr-0017-source-hierarchy-sheet-over-mockups]
tags: [pdr, decision, acte-1, catalog, surfaces, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0014-six-component-catalog, pdr-0017-source-hierarchy-sheet-over-mockups, p-fn-feature-voice-screen-generation, p-fn-catalog]
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0020 — L'acte 1 compose 4 surfaces

> **En bref.** Décision contrainte, tranche Q-28 (E10). L'acte 1 compose **4 surfaces** : Indicateur clé, Courbe de tendance, Sentiment des avis, Checklist go/no-go. L'En-tête de release est hors catalogue, la Liste des crashs hors scénario principal, la Barre d'actions relève de l'acte 3.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Q-28 opposait la fiche § 7 (En-tête et Checklist marqués acte 1) à la maquette 2 (KPI, courbe, avis, changelog) ([p-fn-mockups](../functional/mockups.md), E10).
- [pdr-0014](pdr-0014-six-component-catalog.md), acceptée par le porteur et maintenue par l'exception de [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md), fixe la colonne « Actes » de chaque composant ([p-fn-catalog](../functional/catalog.md)).
- Fiche § 2 acte 1 et § 4 S-01 : « 4 surfaces sont complètes en moins de 8 secondes » ([voice-screen-generation.feature](../functional/features/voice-screen-generation.feature)).

## Hypothèses
- Aucune : la composition découle de pdr-0014 et de S-01.

## Options
1. **Les 4 composants marqués acte 1 dans pdr-0014** (retenue)
2. Composition de la fiche § 7 d'origine (avec En-tête de release)
3. Composition de la maquette 2 (avec changelog / Timeline)

## Décision
| Surface de l'acte 1 | Agent |
|---|---|
| Indicateur clé | Qualité |
| Courbe de tendance | Qualité |
| Sentiment des avis | Voix du client |
| Checklist go/no-go (dont la ligne « Changelog validé · 37 PR ») | Livraison |

Hors acte 1 : En-tête de release (écarté du catalogue, pdr-0014) ; Liste des crashs (hors scénario principal) ; Barre d'actions (acte 3, [pdr-0016](pdr-0016-validate-release-action.md)).

## Raisons
- Les composants marqués acte 1 dans pdr-0014 sont exactement 4, ce qui correspond aux « 4 surfaces » de S-01 : une seule composition est cohérente avec les décisions acceptées et la fiche.

## Options écartées
- **Fiche § 7 d'origine** : l'En-tête de release a été écarté du catalogue par pdr-0014.
- **Maquette 2** : la Timeline est écartée par pdr-0014 ; la maquette n'est qu'une illustration (pdr-0017).

## Conséquences
- [p-fn-catalog](../functional/catalog.md), [p-fn-personas-journey](../functional/personas-journey.md) : composition de l'acte 1 explicite.
- [p-fn-dataset](../functional/dataset.md) : le jeu figé doit couvrir ces 4 surfaces (Q-23).
- [p-rm-roadmap](../roadmap/roadmap.md) J3 : dépendance Q-28 levée.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-28 tranchée ; [p-fn-mockups](../functional/mockups.md) : E10 tranché.
- L'IA garde le choix de la composition (fiche § 7) ; ces 4 surfaces sont l'écran attendu de l'acte 1, fourni en exemple ([pdr-0023](pdr-0023-example-guided-composition.md)).

## Réexaminer si
- pdr-0014 est remplacée (contenu du catalogue ou colonne « Actes » modifiés).
- La fiche change le nombre de surfaces de S-01.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-28 ouverte sans recommandation (consigne « tout laisser ouvert ») | Assistant |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur (pdr-0014, pdr-0017) | Assistant |

Pas d'archive brute.
