---
id: p-fn-dataset
title: Jeu de données fictif et figé
area: functional
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p10, product/sources/design-example.pdf]
links: [p-fn-scope, p-fn-mockups, p-fn-catalog, p-fn-business-rules, p-ar-replay, pdr-0005-frozen-fictional-dataset, p-rm-open-questions, pdr-0014-six-component-catalog, pdr-0016-validate-release-action, pdr-0020-act1-four-surfaces, pdr-0021-mockup-data-not-corrected, pdr-0024-act2-android-only, pdr-0034-app-name-release-copilot, pdr-0040-reference-dataset-adjusted-by-assistant, p-fn-feature-voice-screen-generation]
tags: [donnees, dataset, determinisme, release]
---
# Jeu de données fictif — jeu de référence

**En bref.** Jeu de référence de l'app mobile fictive **Release Copilot**, versions 3.3 et 3.4, iOS et Android, conçu par l'assistant ([pdr-0040](../decisions/pdr-0040-reference-dataset-adjusted-by-assistant.md)) : inspiré de l'illustration sans la copier, cohérent en interne, **figé et déterministe** (NFR-08, [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md)). Récit : la 3.4 passe de justesse au global, mais Android régresse nettement face à la 3.3 (flux de paiement 3-D Secure 2) → NO-GO Android. Brouillon à relire par le porteur.

## Cadre

| Élément | Valeur | Source |
|---|---|---|
| Application | **Release Copilot**, app mobile de commerce fictive | [pdr-0034](../decisions/pdr-0034-app-name-release-copilot.md), fiche § 3 |
| Versions | 3.3 (en production) et 3.4 (bêta en déploiement progressif, à décider) | fiche § 3 |
| Plateformes | iOS et Android | fiche § 4 |
| Période | 7 jours, J1 à J7 (J7 = dernier jour complet), identique pour 3.3 et 3.4 | jeu |
| Sources simulées | Sessions et crashs, avis des stores, changelog ; aucune vraie source (Crashlytics, App Store Connect, Play Console exclus) | fiche § 1, § 3 |

## Règles de calcul et seuils

