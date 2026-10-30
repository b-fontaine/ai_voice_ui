---
id: pdr-0053-client-side-a2ui-validation-from-007
title: "PDR-0053 — Validation A2UI côté client dès 007, catalogue fermé `genesis` en liste blanche"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/006-j3-act1-backend/status.md, knowledge:genui-a2ui-security]
links: [p-rm-open-questions, p-ar-security, p-ar-frontend, p-ar-app-channel-contract, p-fn-catalog, pdr-0007-closed-catalog-stage-theme, genui-a2ui-security]
tags: [pdr, decision, securite, a2ui, catalogue]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0053 — Validation A2UI côté client dès 007, catalogue fermé `genesis` en liste blanche

> **En bref.** Tranche Q-71. L'app valide chaque message A2UI contre le catalogue fermé `genesis` dès la fonctionnalité 007, en plus de l'orchestrateur (« deux fois »).

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Q-71 : [p-ar-security](../architecture/security.md) prévoit une validation « deux fois : orchestrateur puis client » et exclut `BasicCatalogItems` complet ([pdr-0007](pdr-0007-closed-catalog-stage-theme.md)). En J2 seul l'orchestrateur valide ; le client décode seulement. 006 a livré le contrat `genesis` ([p-fn-catalog](../functional/catalog.md)).

## Hypothèses
- ✅ Le catalogue `genesis` (4 composants en J3, contrat `contracts/a2ui/genesis/v1/`) existe côté contrat depuis 006.

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** : dès 007 (J3-B), le catalogue fermé `genesis` sert de liste blanche **dans l'app**, en plus de l'orchestrateur ; un composant ou une propriété hors catalogue est refusé côté client. `security.md` est corrigé en conséquence.

## Raisons
- Défense en profondeur sans attendre la fin de J3 ; la liste blanche existe déjà côté contrat.
- Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ».

## Options écartées
- (b) validation côté client avec la liste blanche provisoire `Column,Text`, à refaire en J3 : double travail (option du registre).

## Conséquences
- [p-ar-security](../architecture/security.md) : validation côté client planifiée en 007, plus « ouverte ».
- [p-rm-roadmap](../roadmap/roadmap.md) J3 : Q-71 levée.

## Réexaminer si
- le catalogue `genesis` change de forme de façon incompatible (nouvelle version du `catalogId`).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ». Tranche Q-71. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
