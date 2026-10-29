---
id: pdr-0026-desktop-only-target
title: "PDR-0026 — Le produit cible le desktop seul ; les ADR hérités et notes knowledge orientés web ne changent pas la cible"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p3]
links: [p-rm-open-questions, p-fn-mockups, p-ar-overview, p-ar-frontend, p-rm-roadmap, pdr-0002-desktop-platform, pdr-0011-adopt-knowledge-adrs, adr-0001-initial-constraints, adr-0004-ds-visual-base-m3, ds-color-dark-contrast, ds-widgetbook-a11y-tooling, perf-web-initial-load]
tags: [pdr, decision, platform, desktop, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0002-desktop-platform, pdr-0011-adopt-knowledge-adrs]
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0026 — Desktop seul

> **En bref.** Décision contrainte, tranche Q-64 (E22). Cible : **desktop seul**, macOS en priorité, Windows en secours, projection 1920×1080. Mobile et web hors périmètre. Les ADR hérités et notes `knowledge/` orientés web sont génériques et ne changent pas la cible.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Fiche § 3 : « Mobile et web : desktop uniquement » ; [pdr-0002](pdr-0002-desktop-platform.md), acceptée.
- Contextes d'origine des ADR hérités : « web, mobile et desktop » [adr-0001-initial-constraints], « desktop et web » [adr-0004-ds-visual-base-m3] ; notes orientées web [ds-color-dark-contrast], [ds-widgetbook-a11y-tooling], [perf-web-initial-load].
- [pdr-0011](pdr-0011-adopt-knowledge-adrs.md) dit déjà : le produit est desktop seul, pas de conflit, le produit restreint ces ADR.

## Hypothèses
- Aucune sur la cible. La faisabilité du secours Windows est une question distincte, ouverte (Q-45, SP-09) ; l'OS de démo reste Q-07.

## Options
1. **Desktop seul (pdr-0002)** (retenue)
2. Desktop + web
3. Web, mobile et desktop

## Décision
- Le produit est une app Flutter desktop : macOS prioritaire, Windows en secours, projection 1920×1080 (pdr-0002).
- Les règles des notes `knowledge/` propres au web ou au tactile ne s'appliquent au produit que si elles valent aussi sur desktop.

## Raisons
- Fiche § 3 et pdr-0002, acceptées ; pdr-0011 restreint déjà les ADR hérités au desktop.

## Options écartées
- **Desktop + web**, **web, mobile et desktop** : contraires à la fiche § 3 et à pdr-0002.

## Conséquences
- [p-ar-overview](../architecture/overview.md), [p-ar-frontend](../architecture/frontend.md) : les mentions E22 · Q-64 deviennent « desktop seul (pdr-0026) » ; [perf-web-initial-load] n'est pas appliquée.
- [p-rm-roadmap](../roadmap/roadmap.md) J1 : dépendance Q-64 levée (Q-07, Q-45 restent).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-64 tranchée ; [p-fn-mockups](../functional/mockups.md) : E22 tranché.

## Réexaminer si
- pdr-0002 est remplacée (par exemple une démo web décidée par le porteur).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-64 ouverte lors du nettoyage de `knowledge/` | Assistant |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur | Assistant |

Pas d'archive brute.
