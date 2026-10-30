---
id: p-fn-dataset-acts
title: Jeu de données - actes 2 et 3 et vue iOS
area: functional
status: draft
updated: 2026-10-30
sources: [specs/009-j5-act3-interact/status.md, specs/009-j5-act3-interact/plan.md, specs/008-j4-act2-transform/status.md, specs/008-j4-act2-transform/plan.md, contracts/a2ui/genesis/v1/README.md, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p10]
links: [pdr-0065-009-act3-interact-details-assistant-decided, p-fn-dataset, p-fn-catalog, p-fn-requirements, p-ar-backend, p-ar-app-channel-contract, p-rm-open-questions, pdr-0024-act2-android-only, pdr-0040-reference-dataset-adjusted-by-assistant, pdr-0016-validate-release-action, pdr-0014-six-component-catalog, pdr-0061-action-bar-appears-end-of-act-2, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0064-008-act2-transform-details-assistant-decided]
tags: [donnees, dataset, acte-2, ios, determinisme]
---
# Jeu de données - actes 2 et 3 et vue iOS

**En bref.** Suite de [p-fn-dataset](dataset.md) (cadre, règles de calcul, séries quotidiennes, acte 1) : valeurs affichées à l'acte 2 (Android seul, comparaison avec la 3.3, FR-07), à la correction de plateforme (vue iOS, FR-17 premier temps) et à l'acte 3 (décision « Bloquée » / « Validée », Barre d'actions, FR-08). Livrées par les fonctionnalités 008 et 009 (2026-10-30) : les valeurs chiffrées sont **recalculées depuis les lignes brutes par les tests Go**, sans écart ; les libellés de décision et de la Barre d'actions sont **lus dans `dataset.json`** (§ Contrôles).

## Acte 2 — « Concentre-toi sur Android et compare avec la 3.3 » (Android seul, [pdr-0024](../decisions/pdr-0024-act2-android-only.md))

| Surface | Android 3.3 | Android 3.4 | Écart | Seuil |
|---|---|---|---|---|
| Indicateur clé : sans crash 7 j | 99,71 % | **99,43 %** | **−0,28 pt** | ≥ 99,50 % : non atteint par la 3.4 |
| Courbe : taux de crash du jour | 0,27 à 0,31 %, stable | 0,30 % → 0,84 % | J7 : +0,55 pt | ligne 0,50 % ; 3.4 au-dessus dès J5 |
| Sentiment : avis négatifs | 14 % (108 / 774) | **30 %** (240 / 792) | **+16 pts** | ≤ 25 % : non atteint par la 3.4 |
| Sentiment : note moyenne | 4,2 | 3,7 | −0,5 | — |

Répartition Android 3.3 (1★ à 5★) : 50 / 30 / 28 / 236 / 430 ; positifs 86 %. Thème n° 1 des avis négatifs Android 3.4 : « Plantage à la validation du panier », **118 mentions** sur 240 avis négatifs (0 en 3.3, où le flux 3-D Secure 2 n'existe pas).

Trois extraits affichés (acte 2, Android 3.4) :
1. ★☆☆☆☆ — « L'app se ferme dès que je valide mon panier. Impossible de payer depuis la mise à jour. »
2. ★★☆☆☆ — « Je valide dans l'app de ma banque, je reviens : l'app redémarre et mon panier est vide. »
3. ★★★★☆ — « Le panier hors ligne est pratique, mais le paiement plante encore de temps en temps. »

**Checklist go/no-go** — 3.4 Android.

| Critère | Seuil | Valeur | Statut |
|---|---|---|---|
| Sessions sans crash Android (7 j) | ≥ 99,50 % | 99,43 % (3.3 : 99,71 %) | **bloquant** |
| Avis négatifs Android (7 j) | ≤ 25 % | 30 % (3.3 : 14 %) | **bloquant** |
| Changelog validé (37 PR, toutes livrées dans le build Android) | revue faite | 37 PR | validé |
| **Recommandation** | | 2 critères bloquants | **NO-GO Android** · statut « En attente de décision » |

## Correction de plateforme — vue iOS (FR-17 premier temps, S-07, [pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md))

Vue servie à « Non, plutôt iOS » après l'acte 2 : mêmes quatre surfaces, **sans comparaison** (le jeu ne contient pas de 3.3 pour iOS). Valeurs tirées des lignes brutes iOS 3.4 ci-dessus ; détail d'affichage tranché par l'assistant (pdr-0040, pdr-0062).

| Surface | Valeur iOS 3.4 |
|---|---|
| Indicateur clé : sans crash 7 j | **99,80 %**, +0,03 pt (99,78 → 99,81), seuil ≥ 99,50 % atteint, statut validé |
| Courbe : taux de crash du jour | une série « iOS 3.4 » (0,19 à 0,22 %), ligne de seuil 0,50 % jamais franchie |
| Sentiment : 372 avis | négatifs **10 %** (37), positifs **90 %** (335), note moyenne 4,4 |
| Checklist go/no-go | sans crash iOS 99,80 % (≥ 99,50 %) validé ; avis négatifs iOS 10 % (≤ 25 %) validé ; changelog 37 PR validé ; recommandation **GO iOS** · « En attente de décision » |

Trois extraits affichés (iOS 3.4) :
1. ★★★★★ — « La validation bancaire est enfin rapide, plus besoin de ressaisir ma carte. »
2. ★★★★☆ — « Le panier hors ligne me sauve dans le métro, bien vu. »
3. ★★★☆☆ — « La galerie photos est plus belle, mais l'ouverture d'une notification plante parfois. »

## Acte 3 — action sur la Barre d'actions (FR-08, 009)

La Barre d'actions est créée par l'agent Livraison à la fin de l'acte 2 ([pdr-0061](../decisions/pdr-0061-action-bar-appears-end-of-act-2.md)). Libellés lus dans `dataset.json` (`actionBar`, `decisions`) :

| Élément | Valeur |
|---|---|
| Titre de la barre | « Décision » |
| Bouton 1 | « Bloquer la release » (`block_release`, ton `danger`) |
| Bouton 2 | « Valider la release » (`validate_release`, ton `neutral`) |

| Action | Agent | Statut de la checklist (`decisionStatus`) | Phrase dite après `completed` | Critères et recommandation |
|---|---|---|---|---|
| « Bloquer la release » (S-03, RG-28) | Livraison | **Bloquée** (avant : « En attente de décision ») | « C'est fait. La release 3.4 est bloquée. » | inchangés (NO-GO Android, comparaison 3.3) |
| « Valider la release » (RG-30, [pdr-0016](../decisions/pdr-0016-validate-release-action.md)) | Livraison | **Validée** | « C'est fait. La release 3.4 est validée. » | inchangés : la décision humaine prime sur la recommandation |

- Le résultat est un `updateDataModel` du **seul sous-chemin** `/checklist/decisionStatus` (le reste de la checklist n'est pas réécrit : [pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md) D3). Fixtures `act3-block` et `act3-validate`.
- Le résumé ne cite ni chiffre ni recommandation (l'agent est sans état) ; version et verbe viennent du jeu de données. Si l'agent échoue : checklist inchangée, phrase d'échec honnête, jamais « Bloquée » annoncé (ma-real-tool-results).
- ⚠️ Limite connue (Q-76) : une demande vocale ultérieure (« plutôt iOS ») fait réécrire tout `/checklist` avec « En attente de décision » ; la décision est perdue.

## Contrôles (008 et 009, livrés le 2026-10-30)

| Point | Constat |
|---|---|
| Valeurs recalculées | `backend/agents/internal/dataset` (`TestAct2AndIosValuesFromRows`) : Android 3.4 **99,43 %**, tendance **−0,54 pt**, 792 avis, **30 %** négatifs, note **3,7** ; Android 3.3 **99,71 %**, 774 avis, **14 %** négatifs ; écart **−0,28 pt** et **+16 pts** ; 2 critères bloquants, **NO-GO Android** ; iOS 3.4 **99,80 %**, **+0,03 pt**, 372 avis, **10 %**, note **4,4**, **GO iOS** |
| Versions | version cible (3.4) et version de comparaison (3.3) lues dans `dataset.json`, plus aucune constante dans le code ; `Load` les exige |
| Comparaison | `Comparison(plateforme)` n'existe que si le jeu contient les lignes 3.3 des sessions **et** des avis de la plateforme : Android seulement ; refusée pour iOS (`TestComparisonNeedsRowsOfBothSources`) |
| Extraits | par **vue** (`global`, `android`, `ios`), exactement 3 par vue (`TestExcerptsByView`, `TestLoadRequiresThreeExcerptsPerView`) ; ceux de iOS sont inventés par l'assistant ([pdr-0040](../decisions/pdr-0040-reference-dataset-adjusted-by-assistant.md)) |
| Checklist | `PlatformChecklist` ; critères désignés par `Kind` (`CriterionCrashFree`, `CriterionReviews`, `CriterionChangelog`), plus par position |
| Format | `FormatPts` : « +16 pts », « −5 pts », « +1 pt », « 0 pt » (arrondi à l'entier, signe moins typographique, « pts » dès 2) |
| Fixtures | `contracts/a2ui/genesis/v1/examples/act2-*.jsonl` et `correction-ios-*.jsonl` (un `updateDataModel` par surface), égales aux messages émis par les agents ([p-fn-catalog](catalog.md), [p-ar-app-channel-contract](../architecture/app-channel-contract.md)) |
| Décision (009, 2026-10-30) | `Dataset.Decision(action)` lit `decisions` de `dataset.json` (statut « Bloquée » / « Validée » et verbe « bloquée » / « validée ») ; `Load` exige les libellés (`TestLoadRequiresDecisionLabels`), une action inconnue est refusée ; titre et boutons de la Barre d'actions lus dans `actionBar` ; le composeur Livraison émet des messages **égaux** aux fixtures `act2-actions`, `act3-block` et `act3-validate` |
