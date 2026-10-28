---
id: p-sources
title: Sources primaires du produit
area: meta
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf, product/sources/design-example.pdf]
links: [p-readme, p-conventions, p-fn-vision, p-fn-mockups, p-rm-open-questions]
tags: [sources, fiche-produit, maquettes, meta]
---
# Sources primaires

**En bref.** Deux PDF fondent toute la documentation produit : la **fiche produit** (source fonctionnelle validée par le porteur) et les **maquettes** (illustration). Ils ne se modifient jamais ; les documents de `product/` les citent par page (`product-description.pdf#p4`).

## Inventaire

| Fichier | Contenu | Auteur, date | Statut | Exploité dans |
|---|---|---|---|---|
| [product-description.pdf](product-description.pdf) | Fiche produit « Genesis Canvas », 12 pages, 8 sections (voir ci-dessous) | Benoît FONTAINE (porteur), 2026-10-28 | **Source validée** : fait foi pour le fonctionnel | Toute la zone [functional/](../functional/), [roadmap](../roadmap/roadmap.md), PDR 0001 à 0012 |
| [design-example.pdf](design-example.pdf) | 3 maquettes haute fidélité « Genesis Canvas — Release Copilot » : canevas vide, construction de l'acte 1, transformation de l'acte 2 | Porteur, reçu le 2026-10-28 | **Illustration** : ne prime pas sur la fiche | [mockups.md](../functional/mockups.md), [dataset.md](../functional/dataset.md), [catalog.md](../functional/catalog.md) |

## Plan de la fiche produit

| Section | Pages | Document produit principal |
|---|---|---|
| 1. Vision et problème | p1-p2 | [vision.md](../functional/vision.md) |
| 2. Personas et parcours | p2 | [personas-journey.md](../functional/personas-journey.md) |
| 3. Périmètre | p2-p3 | [scope.md](../functional/scope.md) |
| 4. Exigences fonctionnelles et scénarios BDD | p3-p6 | [requirements.md](../functional/requirements.md), [features/](../functional/features/) |
| 5. Exigences non fonctionnelles | p6-p7 | [nfr.md](../functional/nfr.md) |
| 6. Description fonctionnelle de l'écran | p7-p10 | [screen.md](../functional/screen.md) |
| 7. Catalogue de composants | p10-p11 | [catalog.md](../functional/catalog.md) |
| 8. Risques, plan B et critères d'acceptation | p11-p12 | [risks-acceptance.md](../functional/risks-acceptance.md) |

## Règles

1. **Ne jamais modifier ni remplacer un PDF.** Une nouvelle version de la fiche est un **nouveau fichier** daté (ex. `product-description-2026-11-15.pdf`) ; l'ancien reste.
2. **Toute nouvelle source** (PDF, export, compte rendu, enregistrement) est déposée ici **et** ajoutée au tableau « Inventaire » avec auteur, date et statut (validée / illustration / brouillon).
3. **Hiérarchie** : fiche validée > maquettes > synthèses de l'assistant. Un écart entre sources n'est **pas tranché** dans les docs : il est décrit dans [mockups.md](../functional/mockups.md) et renvoyé au registre [p-rm-open-questions](../roadmap/open-questions.md) (consigne du porteur : « tout laisser ouvert »).
4. Après l'arrivée d'une source, invoquer `product-curate` pour propager les changements, puis lancer `python3 -I product/_tools/product_lint.py`.
