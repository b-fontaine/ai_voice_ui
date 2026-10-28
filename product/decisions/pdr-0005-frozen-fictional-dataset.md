---
id: pdr-0005-frozen-fictional-dataset
title: "PDR-0005 — Données fictives, figées et déterministes"
area: decisions
status: validated
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p7, product/sources/design-example.pdf, knowledge:adr-0002-orchestrator-backend]
links: [p-fn-dataset, p-fn-scope, p-fn-nfr, p-fn-mockups, p-ar-backend, p-ar-replay, p-ar-quality, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0003-use-case-release-copilot, pdr-0006-replay-fallback-must, adr-0002-orchestrator-backend]
tags: [pdr, decision, dataset, determinism]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0005 — Jeu de données fictif et figé

> **En bref.** Les agents travaillent sur un jeu de données fictif, crédible et figé : une app mobile en versions 3.3 et 3.4. Seule la composition de l'UI varie d'une exécution à l'autre. Aucune vraie source (Crashlytics, stores) n'est connectée.

Part de l'assistant : mise en forme de la fiche. Aucune recommandation.

## Contexte
- Fiche § 3 (p. 2-3), « Dans le périmètre » : « Un jeu de données fictif et figé : une app mobile (nom à choisir) en versions 3.3 et 3.4. »
- Fiche § 3 : le MVP utilise « des données fictives crédibles et déterministes ».
- Fiche § 5, NFR-08 (p. 7) : « Données fictives figées ; seule la composition de l'UI varie », mesuré par « Snapshot des réponses d'agents ».

## Hypothèses
- ✅ Les valeurs visibles dans les maquettes (taux de sessions sans crash, notes, avis…) sont des exemples cohérents avec ce jeu → [p-fn-dataset](../functional/dataset.md), [p-fn-mockups](../functional/mockups.md).
- ⚠️ Hypothèse non confirmée : nom de l'app mobile fictive → [p-rm-open-questions](../roadmap/open-questions.md) (Q-08).
- ⚠️ Hypothèse non confirmée : le jeu définitif reprend les valeurs des maquettes. La fiche ne fixe aucune valeur → [p-rm-open-questions](../roadmap/open-questions.md) (Q-23).

## Options
1. **Données fictives figées** (retenue).
2. Connexion à de vraies sources : écartée par la fiche.

## Décision
- Les agents lisent un **jeu de données fictif versionné** couvrant les versions 3.3 et 3.4, avec au moins les plateformes Android et iOS (actes 2 et scénario « Non, plutôt iOS », fiche § 4).
- Les réponses des agents sont **déterministes** sur les données ; la composition de l'UI par le LLM peut varier.

## Raisons
- Fiche § 3 : la crédibilité et le déterminisme sont exigés pour les 3 actes.
- NFR-08 : un snapshot des réponses d'agents doit pouvoir être comparé entre répétitions.
- Cohérent avec [pdr-0001-conference-demo-deliverable](pdr-0001-conference-demo-deliverable.md) : aucune dépendance à un service tiers sur scène.

## Options écartées
- **Connexion à de vraies sources** (Crashlytics, App Store Connect, Google Play Console) : hors périmètre, fiche § 3 (p. 3).

## Conséquences
- **Fonctionnel** : [p-fn-dataset](../functional/dataset.md) décrit le jeu ; toute valeur citée dans un scénario BDD doit en provenir.
- **Architecture** : les agents tournent côté backend [adr-0002-orchestrator-backend] ; déduction de l'assistant, à valider dans [p-ar-backend](../architecture/backend.md) : les données fictives sont servies par les agents backend, derrière un port, pour pouvoir brancher de vraies sources plus tard ([p-rm-beyond](../roadmap/beyond.md)).
- **Qualité** : tests de contrat par snapshot des réponses d'agents (NFR-08) → [p-ar-quality](../architecture/quality.md).
- **Rejeu** : le déterminisme des données facilite, sans le garantir, la reproductibilité du rejeu ; le rejeu s'appuie sur un journal enregistré → [p-ar-replay](../architecture/replay.md).

## Réexaminer si
- Le porteur veut une démo sur données réelles (après le talk, [p-rm-beyond](../roadmap/beyond.md)).
- Le public des répétitions juge les données peu crédibles.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 3, NFR-08) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR | Assistant (mise en forme) |

Pas d'archive brute.
