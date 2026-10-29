---
id: pdr-0014-six-component-catalog
title: "PDR-0014 — Catalogue de 6 composants, noms de la fiche, comportement des maquettes"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p10, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-catalog, p-fn-scope, p-fn-mockups, p-fn-glossary, p-fn-screen, p-fn-dataset, p-fn-business-rules, p-ar-frontend, p-ar-agents-protocols, p-rm-roadmap, p-rm-backlog, pdr-0007-closed-catalog-stage-theme, pdr-0013-orchestrator-visible-agent-selection, pdr-0008-single-screen-show-the-making, pdr-0019-six-limit-applies-to-surfaces, pdr-0020-act1-four-surfaces]
tags: [pdr, decision, catalog, genui, sentiment]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0014 — Catalogue de 6 composants, noms de la fiche, comportement des maquettes

> **En bref.** Tranche Q-02 (écart E2) et Q-60 (écart E21). Le catalogue compte **6 composants**, nommés comme dans la fiche et se comportant comme dans les maquettes. Il complète [pdr-0007](pdr-0007-closed-catalog-stage-theme.md), qui fixait le principe du catalogue fermé.

Part de l'assistant : recommandation et mise en forme ; la décision est du porteur.

## Contexte
Fiche § 7 : 8 composants. Maquettes : 6 (Carte KPI, Courbes, Liste d'avis, Checklist, Timeline, Bouton d'action) + racine `Grid`. Sentiment des avis : répartition positifs/négatifs avec 3 extraits (fiche), liste (maquette 2), 3 segments (maquette 3). Voir [p-fn-mockups](../functional/mockups.md) (E2, E21) et [p-fn-catalog](../functional/catalog.md).

## Hypothèses
- ✅ Les noms de la fiche sont préférés aux noms des maquettes ([pdr-0013](pdr-0013-orchestrator-visible-agent-selection.md)).
- ⚠️ Hypothèse non confirmée : les données de la Liste des crashs (top crashs, plateforme, volume) restent à écrire dans le jeu figé ([p-fn-dataset](../functional/dataset.md)).
- Q-04 (sur quoi porte la limite « 6 ») tranchée le 2026-10-29 par [pdr-0019](pdr-0019-six-limit-applies-to-surfaces.md) (surfaces visibles) ; constat d'origine : le catalogue compte maintenant 6 composants, ce qui ne tranche pas Q-04.

## Options
1. **6 composants : noms de la fiche, comportement des maquettes** (retenue)
2. 8 composants de la fiche
3. 6 composants des maquettes, avec leurs noms

## Décision
Le catalogue contient 6 composants :

| Composant | Agent | Actes | Comportement |
|---|---|---|---|
| Indicateur clé | Qualité | 1, 2 | Muté à l'acte 2 pour afficher l'écart avec la 3.3 |
| Courbe de tendance | Qualité | 1, 2 | Mutée à l'acte 2 : séries 3.3 / 3.4 et ligne de seuil |
| Sentiment des avis | Voix du client | 1, 2 | Muté à l'acte 2 pour comparer les versions |
| Checklist go/no-go | Livraison | 1, 3 | Passe à « Bloquée » à l'acte 3 |
| Barre d'actions | Livraison | 3 | Décisions possibles (cf. [pdr-0016](pdr-0016-validate-release-action.md)) |
| Liste des crashs | Qualité | aucun (scénario principal) | Présente dans le catalogue, non utilisée dans le scénario principal ; l'IA la choisit selon la demande |

**Écartés** : Comparatif de versions (à l'acte 2 la comparaison se fait en mutant les surfaces existantes) ; En-tête de release (version et statut déjà visibles par le titre du canevas et la checklist) ; Timeline des maquettes (absente de la fiche ; le changelog tient dans une ligne de la checklist, « Changelog validé · 37 PR »).

**Q-60** : Sentiment des avis = version de la fiche (répartition positifs/négatifs + 3 extraits), plus la comparaison entre deux versions montrée par la maquette 3.

## Raisons
Parole du porteur, 2026-10-29 (conversation avec l'assistant), après présentation des recommandations : « oui, enregistre tes recommandations comme décision. Je les valide. »
Cohérent avec [pdr-0013](pdr-0013-orchestrator-visible-agent-selection.md) ; met en valeur la mutation sur place (meilleure preuve de FR-07) ; noms de la fiche ; coût moindre (6 composants au lieu de 8, chacun demandant widget, schéma, squelette, état neutre, story Widgetbook, goldens, exemples de prompt) ; lisibilité de l'étagère (6 tuiles en 24 px sur 1920 px, NFR-05) ; 4 surfaces à l'acte 1 en moins de 8 s (NFR-03). La Liste des crashs montre que l'IA choisit dans un catalogue que le développeur contrôle, comme un agent en veille montre que l'orchestrateur choisit.

**Perte assumée** : la démonstration du retrait d'une surface que portait la Timeline. Le retrait reste démontrable via « Stop » (FR-16).

## Options écartées
- Option 2 : 8 composants, coût plus élevé, dont deux (En-tête, Comparatif) sans rôle dans le scénario.
- Option 3 : noms de maquettes (source de données), moins bons selon [pdr-0013](pdr-0013-orchestrator-visible-agent-selection.md).

## Conséquences
- [p-fn-catalog](../functional/catalog.md) : le catalogue retenu devient la référence ; tables fiche et maquettes conservées en historique.
- [p-fn-scope](../functional/scope.md), [p-fn-glossary](../functional/glossary.md), [p-fn-screen](../functional/screen.md), [p-fn-mockups](../functional/mockups.md) : « 8 composants » remplacé, E2 et E21 tranchés.
- [p-fn-dataset](../functional/dataset.md) : données de la Liste des crashs à écrire (point ouvert).
- [p-ar-frontend](../architecture/frontend.md), [p-ar-agents-protocols](../architecture/agents-protocols.md) : 6 `CatalogItem` ; acte 2 par mutation, sans Comparatif.
- Roadmap : dépendances Q-02 et Q-60 levées (J3, EP-04).
- Q-21 (retrait d'une surface à l'acte 2) reste ouverte ; Q-04 tranchée depuis par [pdr-0019](pdr-0019-six-limit-applies-to-surfaces.md). Composition de l'acte 1 déduite de la colonne « Actes » : [pdr-0020](pdr-0020-act1-four-surfaces.md).

## Réexaminer si
- Le public ne perçoit pas la mutation sur place à l'acte 2.
- Un besoin de démontrer le retrait d'une surface apparaît (Q-21).
- Un agent tiers apporte un composant (Q-10, Q-16).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Recommandation présentée par l'assistant | Assistant |
| 2026-10-29 | Acceptée, sur la parole « oui, enregistre tes recommandations comme décision. Je les valide. » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Q-04 tranchée par [pdr-0019](pdr-0019-six-limit-applies-to-surfaces.md) (décision contrainte : la limite « 6 » porte sur les surfaces visibles) ; décision maintenue, hypothèse ⚠️ Q-04 levée | Assistant (décision contrainte) |
| 2026-10-29 | Composition de l'acte 1 (Q-28) tranchée par [pdr-0020](pdr-0020-act1-four-surfaces.md) à partir de la colonne « Actes » ; décision maintenue | Assistant (décision contrainte) |

Pas d'archive brute.
