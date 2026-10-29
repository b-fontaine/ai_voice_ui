---
id: p-fn-mockups
title: Maquettes (illustration) et différences avec la fiche
area: functional
status: draft
updated: 2026-10-29
sources: [product/sources/design-example.pdf, product/sources/product-description.pdf]
links: [pdr-0002-desktop-platform, adr-0001-initial-constraints, adr-0004-ds-visual-base-m3, p-fn-screen, p-fn-catalog, p-fn-dataset, p-fn-personas-journey, p-fn-business-rules, p-rm-open-questions, pdr-0007-closed-catalog-stage-theme, pdr-0008-single-screen-show-the-making, genui-a2ui-overview, genui-a2ui-messages, genui-multiple-surfaces, test-bdd-feature-syntax, pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0019-six-limit-applies-to-surfaces, pdr-0020-act1-four-surfaces, pdr-0021-mockup-data-not-corrected, pdr-0022-gherkin-steps-no-leading-digit, pdr-0024-act2-android-only, pdr-0025-top-bar-speaker-and-ai-lines, pdr-0026-desktop-only-target]
tags: [maquettes, design, ecarts, a2ui]
---
# Maquettes (design-example.pdf) : illustration de la vision

**En bref.** Trois maquettes haute fidélité, thème sombre violet, montrent la démo à trois moments : canevas vide, construction de l'acte 1, transformation de l'acte 2. Ce sont des **illustrations de la vision** du porteur, pas une spécification ([pdr-0017](../decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md)). Leurs différences avec la fiche (E1 à E22) sont listées plus bas ; la fiche l'emporte.

## Structure commune

Bandeau : « Genesis Canvas · Release Copilot », pastille d'état micro (« EN ÉCOUTE »), forme d'onde, transcription entre guillemets, mention « A2A · A2UI · GenUI », compteur d'étape « n / 3 · NOM ». En dessous : rail « AGENTS A2A » à gauche (légende actif / en veille), « CANEVAS » au centre, « FLUX A2UI · live » à droite (repliable), étagère « CATALOGUE · n / 6 utilisés » en bas.

## Maquette 1 — « 1 / 3 · VIDE »

| Zone | Contenu |
|---|---|
| Transcription | « Prépare la release 3.4 » (curseur de saisie) |
| Rail | Orchestrateur « planifie · 4 tâches » ; Crash, Avis stores, Changelog, Captures d'écran « en veille » |
| Canevas | `release-3-4`, 0 surface ; cadre pointillé « board · Grid · 0 enfant » ; grand orbe micro au centre ; « L'orchestrateur planifie la release 3.4 » ; « plan A2A → 4 tâches · 0 / 4 agents mobilisés » |
| Flux | #01 `beginRendering` (surfaceId `release-3-4`, root `board`, catalogId `genesis.release`) ✓ reçu ; #02 `surfaceUpdate` « EN RENDU → board » (`Grid`, 2 colonnes, `explicitList` vide) ; « 2 messages · A2UI v0.8 · 612 o » |
| Étagère | 0 / 6 utilisés |

## Maquette 2 — « 2 / 3 · CONSTRUCTION »

