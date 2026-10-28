---
id: pdr-0007-closed-catalog-stage-theme
title: "PDR-0007 — Catalogue de composants fermé ; apparence par le thème de scène, jamais par l'IA"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p10, product/sources/product-description.pdf#p11, product/sources/design-example.pdf, knowledge:ux-genui-catalog-as-ds, knowledge:genui-a2ui-security, knowledge:genui-custom-catalog-item, knowledge:ux-genui-errors-validation]
links: [pdr-0014-six-component-catalog, p-fn-catalog, p-fn-business-rules, p-fn-nfr, p-fn-mockups, p-ar-frontend, p-ar-agents-protocols, p-rm-open-questions, pdr-0003-use-case-release-copilot, pdr-0008-single-screen-show-the-making, pdr-0011-adopt-knowledge-adrs, adr-0004-ds-visual-base-m3, adr-0005-ds-tokens-style-dictionary, ux-genui-catalog-as-ds, genui-a2ui-security, genui-custom-catalog-item, ux-genui-errors-validation, genui-catalog-ids]
tags: [pdr, decision, catalog, theme, genui, a2ui]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0007 — Catalogue fermé et thème de scène

> **En bref.** L'IA compose uniquement avec un catalogue fermé de composants déclarés par le développeur ; leurs couleurs et tailles de texte viennent du thème de scène, jamais de l'IA. C'est le message clé du talk. Le principe est acté ; le **contenu exact** du catalogue est arbitré par [pdr-0014](pdr-0014-six-component-catalog.md) (6 composants).

Part de l'assistant : mise en forme de la fiche ; liens vers knowledge.

## Contexte
- Fiche § 7 (p. 10) : « L'IA compose uniquement avec ces 8 composants. Elle choisit lesquels afficher et avec quelles données, mais leur apparence est définie à l'avance. C'est le message clé pour le public. »
- Fiche § 3 « Hors périmètre » : « Génération de widgets hors catalogue ».
- Côté knowledge : le catalogue A2UI doit refléter le design system ; l'agent n'envoie que des indications sémantiques, jamais de styles [ux-genui-catalog-as-ds] ; le catalogue est la liste blanche de sécurité d'A2UI [genui-a2ui-security].

## Hypothèses
- ✅ Les 4 règles fonctionnelles du catalogue (fiche § 7, ci-dessous).
- ⚠️ Écart E2 non tranché : fiche = 8 composants (En-tête de release, Indicateur clé, Courbe de tendance, Liste des crashs, Sentiment des avis, Comparatif de versions, Checklist go/no-go, Barre d'actions) ; maquettes = 6 (Carte KPI, Courbes, Liste d'avis, Checklist, Timeline, Bouton d'action) plus un `Grid` racine (« board ») → [p-rm-open-questions](../roadmap/open-questions.md) (Q-02), [p-fn-catalog](../functional/catalog.md).
- ⚠️ Écart E4 non tranché : « au maximum 6 surfaces visibles » (fiche § 3, NFR-06) ; « 4 / 6 utilisés » dans la maquette porte sur le catalogue → [p-rm-open-questions](../roadmap/open-questions.md) (Q-04).

## Options
Aucune alternative documentée dans la source, hormis la génération hors catalogue, exclue.

## Décision
**Règles du catalogue** (fiche § 7) :
1. L'IA ne peut pas inventer de composant hors catalogue. Une demande impossible est refusée **à la voix**, avec une alternative.
2. Les couleurs et tailles de texte viennent du **thème de scène**, jamais de l'IA.
3. Un composant qui reçoit des données incomplètes affiche un **état neutre** plutôt qu'une erreur ; la démo continue.
4. Chaque composant possède un **état squelette** visible pendant sa construction (cf. FR-04).

Le thème de scène impose au minimum un texte de 24 px et un contraste WCAG AA (NFR-05, fiche § 8).

## Raisons
- Fiche § 1 et § 7 : c'est le message du talk (« le développeur Flutter garde la main sur le rendu via son catalogue »).
- Fiche § 8, risque « L'IA produit un écran incohérent » : parade « Catalogue restreint ».
- Fiche § 8, risque « Texte illisible au projecteur » : parade « Thème de scène en 24 px minimum ».

## Options écartées
- **Génération de widgets hors catalogue** : hors périmètre, fiche § 3.
- **Style piloté par l'IA** : exclu par la règle 2 (fiche § 7) ; côté A2UI, les composants du Basic Catalog ignorent de toute façon le `theme` envoyé par l'agent [ux-genui-catalog-as-ds].

## Conséquences
- **Architecture front** : chaque `CatalogItem` enveloppe un composant `Ds*` qui lit `ThemeData`/`ThemeExtension` [ux-genui-catalog-as-ds], [genui-custom-catalog-item] ; base M3 via `material_ui` [adr-0004-ds-visual-base-m3] ; thème de scène généré depuis les tokens DTCG [adr-0005-ds-tokens-style-dictionary] → [p-ar-frontend](../architecture/frontend.md).
- **Protocole** : l'identifiant du catalogue est négocié et figé pour la vie d'une surface [genui-catalog-ids] ; la maquette n° 1 montre `catalogId: "genesis.release"` → [p-ar-agents-protocols](../architecture/agents-protocols.md).
- **Erreurs** : la règle 3 rejoint les pièges de validation A2UI [ux-genui-errors-validation].
- **Écran** : l'étagère du catalogue allume le composant utilisé (FR-06) → [pdr-0008-single-screen-show-the-making](pdr-0008-single-screen-show-the-making.md).
- **Roadmap** : la liste des composants doit être arbitrée (E2, Q-02) avant d'écrire les `CatalogItem` → [p-rm-backlog](../roadmap/backlog.md).

## Réexaminer si
- Le porteur arbitre E2 : mettre à jour [p-fn-catalog](../functional/catalog.md) et consigner l'arbitrage dans un nouveau PDR.
- Une démonstration de composant hors catalogue devient un objectif du talk (contre-exemple pédagogique).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 3, § 7) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR ; écarts E2 et E4 signalés | Assistant (mise en forme) |
| 2026-10-29 | Contenu du catalogue arbitré par [pdr-0014](pdr-0014-six-component-catalog.md) (6 composants, Q-02) ; principe inchangé | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
