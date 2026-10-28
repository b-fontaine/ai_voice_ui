---
id: pdr-0015-app-held-canvas-layout
title: "PDR-0015 — Mise en page du canevas tenue par l'app, sans composant Grid dans le catalogue"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p10, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-mockups, p-fn-catalog, p-fn-business-rules, p-ar-frontend, p-ar-agents-protocols, pdr-0014-six-component-catalog, pdr-0007-closed-catalog-stage-theme, pdr-0008-single-screen-show-the-making, genui-multiple-surfaces]
tags: [pdr, decision, layout, surfaces, grid]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0015 — Mise en page du canevas tenue par l'app, sans composant Grid dans le catalogue

> **En bref.** Tranche Q-29 (écart E11). `Grid` ne fait **pas** partie du catalogue. L'app place les surfaces dans une **grille fixe**, N surfaces ; l'IA ne contrôle pas la mise en page.

Part de l'assistant : recommandation et mise en forme ; la décision est du porteur.

## Contexte
Maquette 1 : une surface `release-3-4` à racine `Grid` ; maquette 2 : surfaces distinctes `s-*`. Fiche : « les surfaces existantes restent à leur place » (S-02, FR-07). Voir [p-fn-mockups](../functional/mockups.md) (E11) et [genui-multiple-surfaces].

## Hypothèses
- ✅ La disposition était déjà décrite comme tenue par l'app dans [p-ar-frontend](../architecture/frontend.md).
- ⚠️ Q-04 (limite « 6 ») reste ouverte ; la grille de l'app est dimensionnée pour au plus 6 surfaces (NFR-06) sans trancher Q-04.

## Options
1. **Grille fixe tenue par l'app, N surfaces** (retenue)
2. Une surface à racine A2UI `Grid` (maquette 1)

## Décision
- L'app place les surfaces dans une grille fixe ; chaque surface est indépendante (N surfaces).
- `Grid` n'est pas un composant du catalogue ([pdr-0014](pdr-0014-six-component-catalog.md)).
- L'IA choisit les composants et leurs données, pas leur emplacement.

## Raisons
Parole du porteur, 2026-10-29 (conversation avec l'assistant), après présentation des recommandations : « oui, enregistre tes recommandations comme décision. Je les valide. »
Garantit que « les surfaces restent à leur place » (FR-07, S-02) ; facilite le rejeu ; retire une source d'écran incohérent (risque R6) ; l'IA ne contrôle pas la mise en page.

## Options écartées
- Option 2 : l'IA pilote la mise en page, risque d'écran incohérent et rejeu moins stable.

## Conséquences
- [p-fn-mockups](../functional/mockups.md) : E11 tranché. [p-fn-catalog](../functional/catalog.md) : pas de `Grid`.
- [p-ar-frontend](../architecture/frontend.md), [p-ar-agents-protocols](../architecture/agents-protocols.md) : N surfaces `s-*`, pas de racine `board`.
- [p-fn-business-rules](../functional/business-rules.md) : RG-14 / RG-15 s'appuient sur le modèle à N surfaces.
- Roadmap : dépendance Q-29 levée (J2).

## Réexaminer si
- La grille fixe ne tient pas 6 surfaces lisibles en 1920×1080 (SP-07).
- Un besoin de mise en page pilotée par l'IA apparaît.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Recommandation présentée par l'assistant | Assistant |
| 2026-10-29 | Acceptée, sur la parole « oui, enregistre tes recommandations comme décision. Je les valide. » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