| Zone | Contenu |
|---|---|
| Transcription | « Prépare la release 3.4 » → orchestrateur · 3 agents |
| Rail | Orchestrateur « délègue · 3 tâches » ; Crash « actif · 9 msg » ; Avis stores « actif · 1 284 avis » ; Changelog « actif · 37 PR » ; Captures d'écran « en veille » ; liaisons pointillées |
| Canevas | « 4 surfaces · 3 en génération » : `s-kpi` KpiCard « Sessions sans crash » (badge Rendu) ; `s-crash-trend` LineChart « Taux de crash » iOS/Android (badge « Données 6/7 », ← #15) ; `s-reviews` ReviewList « Avis des stores » (badge Squelette, « attend /reviews ») ; `s-changelog` Timeline « Changelog 3.4 » (badge Nouvelle, 1 / 5 entrées) |
| Flux | #13 `surfaceUpdate` ✓ s-reviews ; #14 `beginRendering` ✓ s-changelog ; #15 `dataModelUpdate` EN RENDU (`s-crash-trend`, `/series/android`) ; « 15 messages · A2UI v0.8 · 8,4 ko » |
| Étagère | 4 / 6 : Carte KPI ×1 s-kpi, Courbes ×1 en rendu, Liste d'avis ×1, Timeline ×1 nouveau |

Badges de surface observés : **Rendu**, **Données n/m**, **Squelette**, **Nouvelle**, **Muté**, **Nouvelle · génération**. Ils illustrent RG-02 (3 temps) et RG-06 (mutation).

## Maquette 3 — « 3 / 3 · TRANSFORMATION »

| Zone | Contenu |
|---|---|
| Transcription | « Concentre-toi sur Android et compare avec la 3.3 » |
| Rail | Orchestrateur « re-planifie · Android » ; Crash « actif · 3.3 ↔ 3.4 » ; Avis stores « actif · Android » ; Changelog et Captures « en veille » |
| Canevas | Puces de filtre « ✓ Android », « iOS », « ✓ Comparer 3.3 ↔ 3.4 » ; « 3 mutées · 1 en génération · 1 retirée » ; courbe Android 3.3 vs 3.4 (Muté, LineChart v2, `filtre platform=android`, seuil go) ; « Sans crash · Android » 99,39 % (Muté) ; « Avis Android » 37 % vs 18 % négatifs (Muté) ; « Décision go/no-go · 3.4 » (Nouvelle · génération) avec checklist, « NO-GO Android » et bouton « Bloquer la release » + un second bouton en squelette |
| Flux | Replié (bandeau vertical « FLUX A2UI », compteur 57, « surfaceUpdate → s-decision ») |
| Étagère | 5 / 6 : Carte KPI, Courbes, Liste d'avis mutés ; Checklist ×1 en rendu ; Timeline retirée ; Bouton d'action ×2 en rendu |

## Différences avec l'illustration

> **Règle** ([pdr-0017](../decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md), 2026-10-29, remplace la consigne « tout laisser ouvert ») : la **fiche produit fait foi** ; une différence fiche/maquette n'est pas une question, la fiche l'emporte. Fiche muette : la maquette n'est qu'une inspiration et n'impose rien. Point technique (version A2UI, noms de messages, ids de surfaces, `Grid`, `catalogId`, `LineChart v2`…) : la maquette ne compte pas ; seuls les faits vérifiés et les décisions décident. Les décisions déjà acceptées (pdr-0013 à pdr-0016) restent valables telles quelles.

Le registre garde ses identifiants (E1 à E22) et le renvoi à la `Q-xx` d'origine, dont la clôture suit la règle ci-dessus ([p-rm-open-questions](../roadmap/open-questions.md)).

| Id | Q | Écart | Fiche | Maquettes / autre source |
|---|---|---|---|---|
| E1 | Q-01 | Agents | 3 : Qualité, Voix du client, Livraison (§ 3) | 4 : Crash, Avis stores, Changelog, Captures d'écran ; « planifie · 4 tâches » — **tranché** : [pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md) (noms de la fiche, sélection visible, nombre libre) |
| E2 | Q-02 | Catalogue | 8 composants (§ 7) | 6 (Carte KPI, Courbes, Liste d'avis, Checklist, Timeline, Bouton d'action) + racine `Grid` ; voir [p-fn-catalog](catalog.md) — **tranché** : [pdr-0014](../decisions/pdr-0014-six-component-catalog.md) (6 composants, noms de la fiche, comportement des maquettes) |
| E3 | Q-03 | Version A2UI | Non précisée ; la base knowledge vise genui 0.10 / A2UI **v0.9** (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`) [genui-a2ui-messages], v0.8 = legacy [genui-a2ui-overview] | Messages **v0.8** : `beginRendering`, `surfaceUpdate`, `dataModelUpdate` ; « A2UI v0.8 » — **tranché** : [pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md) (décision contrainte : A2UI v0.9, genui 0.10.4 ; la mention v0.8 de l'illustration est sans portée) |
| E4 | Q-04 | « 6 » | Au plus 6 **surfaces** visibles (§ 3, NFR-06) | « n / 6 utilisés » compte les **composants** du catalogue — **tranché** : [pdr-0019](../decisions/pdr-0019-six-limit-applies-to-surfaces.md) (décision contrainte : la limite porte sur les surfaces visibles ; pas de compteur de composants) |
| E5 | Q-05..Q-09 | Hypothèses | Raccourcis « proposés, à valider » (Q-05) ; durée du talk (Q-06), OS de démo (Q-07), nom de l'app (Q-08), gabarit SDD (Q-09) non fixés | — |
| E6 | Q-10 | Agent tiers | Question ouverte : agent d'un autre éditeur ? (§ 3) | Absent |
| E7 | Q-20 | Bouton « Bloquer la release » | Barre d'actions en acte 3 (§ 7) | Visible dès la transformation (maquette 3), dans une surface Décision go/no-go |
| E8 | Q-21 | Transformation | « Les surfaces existantes restent à leur place » (S-02, FR-07) | « 3 mutées · 1 en génération · **1 retirée** » (Timeline) + nouvelle surface Décision go/no-go |
| E9 | Q-22 | Actes vs étapes | 3 actes : Créer, Transformer, Interagir (+ Rejouer) (§ 2) | Indicateur « 1 / 3 · VIDE », « 2 / 3 · CONSTRUCTION », « 3 / 3 · TRANSFORMATION » ; aucune maquette de l'acte 3 |
| E10 | Q-28 | Composition de l'acte 1 | En-tête de release et Checklist marqués acte 1 (§ 7) | Acte 1 = KPI, courbe, avis, changelog ; ni en-tête ni checklist — **tranché** : [pdr-0020](../decisions/pdr-0020-act1-four-surfaces.md) (décision contrainte : Indicateur clé, Courbe de tendance, Sentiment des avis, Checklist go/no-go) |
| E11 | Q-29 | Modèle de surfaces | « surfaces » (6 max) | Une surface `release-3-4` à racine `Grid` (maquette 1), puis des surfaces distinctes `s-*` (maquette 2) [genui-multiple-surfaces] — **tranché** : [pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md) (grille fixe tenue par l'app, N surfaces, pas de `Grid` dans le catalogue) |
| E12 | Q-30 | État de l'orbe | « Réflexion » quand les agents travaillent ; orbe dans la barre supérieure (§ 6) | Pastille « EN ÉCOUTE » pendant planification et construction ; grand orbe au centre du canevas vide |
| E13 | Q-31 | Zone Rejeu et flux | 6 zones dont Rejeu ; flux « replié par défaut » (§ 6) | Aucune zone Rejeu ; flux déplié (maquettes 1-2), replié (3) |
| E14 | Q-32 | Filtres | Non décrits (ni zone ni composant) | Puces Android / iOS / Comparer 3.3 ↔ 3.4 : chrome de l'app ou UI générée ? |
| E15 | Q-33 (et Q-23) | Cohérence des données | — | Courbe Android J7 0,82 % vs 99,39 % sans crash (0,61 %) ; « 4 tâches » puis « 3 tâches » ; voir [p-fn-dataset](dataset.md) — **tranché** : [pdr-0021](../decisions/pdr-0021-mockup-data-not-corrected.md) (décision contrainte : illustration non corrigée ; jeu de référence cohérent via Q-23) |
| E16 | Q-34 | Gherkin et outil | Steps « Et 4 surfaces sont complètes… », « Soit 2 surfaces sur 4… » ; 2 fonctionnalités dans un bloc (§ 4) | `bdd_widget_test` : un step commençant par un chiffre fait échouer le build [test-bdd-feature-syntax] — **tranché** : [pdr-0022](../decisions/pdr-0022-gherkin-steps-no-leading-digit.md) (décision contrainte : steps reformulés en toutes lettres, bdd_widget_test conservé) |
| E17 | Q-35 | Statuts | Checklist : validé / à risque / bloquant ; en-tête : en préparation / prête / bloquée ; S-03 : « le statut de la checklist passe à Bloquée » | Checklist : ✓ / ✗ seulement ; recommandation « NO-GO Android » |
| E18 | Q-36 (lié à Q-18) | Persistance | Pas de persistance au-delà de la session (§ 3) | Le mode secours rejoue une session enregistrée **avant** le talk (FR-10) |
| E19 | Q-58 | Acte 2 : périmètre Android | S-02 : « Et les données affichées concernent uniquement Android » (§ 4, FR-07) | Maquette 3 : la surface « Décision go/no-go · 3.4 » garde le critère « Sans crash iOS ≥ 99,5 % · 99,71 » ; la puce de filtre « iOS » reste affichée (non cochée) — **tranché** : [pdr-0024](../decisions/pdr-0024-act2-android-only.md) (décision contrainte : uniquement Android, checklist comprise) |
| E20 | Q-59 | Répliques de l'IA dans la barre supérieure | Les répliques du speaker **et de l'IA** s'affichent en direct ; une réplique coupée est tronquée (§ 6, FR-19) | Maquettes 1-3 : seule la phrase du speaker est affichée, aucune réplique de l'IA — **tranché** : [pdr-0025](../decisions/pdr-0025-top-bar-speaker-and-ai-lines.md) (décision contrainte : speaker et IA, réplique coupée tronquée) |
| E21 | Q-60 | Sentiment des avis | « La répartition des avis positifs et négatifs, avec 3 extraits » (§ 7) | Maquette 2 : `ReviewList` « Avis des stores » (une liste) ; maquette 3 : barre en 3 segments (négatif, neutre gris, positif) et un seul « thème n°1 · 212 mentions », sans 3 extraits — **tranché** : [pdr-0014](../decisions/pdr-0014-six-component-catalog.md) (version de la fiche : répartition + 3 extraits, plus la comparaison entre deux versions de la maquette 3) |
| E22 | Q-64 | Plateformes cibles | Desktop : macOS prioritaire, Windows en secours (§ 1, [pdr-0002](../decisions/pdr-0002-desktop-platform.md)) | ADR hérités de `knowledge/`, contexte d'origine : « web, mobile et desktop » ([adr-0001-initial-constraints]) et « desktop et web » ([adr-0004-ds-visual-base-m3]) — **tranché** : [pdr-0026](../decisions/pdr-0026-desktop-only-target.md) (décision contrainte : desktop seul ; ADR et notes orientés web sans effet sur la cible) |

E1 à E6 sont les écarts connus du porteur ; E7 à E9 ont été relevés en rédigeant la roadmap ; E10 à E18 en rédigeant le fonctionnel ; E19 à E21 lors de la revue de fidélité ; E22 lors du nettoyage de `knowledge/` (2026-10-28). Les questions Q-28 à Q-36, Q-58 à Q-60 et Q-64 figurent dans le registre [p-rm-open-questions](../roadmap/open-questions.md).
