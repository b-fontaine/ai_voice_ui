---
id: p-fn-scope
title: Périmètre du MVP
area: functional
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p3]
links: [p-fn-vision, p-fn-requirements, p-fn-catalog, p-fn-dataset, p-fn-mockups, pdr-0001-conference-demo-deliverable, pdr-0002-desktop-platform, pdr-0004-mvp-three-acts, pdr-0005-frozen-fictional-dataset, pdr-0006-replay-fallback-must, pdr-0007-closed-catalog-stage-theme, pdr-0009-french-only, p-rm-open-questions, pdr-0013-orchestrator-visible-agent-selection, pdr-0019-six-limit-applies-to-surfaces]
tags: [perimetre, mvp, hors-perimetre]
---
# Périmètre du MVP

**En bref.** Le MVP couvre les 3 actes avec des données fictives crédibles et déterministes. Tout le reste est hors périmètre (fiche § 3, p. 2). Décision : [pdr-0004-mvp-three-acts](../decisions/pdr-0004-mvp-three-acts.md).

## Dans le périmètre (fiche § 3)

| # | Élément | Détail | Écart / décision |
|---|---|---|---|
| 1 | Un écran unique « Genesis Canvas » | 6 zones, voir [p-fn-screen](screen.md) | [pdr-0008](../decisions/pdr-0008-single-screen-show-the-making.md) |
| 2 | Conversation vocale **en français** | Le speaker peut interrompre l'IA à tout moment | [pdr-0009](../decisions/pdr-0009-french-only.md) |
| 3 | Un orchestrateur et **3 agents** visibles | Qualité (crashs), Voix du client (avis des stores), Livraison (changelog et checklist) | Nombre non fixé ; noms métier et sélection visible par l'orchestrateur ([pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md), E1 tranché) |
| 4 | Un catalogue fermé de **6 composants** (voir [pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) | Au maximum **6 surfaces** visibles en même temps ; voir [p-fn-catalog](catalog.md) | Contenu tranché (E2 · Q-02, [pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) ; « 6 » = surfaces visibles (E4 · Q-04, [pdr-0019](../decisions/pdr-0019-six-limit-applies-to-surfaces.md)) |
| 5 | Agir sur un composant généré (bouton) | L'IA répond | FR-08 |
| 6 | Enregistrement de chaque session et rejeu | Sert aussi de **mode secours** | [pdr-0006](../decisions/pdr-0006-replay-fallback-must.md) |
| 7 | Jeu de données fictif et figé | Une app mobile en versions 3.3 et 3.4 ; ⚠️ nom de l'app à choisir (E5 · Q-08) | [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md), [p-fn-dataset](dataset.md) |

## Hors périmètre (fiche § 3)

| Exclu | Conséquence |
|---|---|
| Connexion à de vraies sources (Crashlytics, App Store Connect, Google Play Console) | Les agents lisent le jeu fictif ([p-fn-dataset](dataset.md)) |
| Authentification utilisateur, multi-utilisateur, persistance au-delà de la session | À clarifier : voir E18 · Q-36 (note ci-dessous) |
| Mobile et web | Desktop uniquement ([pdr-0002](../decisions/pdr-0002-desktop-platform.md)) |
| Localisation autre que le français | [pdr-0009](../decisions/pdr-0009-french-only.md) |
| Génération de widgets hors catalogue | L'agent ne compose qu'avec les widgets déclarés ([pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md)) |

⚠️ **Point à clarifier (écart E18 · Q-36).** « Pas de persistance au-delà de la session » coexiste avec « rejeu d'une session enregistrée » en mode secours (FR-10) : la session de secours doit avoir été enregistrée **avant** le talk, donc persistée. La fiche ne dit pas où ni comment. Voir [p-rm-open-questions](../roadmap/open-questions.md).

## Question ouverte (fiche § 3)

Montrer un agent venu d'un autre éditeur, qui s'intègre sans adaptation ? Argument le plus fort de l'approche multi-agents, mais un acte de plus (E6 · Q-10). Non tranché : [p-rm-open-questions](../roadmap/open-questions.md).

## Hors produit mais structurant

La sécurité (aucune clé longue durée côté client, NFR-09) et la reproductibilité (versions figées, NFR-10) restent dans le périmètre même pour une démo : voir [p-fn-nfr](nfr.md) et [pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md).
