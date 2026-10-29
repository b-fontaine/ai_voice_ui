---
id: pdr-0040-reference-dataset-adjusted-by-assistant
title: "PDR-0040 — Le jeu de données de référence est conçu par l'assistant : cohérent, figé, inspiré de l'illustration sans la copier"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p3, product/sources/design-example.pdf]
links: [pdr-0005-frozen-fictional-dataset, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0021-mockup-data-not-corrected, pdr-0024-act2-android-only, pdr-0034-app-name-release-copilot, p-fn-dataset, p-fn-mockups, p-rm-open-questions]
tags: [pdr, decision, dataset, determinisme]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0040 — Jeu de référence ajusté par l'assistant

> **En bref.** Les valeurs vues dans les maquettes ne sont pas reprises telles quelles. Le porteur délègue l'ajustement à l'assistant, qui conçoit un **jeu de référence** cohérent, figé et déterministe, inspiré de l'illustration sans la copier. Les valeurs sont écrites dans [dataset.md](../functional/dataset.md) (brouillon à relire par le porteur). Tranche Q-23.

Part de l'assistant : consignation ; la conception des valeurs lui est déléguée.

## Contexte
- Q-23 : reprendre tel quel ou ajuster les valeurs des maquettes (99,53 %, 99,71 %, 99,39 %, seuil ≥ 99,50 %, 1 284 avis…) ?
- [pdr-0021](pdr-0021-mockup-data-not-corrected.md) : l'illustration n'est pas corrigée ; le jeu de référence doit être cohérent, figé, déterministe ([pdr-0005](pdr-0005-frozen-fictional-dataset.md), NFR-08).

## Hypothèses
- Aucune.

## Options
1. Reprendre tel quel
2. **Ajuster** (retenue)

## Décision
- L'assistant conçoit le jeu de référence : app « Release Copilot » ([pdr-0034](pdr-0034-app-name-release-copilot.md)), releases 3.3 et 3.4, Android et iOS.
- Contraintes : chiffres cohérents entre eux (pourcentages, totaux, seuils, courbes), compatibles avec les 3 actes (acte 2 Android seul, [pdr-0024](pdr-0024-act2-android-only.md)), figés et versionnés.
- Les maquettes inspirent l'ordre de grandeur et le récit (Android 3.4 sous le seuil), pas les valeurs exactes ([pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md)).

## Raisons
- Parole du porteur (2026-10-29), Q-23 : « Ne le reprends pas tel quel. Ajuste-le ».

## Options écartées
- **Reprendre tel quel** : écarté par le porteur ; les valeurs de l'illustration sont incohérentes (pdr-0021).

## Conséquences
- [p-fn-dataset](../functional/dataset.md) : jeu de référence écrit (séries J1-J7 et contrôles de cohérence), brouillon à relire par le porteur (livrable de l'assistant, EP-09).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-23 tranchée.

## Réexaminer si
- Le porteur conteste une valeur du jeu écrit.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « Ne le reprends pas tel quel. Ajuste-le » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Jeu de référence écrit dans dataset.md (cohérence recalculée : global 845 / 195 500 = 99,57 %, écart Android −0,28 pt) ; brouillon à relire par le porteur | Assistant |

Pas d'archive brute.