| Terme | Définition |
|---|---|
| Taux de crash du jour | sessions avec crash ÷ sessions du jour (courbes) |
| Sans crash 7 j | 100 % − (Σ sessions avec crash ÷ Σ sessions) : moyenne **pondérée** par les sessions, jamais moyenne des 7 taux |
| Tendance | taux sans crash du jour J7 − celui de J1, en points (pt) |
| Avis négatif / positif | 1 à 3 ★ / 4 et 5 ★ (2 segments, version de la fiche, [pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) |
| Statut d'un critère (fiche § 7) | **validé** : seuil atteint avec marge ; **à risque** : seuil atteint, marge < 0,10 pt (sans crash) ou < 2 pts (avis) ; **bloquant** : seuil non atteint |
| Recommandation | GO si tout est validé ; À RISQUE si au moins un « à risque » et aucun bloquant ; NO-GO si au moins un bloquant |
| Seuil go sans crash | **≥ 99,50 %** sans crash sur 7 j, soit **0,50 %** de taux de crash (ligne de seuil des courbes) |
| Seuil go avis | **≤ 25 %** d'avis négatifs sur 7 j |

## Séries quotidiennes (source de toutes les valeurs de stabilité)

| Jour | iOS 3.4 sessions | crashs | taux | Android 3.4 sessions | crashs | taux | Android 3.3 sessions | crashs | taux |
|---|---|---|---|---|---|---|---|---|---|
| J1 | 9 800 | 22 | 0,22 % | 12 000 | 36 | 0,30 % | 41 200 | 125 | 0,30 % |
| J2 | 10 100 | 20 | 0,20 % | 13 500 | 45 | 0,33 % | 40 800 | 116 | 0,28 % |
| J3 | 10 400 | 22 | 0,21 % | 15 000 | 60 | 0,40 % | 40 500 | 118 | 0,29 % |
| J4 | 10 600 | 20 | 0,19 % | 17 000 | 85 | 0,50 % | 40 900 | 112 | 0,27 % |
| J5 | 10 900 | 23 | 0,21 % | 19 000 | 118 | 0,62 % | 41 300 | 126 | 0,31 % |
| J6 | 11 200 | 22 | 0,20 % | 21 000 | 153 | 0,73 % | 40 600 | 116 | 0,29 % |
| J7 | 11 500 | 22 | 0,19 % | 23 500 | 197 | 0,84 % | 40 700 | 117 | 0,29 % |
| **7 j** | **74 500** | **151** | **0,20 %** | **121 000** | **694** | **0,57 %** | **286 000** | **830** | **0,29 %** |

Sessions, sessions avec crash et taux de crash du jour ; servent la **Courbe de tendance** et l'**Indicateur clé** (actes 1 et 2). La montée des sessions Android 3.4 reflète le déploiement progressif ; le taux de crash croît avec l'adoption du nouveau paiement.

## Acte 1 — « Prépare la release 3.4 » (4 surfaces, [pdr-0020](../decisions/pdr-0020-act1-four-surfaces.md))

**Indicateur clé** (agent Qualité) — sessions sans crash, 3.4, 7 j.

| Périmètre | Valeur | Tendance J1 → J7 | Seuil | Lecture |
|---|---|---|---|---|
| Global | **99,57 %** | −0,36 pt (99,73 → 99,37) | ≥ 99,50 % | atteint, marge 0,07 pt |
| iOS | **99,80 %** | +0,03 pt (99,78 → 99,81) | ≥ 99,50 % | atteint |
| Android | **99,43 %** | −0,54 pt (99,70 → 99,16) | ≥ 99,50 % | **non atteint** |

**Courbe de tendance** (agent Qualité) — taux de crash du jour, 3.4, J1 à J7, une série par plateforme (colonnes iOS 3.4 et Android 3.4 ci-dessus), ligne de seuil à 0,50 %, axe 0 à 1,0 %. Android franchit le seuil à J5.

**Sentiment des avis** (agent Voix du client) — avis 3.4 des 7 j, deux plateformes.

| Périmètre | Avis | 1★ / 2★ / 3★ / 4★ / 5★ | Négatifs | Positifs | Note moyenne |
|---|---|---|---|---|---|
| Global (affiché) | **1 164** | 156 / 64 / 57 / 285 / 602 | **24 %** (277) | **76 %** (887) | 4,0 |
| dont iOS | 372 | 16 / 8 / 13 / 95 / 240 | 10 % (37) | 90 % (335) | 4,4 |
| dont Android | 792 | 140 / 56 / 44 / 190 / 362 | 30 % (240) | 70 % (552) | 3,7 |

Trois extraits affichés (acte 1) :
1. ★☆☆☆☆ · Android — « L'app se ferme dès que je valide mon panier. Impossible de payer depuis la mise à jour. »
2. ★★★★★ · iOS — « La validation bancaire est enfin rapide, plus besoin de ressaisir ma carte. »
3. ★★☆☆☆ · Android — « Après le code reçu par SMS, retour à l'accueil et panier vide. »

**Checklist go/no-go** (agent Livraison) — 3.4, toutes plateformes.

| Critère | Seuil | Valeur | Statut |
|---|---|---|---|
| Sessions sans crash (global, 7 j) | ≥ 99,50 % | 99,57 % | à risque (marge 0,07 pt) |
| Avis négatifs (global, 7 j) | ≤ 25 % | 24 % (23,8 %) | à risque (marge 1,2 pt) |
| Changelog validé | revue faite | 37 PR | validé |
| **Recommandation** | | 2 critères à risque, aucun bloquant | **À RISQUE** · statut « En attente de décision » |

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

## Acte 3 — action sur la Barre d'actions

| Action | Agent | Statut de la checklist | Critères et recommandation |
|---|---|---|---|
| « Bloquer la release » (S-03, RG-28) | Livraison | **Bloquée** | inchangés (NO-GO Android) |
| « Valider la release » (RG-30, [pdr-0016](../decisions/pdr-0016-validate-release-action.md)) | Livraison | **Validée** | inchangés : la décision humaine prime sur la recommandation |

## Liste des crashs (hors scénario principal, [pdr-0014](../decisions/pdr-0014-six-component-catalog.md))

Top 5 des crashs de la 3.4 sur 7 j, deux plateformes, par volume. Volume = occurrences ; sessions touchées = sessions distinctes avec au moins une occurrence.

| # | Libellé | Plateforme | Volume | Sessions touchées |
|---|---|---|---|---|
| 1 | Plantage à la validation du panier (3-D Secure 2) | Android | 371 | 352 |
| 2 | Fermeture au retour de l'app bancaire (WebView 3-D Secure) | Android | 148 | 139 |
| 3 | Mémoire saturée à l'ouverture de la galerie photos | Android | 72 | 66 |
| 4 | Crash au démarrage à froid (migration de la base locale 3.4) | iOS | 58 | 55 |
| 5 | Plantage à l'ouverture d'une notification push | iOS | 41 | 39 |

## Changelog 3.4 (ligne « Changelog validé · 37 PR » de la checklist)

Paiement : flux 3-D Secure 2 (feat, 11 PR) · Panier : sauvegarde hors ligne (feat, 8) · Catalogue : galerie photos plein écran (feat, 7) · Base locale : migration du schéma 3.4 (refactor, 6) · Correctifs notifications et accessibilité (fix, 5) : **37 PR**.

## Contrôles de cohérence

| Contrôle | Calcul |
|---|---|
| Sans crash = 100 % − taux 7 j | iOS 151 / 74 500 = 0,20 % → 99,80 % ; Android 694 / 121 000 = 0,57 % → 99,43 % ; 3.3 830 / 286 000 = 0,29 % → 99,71 % |
| Global pondéré | 845 / 195 500 = 0,43 % → 99,57 % (38 % iOS × 99,80 + 62 % Android × 99,43) ; la moyenne simple des 7 taux Android (0,53 %) n'est pas utilisée |
| Écart Android | 99,43 − 99,71 = −0,28 pt (valeurs exactes : −0,283) |
| Avis | 37 + 240 = 277 négatifs ; 372 + 792 = 1 164 ; chaque répartition somme à 100 % |
| Top 5 crashs ≤ sessions avec crash | Android 352 + 139 + 66 = 557 ≤ 694 sessions avec crash ; iOS 55 + 39 = 94 ≤ 151 |
| Tendances | J1 global = 58 / 21 800 ; J7 global = 219 / 35 000 ; signes cohérents avec les courbes |

## Différences avec l'illustration et points ouverts

- Valeurs des maquettes (99,53 %, 99,39 %, 1 284 avis, 37 % vs 18 %, 212 mentions…) **non reprises** ([pdr-0021](../decisions/pdr-0021-mockup-data-not-corrected.md), [pdr-0040](../decisions/pdr-0040-reference-dataset-adjusted-by-assistant.md)) ; écarts détaillés dans [p-fn-mockups](mockups.md). Les identifiants techniques (surfaces, chemins du data model) relèvent de l'architecture, pas des maquettes ([pdr-0017](../decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md)).
- ⚠️ Hypothèse non confirmée : libellés du statut global (« En attente de décision », « Bloquée », « Validée ») et recommandation « À RISQUE », en attente de Q-35 ([p-rm-open-questions](../roadmap/open-questions.md)). Les statuts des critères suivent la fiche § 7. Moment d'apparition de la Barre d'actions : Q-20 (ouverte). Stockage et relecture : [p-ar-replay](../architecture/replay.md).
