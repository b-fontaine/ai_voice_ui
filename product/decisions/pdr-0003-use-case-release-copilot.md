---
id: pdr-0003-use-case-release-copilot
title: "PDR-0003 — Cas d'usage métier : Release Copilot"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p10, product/sources/design-example.pdf]
links: [p-fn-vision, p-fn-personas-journey, p-fn-catalog, p-fn-dataset, p-fn-mockups, p-rm-open-questions, pdr-0004-mvp-three-acts, pdr-0005-frozen-fictional-dataset, pdr-0007-closed-catalog-stage-theme, pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog]
tags: [pdr, decision, use-case, release-copilot]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0003 — Cas d'usage : Release Copilot

> **En bref.** La démo met en scène un « Release Copilot » qui prépare la décision go/no-go d'une release mobile à partir des crashs, des avis stores, du changelog et des captures. Le découpage en agents qui porte ce cas d'usage diffère entre la fiche et la maquette, et reste ouvert.

Part de l'assistant : mise en forme de la fiche. Aucune recommandation.

## Contexte
- Fiche § 1 (p. 1), « Cas d'usage métier retenu » : « Release Copilot : préparer la décision go/no-go d'une release mobile (crashs, avis stores, changelog, captures). »
- Le cas d'usage sert le message du talk : il doit produire des écrans variés à partir d'une seule demande vocale ([p-fn-vision](../functional/vision.md)).

## Hypothèses
- ✅ Le sujet parle à tout développeur Flutter (fiche § 1).
- ⚠️ Hypothèse non confirmée : nom de l'app mobile fictive (fiche § 3 : « une app mobile (nom à choisir) ») → [p-rm-open-questions](../roadmap/open-questions.md) (Q-08).
- ⚠️ Écart E1 non tranché : la fiche § 3 décrit **3 agents** (Qualité, Voix du client, Livraison) ; la maquette n° 1 en montre **4** (Crash, Avis stores, Changelog, Captures d'écran) et un orchestrateur qui « planifie · 4 tâches » → [p-rm-open-questions](../roadmap/open-questions.md) (Q-01), [p-fn-mockups](../functional/mockups.md).

## Options
Aucune alternative documentée dans la source.

## Décision
Le domaine métier de la démo est la **préparation d'une release mobile** :
- release cible 3.4, comparée à la 3.3 ([pdr-0005-frozen-fictional-dataset](pdr-0005-frozen-fictional-dataset.md)) ;
- issue de la démo : une décision go/no-go matérialisée par une checklist et une barre d'actions (« Bloquer la release », « Valider la release ») (fiche § 7).

## Raisons
- Fiche § 1 : le cas « parle à tout développeur Flutter et produit naturellement des écrans variés ».
- Il couvre les 3 actes (créer, transformer, interagir) sans forcer le scénario ([pdr-0004-mvp-three-acts](pdr-0004-mvp-three-acts.md)).

## Options écartées
Aucune alternative documentée dans la source.

## Conséquences
- **Fonctionnel** : le catalogue est métier (En-tête de release, Indicateur clé, Liste des crashs, Checklist go/no-go…) ; son contenu exact est arrêté par pdr-0014 (6 composants) → [p-fn-catalog](../functional/catalog.md), [pdr-0007-closed-catalog-stage-theme](pdr-0007-closed-catalog-stage-theme.md).
- **Données** : jeu fictif d'une app mobile en 3.3 et 3.4 → [p-fn-dataset](../functional/dataset.md).
- **Architecture** : le nombre et le rôle des agents A2A (3 ou 4) conditionnent [p-ar-agents-protocols](../architecture/agents-protocols.md) ; l'architecture doit rester valable dans les deux cas tant que E1 est ouvert.
- **Roadmap** : la question « montrer un agent d'un autre éditeur » (E6) étendrait le cas d'usage → [p-rm-open-questions](../roadmap/open-questions.md) (Q-10).

## Réexaminer si
- Les répétitions montrent que le public ne comprend pas le domaine « release » sans explication.
- Le porteur choisit d'ajouter un agent d'un autre éditeur (E6, Q-10) et que le cas d'usage ne s'y prête pas.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 1) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR ; écart E1 signalé | Assistant (mise en forme) |
| 2026-10-29 | Écart E1 tranché par [pdr-0013](pdr-0013-orchestrator-visible-agent-selection.md) ; décision inchangée | Benoît FONTAINE (porteur) |

Pas d'archive brute.
