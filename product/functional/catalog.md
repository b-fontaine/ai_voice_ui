---
id: p-fn-catalog
title: Catalogue de composants
area: functional
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p10, product/sources/product-description.pdf#p11, product/sources/design-example.pdf]
links: [p-fn-business-rules, p-fn-mockups, p-fn-dataset, p-fn-screen, pdr-0007-closed-catalog-stage-theme, p-rm-open-questions, genui-custom-catalog-item, genui-catalog-ids, genui-a2ui-security, ux-genui-catalog-as-ds, ux-genui-errors-validation, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action]
tags: [catalogue, composants, a2ui, genui, theme]
---
# Catalogue de composants

**En bref.** L'IA compose **uniquement** avec un catalogue fermé. Elle choisit quels composants afficher et avec quelles données, mais leur apparence est définie à l'avance. C'est le message clé du talk : le développeur garde la main sur le rendu (fiche § 7, p. 10). Décisions : principe [pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md) ; contenu [pdr-0014](../decisions/pdr-0014-six-component-catalog.md) (6 composants, E2 · Q-02 et E21 · Q-60 tranchés) ; mise en page par l'app [pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md) (pas de `Grid`).

## Le catalogue retenu (référence, 6 composants)

Noms de la fiche, comportement des maquettes ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)).

| Composant | Agent | Actes | Comportement |
|---|---|---|---|
| **Indicateur clé** | Qualité | 1, 2 | Muté à l'acte 2 pour afficher l'écart avec la 3.3 |
| **Courbe de tendance** | Qualité | 1, 2 | Mutée à l'acte 2 : séries 3.3 / 3.4 et ligne de seuil |
| **Sentiment des avis** | Voix du client | 1, 2 | Répartition positifs / négatifs + 3 extraits (fiche) ; muté à l'acte 2 pour comparer les versions (maquette 3) |
| **Checklist go/no-go** | Livraison | 1, 3 | Passe à « Bloquée » à l'acte 3 (RG-28) ; ligne « Changelog validé · 37 PR » |
| **Barre d'actions** | Livraison | 3 | « Bloquer la release » (RG-28) et « Valider la release » (RG-30, [pdr-0016](../decisions/pdr-0016-validate-release-action.md)) |
| **Liste des crashs** | Qualité | aucun | Dans le catalogue, hors scénario principal : l'IA la choisit selon la demande. Données à écrire (point ouvert, [p-fn-dataset](dataset.md)) |

Écartés : Comparatif de versions (la comparaison passe par la mutation des surfaces existantes), En-tête de release (version et statut visibles par le titre du canevas et la checklist), Timeline des maquettes. `Grid` n'est pas un composant : l'app place les surfaces ([pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)). La limite « 6 » (surfaces ou composants) reste ouverte : Q-04.

## Historique : les 8 composants de la fiche (§ 7)

*Table source, conservée pour mémoire ; le catalogue retenu est ci-dessus.*

| Composant | Ce qu'il affiche | Ce que l'utilisateur peut faire | Acte |
|---|---|---|---|
| **En-tête de release** | Numéro de version, date cible, statut global (en préparation, prête, bloquée) | Lire uniquement | 1 |
| **Indicateur clé** | Une valeur, sa tendance et son seuil (taux de sessions sans crash, note moyenne) | Demander le détail à la voix | 1, 2 |
| **Courbe de tendance** | L'évolution d'un indicateur, avec comparaison possible entre deux versions | Demander une autre période ou plateforme | 1, 2 |
| **Liste des crashs** | Les crashs les plus fréquents, avec plateforme et volume | Filtrer par plateforme à la voix | 1, 2 |
| **Sentiment des avis** | La répartition des avis positifs et négatifs, avec 3 extraits | Demander les avis d'une plateforme | 1, 2 |
| **Comparatif de versions** | Ce qui a changé entre deux versions (fonctionnalités, correctifs) | Lire uniquement | 2 |
| **Checklist go/no-go** | Les critères de release et leur statut (validé, à risque, bloquant) | Lire ; le statut évolue après une action | 1, 3 |
| **Barre d'actions** | Les décisions possibles : « Bloquer la release », « Valider la release » | Cliquer ; l'IA confirme à la voix | 3 |

## Règles fonctionnelles du catalogue (fiche § 7)

| Règle (fiche) | RG |
|---|---|
| L'IA ne peut pas inventer de composant hors de ce catalogue. Une demande impossible est refusée à la voix, avec une alternative. | RG-07, RG-08 |
| Les couleurs et tailles de texte viennent du thème de scène, jamais de l'IA. | RG-09 |
| Si un composant reçoit des données incomplètes, il affiche un état neutre plutôt qu'une erreur, et la démo continue. | RG-10 |
| Chaque composant possède un état squelette, visible pendant sa construction. | RG-02 |

Détails : [p-fn-business-rules](business-rules.md).

⚠️ Les interactions vocales de la colonne « Ce que l'utilisateur peut faire » (détail d'un indicateur, autre période ou plateforme, filtre des crashs, avis d'une plateforme) ne sont portées par aucune FR, RG, scénario ni jalon : leur place dans le MVP est ouverte (Q-61). « Valider la release » : tranché (RG-30, pdr-0016).

## Historique : le catalogue des maquettes (6 composants)

*Conservé pour mémoire ; E2 et E21 sont tranchés par pdr-0014.*

L'étagère des maquettes affiche 6 composants, avec leur type A2UI quand il est visible :

| Libellé maquette | Type A2UI visible | Surface (maquette) | Correspondance **apparente** avec la fiche |
|---|---|---|---|
| Carte KPI | `KpiCard` | `s-kpi` | Indicateur clé |
| Courbes | `LineChart` (puis `LineChart v2`) | `s-crash-trend` | Courbe de tendance |
| Liste d'avis | `ReviewList` | `s-reviews` | Sentiment des avis — ⚠️ la fiche décrit une répartition positifs / négatifs avec 3 extraits ; la maquette 2 montre une liste, la maquette 3 trois segments (négatif, neutre, positif) et un seul thème (E21 · Q-60) |
| Checklist | — | `s-decision` | Checklist go/no-go |
| Timeline | `Timeline` | `s-changelog` | aucune (proche de Comparatif de versions ?) |
| Bouton d'action | — | `s-decision` | Barre d'actions |
| *(racine)* | `Grid` (`board`, 2 colonnes) | `release-3-4` | aucune |

Sans équivalent dans les maquettes : **En-tête de release**, **Liste des crashs**, **Comparatif de versions**. Le `catalogId` visible est `genesis.release` (maquette 1).

La correspondance ci-dessus est une lecture de l'assistant, gardée pour mémoire ; la décision est pdr-0014. Voir [p-fn-mockups](mockups.md), [p-rm-open-questions](../roadmap/open-questions.md).

## Repères techniques (knowledge)

- Un composant de catalogue genui = nom + schéma JSON + `widgetBuilder` : [genui-custom-catalog-item].
- Le `catalogId` est un contrat entre agent et client : [genui-catalog-ids].
- Le catalogue est une liste blanche et une frontière de sécurité : [genui-a2ui-security].
- Traiter le catalogue comme une partie du design system : [ux-genui-catalog-as-ds].
- Erreurs de validation et états dégradés : [ux-genui-errors-validation].
