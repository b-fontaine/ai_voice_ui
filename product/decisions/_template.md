---
# Gabarit de décision produit (PDR). Copier ce fichier en pdr-NNNN-<slug>.md,
# NNNN = next_id de decisions/index.yaml (format pdr-NNNN, jamais réutilisé), puis incrémenter next_id.
# Ce fichier est exclu du lint : son id est factice.
id: pdr-0000-template
title: "PDR-0000 — <Titre de la décision, formulé comme un choix>"
area: decisions
status: proposed           # validated = acceptée | proposed = proposée | superseded = remplacée ou abandonnée
updated: 2026-10-28
sources: []                # ex. product/sources/product-description.pdf#p3, knowledge:rt-barge-in
links: []                  # ids product (p-*, pdr-*) et knowledge (adr-*, rt-*, genui-*…)
tags: [pdr, decision]
decision_status: proposée  # acceptée | proposée | remplacée par pdr-XXXX | abandonnée
decided_on: 2026-10-28     # date de la décision (ou de la proposition si proposée)
decided_by: "<Nom (rôle)>, <canal : fiche produit, conversation, réunion…>"
# Décision contrainte uniquement : decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
# et constraint_basis (ids des faits vérifiés et décisions qui imposent la réponse ; obligatoire dans ce cas) :
# constraint_basis: [genui-a2ui-overview, pdr-0008-single-screen-show-the-making]
scope: fonctionnel         # fonctionnel | technique | mixte
supersedes: []             # ids des PDR que celle-ci remplace
superseded_by: null        # id du PDR qui la remplace, le cas échéant
---
# PDR-0000 — <Titre>

> **En bref.** <2-3 lignes : ce qui est décidé, par qui, et ce que ça change.>

<!-- Part de l'assistant : préciser ici s'il a recommandé, mis en forme ou seulement consigné,
     ou s'il s'agit d'une décision contrainte (prise sur délégation, contestable par le porteur). -->

## Contexte
<!-- Le problème, la contrainte ou la question. Citer la source (§ / page de la fiche, maquette n°,
     id de note knowledge). Pas de fait technique sans id de note. -->

## Hypothèses
<!-- Une ligne par hypothèse. -->
- ✅ <hypothèse confirmée> (source)
- ⚠️ Hypothèse non confirmée : <…> → [p-rm-open-questions](../roadmap/open-questions.md) (Q-xx)

## Options
<!-- Uniquement des options réellement envisagées dans une source. Sinon :
     « Aucune alternative documentée dans la source ». -->
1. **<Option retenue>**
2. <Option alternative>

## Décision
<!-- Ce qui est retenu, formulé de façon vérifiable. -->

## Raisons
-

## Options écartées
<!-- Pour chaque option : pourquoi elle est écartée, avec la source. -->
-

## Conséquences
<!-- Effets sur le fonctionnel, l'architecture et la roadmap, avec ids (p-fn-*, p-ar-*, p-rm-*, FR-xx, NFR-xx). -->
-

## Réexaminer si
<!-- Conditions observables qui doivent rouvrir la décision. -->
-

## Historique
| Date | Événement | Qui |
|---|---|---|
| AAAA-MM-JJ | Proposée / acceptée / reconfirmée / remplacée | <nom (rôle)> |

<!-- Archives : sorties brutes (panels, recherches) dans product/decisions/_archive/AAAA-MM-JJ-<slug>.md
     si elles existent ; sinon « Pas d'archive brute ». -->
