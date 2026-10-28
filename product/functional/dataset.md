---
id: p-fn-dataset
title: Jeu de données fictif et figé
area: functional
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p6, product/sources/design-example.pdf]
links: [p-fn-scope, p-fn-mockups, p-fn-catalog, p-fn-business-rules, p-ar-replay, pdr-0005-frozen-fictional-dataset, p-rm-open-questions, pdr-0014-six-component-catalog]
tags: [donnees, dataset, determinisme, release]
---
# Jeu de données fictif

**En bref.** Une app mobile fictive en versions **3.3** et **3.4**, avec des crashs, des avis des stores, un changelog et des critères go/no-go. Les données sont figées : seule la composition de l'UI varie (NFR-08, [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md)). Les valeurs ci-dessous sont celles **vues dans les maquettes** ; elles n'ont pas encore été validées comme jeu de référence.

## Cadre (fiche)

| Élément | Valeur | Source |
|---|---|---|
| Application | App mobile, ⚠️ **nom à choisir** (hypothèse non confirmée, E5 · Q-08) | § 3 |
| Versions | 3.3 (précédente) et 3.4 (à décider) | § 3 |
| Plateformes | iOS et Android | § 4 (FR-17, BDD), maquettes |
| Sources simulées | Crashs, avis des stores, changelog, captures | § 1 |
| Vraies sources | Aucune (Crashlytics, App Store Connect, Google Play Console exclus) | § 3 |
| Contrainte | Crédible, déterministe, figée | § 3, NFR-08 |

## Valeurs visibles dans les maquettes

### Stabilité (agent Crash / Qualité)

| Indicateur | Valeur | Maquette |
|---|---|---|
| Sessions sans crash, 3.4 bêta, 7 derniers jours | **99,53 %** | 2 |
| — iOS | 99,71 % | 2, 3 |
| — Android | 99,39 % | 2, 3 |
| Sessions sans crash Android, 3.3 | 99,64 % | 3 |
| Écart Android 3.4 vs 3.3 | −0,25 pt | 3 |
| Seuil go sans crash | ≥ 99,50 % (« non atteint » pour Android) | 3 |
| Taux de crash (% des sessions), axe | 0 % – 1,0 %, J1 à J7 | 2, 3 |
| Taux de crash Android 3.4 (série) | J5 : 0,62 · J6 : 0,71 · J7 : 0,82 | 2 (`dataModelUpdate /series/android`), 3 |
| Taux de crash Android 3.3 à J7 | 0,35 (légende 3.3 / 3.4 en maquette 3 ; en maquette 2 la courbe basse est iOS) | 3 |
| Seuil go sur la courbe | 0,5 % (ligne pointillée « seuil go ») | 3 |
| Messages traités par l'agent Crash | 9 msg | 2 |

### Avis des stores (agent Avis stores / Voix du client)

| Indicateur | Valeur | Maquette |
|---|---|---|
| Volume d'avis | 1 284 avis | 2 |
| Avis négatifs Android 3.4 | **37 %** | 3 |
| Avis négatifs Android 3.3 | **18 %** | 3 |
| Seuil go avis négatifs | ≤ 25 % | 3 |
| Thème n° 1 | « Plantage à la validation du panier » — 212 mentions | 3 |

### Changelog (agent Changelog / Livraison)

| Indicateur | Valeur | Maquette |
|---|---|---|
| Volume | 37 PR | 2, 3 |
| Entrée 1 | « Paiement : flux 3-D Secure 2 » — feat · 12 PR | 2 |
| Nombre d'entrées | 5 (« 1 / 5 entrées » en cours) | 2 |

### Décision go/no-go 3.4 (maquette 3)

| Critère | Valeur | Statut |
|---|---|---|
| Sans crash Android ≥ 99,5 % | 99,39 | ✗ bloquant |
| Avis négatifs ≤ 25 % | 37 % | ✗ bloquant |
| Sans crash iOS ≥ 99,5 % | 99,71 | ✓ validé |
| Changelog validé | 37 PR | ✓ validé |
| **Recommandation** | 2 critères bloquants | **NO-GO Android** |

## Identifiants vus dans les maquettes

| Type | Valeurs |
|---|---|
| Surfaces | `release-3-4`, `s-kpi`, `s-crash-trend`, `s-reviews`, `s-changelog`, `s-decision` |
| Chemins du data model | `/reviews`, `/series/android` (clés `d5`, `d6`, `d7`) |
| Catalogue | `genesis.release` |

## Points à vérifier (assistant)

- ⚠️ **Cohérence à figer (E15 · Q-33, Q-23).** Le taux de crash Android à J7 vaut 0,82 % alors que 99,39 % de sessions sans crash donne 0,61 % sur 7 jours. C'est plausible (valeur du jour contre moyenne), mais le jeu de référence devra le rendre explicite, car le public peut faire le calcul.
- Les données manquantes : **Liste des crashs** (top crashs, plateforme, volume), composant retenu ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) mais sans aucune donnée dans les maquettes : **point ouvert**, à écrire dans le jeu figé sans l'inventer ici ; note moyenne, 3 extraits d'avis (Sentiment des avis, version de la fiche), répartition positifs / négatifs. Comparatif de versions et date cible : composants ou champs écartés par pdr-0014.
- Les seuils go (99,50 %, 25 %) n'apparaissent que dans les maquettes : à confirmer par le porteur.

Toutes ces questions vont dans [p-rm-open-questions](../roadmap/open-questions.md). Le stockage et la relecture du jeu (snapshots des réponses d'agents) sont décrits dans [p-ar-replay](../architecture/replay.md).
