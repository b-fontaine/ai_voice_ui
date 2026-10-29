---
id: pdr-0049-sheet-gherkin-scenarios-only
title: "PDR-0049 — Scénarios Gherkin : les 9 de la fiche, sans scénario supplémentaire"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p12, product/functional/requirements.md, product/roadmap/roadmap.md]
links: [p-rm-open-questions, p-fn-requirements, p-fn-risks-acceptance, p-fn-nfr, p-rm-backlog, p-rm-roadmap, pdr-0042-calendar-and-cut-order-validated, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0022-gherkin-steps-no-leading-digit, pdr-0033-optional-shortcuts-mouse-first, pdr-0019-six-limit-applies-to-surfaces, test-bdd-feature-syntax, test-bdd-widget-test, adr-0001-initial-constraints]
tags: [pdr, decision, bdd, gherkin, couverture, coupe]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0049 — Pas de scénario Gherkin au-delà des 9 de la fiche

> **En bref.** Tranche Q-63. La Definition of Done s'en tient aux **9 scénarios de la fiche** (§ 4) plus une revue. Aucun scénario Gherkin n'est ajouté pour FR-05, FR-06, FR-09, FR-11, FR-12. C'est la coupe **C4**, déjà pré-autorisée par [pdr-0042](pdr-0042-calendar-and-cut-order-validated.md), appliquée ici d'emblée.

Part de l'assistant : recommandation acceptée par le porteur.

## Contexte
- Fiche § 4 : 9 scénarios (S-01 à S-09) ; la DoD D1 n'exige que « les 9 scénarios » ([p-fn-risks-acceptance](../functional/risks-acceptance.md)). S-04 (bascule en mode secours) est retiré par [pdr-0032](pdr-0032-obs-video-fallback-a2ui-replay-act.md) : 8 scénarios actifs.
- Sans scénario dédié : FR-05, FR-09, FR-11 (Must), FR-06, FR-12 (Should) ([p-fn-requirements](../functional/requirements.md)). Question Q-63, liée à Q-34 ([pdr-0022](pdr-0022-gherkin-steps-no-leading-digit.md)).
- C4 de l'ordre de coupe : « pas de scénario Gherkin au-delà des 9 de la fiche ; revue visuelle », gain 0,5 j ([p-rm-roadmap](../roadmap/roadmap.md)).

## Hypothèses
- ✅ La DoD de la fiche ne demande pas de scénario pour ces exigences (fiche § 8, D1).

## Options
1. **S'en tenir aux 9 scénarios de la fiche + revue** (retenue)
2. Ajouter des scénarios pour FR-05, FR-06, FR-09, FR-11, FR-12

## Décision
- Les `.feature` de [functional/features/](../functional/features/) ne reçoivent **aucun scénario supplémentaire** pour FR-05, FR-06, FR-09, FR-11, FR-12.
- Ces exigences sont vérifiées par **revue visuelle** (et par les tests unitaires et de widgets du TDD) ; la DoD D1 reste « les scénarios de la fiche ».
- La décision ne limite que les scénarios Gherkin : TDD et tests unitaires restent exigés (AGENTS.md § 2).

## Raisons
- Gain d'environ 0,5 j dans un calendrier sans marge ([pdr-0042](pdr-0042-calendar-and-cut-order-validated.md)).
- La fiche fixe elle-même le périmètre de la DoD ; la revue couvre les exigences visuelles (FR-05, FR-06).

## Options écartées
- Ajouter des scénarios : couverture BDD plus complète des Must (FR-05, FR-09, FR-11), mais coût non prévu avant le gel ; réexaminable si le temps le permet.

## Conséquences
- [p-fn-requirements](../functional/requirements.md), [p-fn-risks-acceptance](../functional/risks-acceptance.md), [p-rm-backlog](../roadmap/backlog.md) : colonne « Scénario BDD » de FR-05/06/09/11/12 = revue, sans scénario supplémentaire.
- [p-ar-quality](../architecture/quality.md) : NFR-06 (≤ 6 surfaces) reste une assertion dans `CanvasBloc` ([pdr-0019](pdr-0019-six-limit-applies-to-surfaces.md)), sans scénario.
- [p-rm-roadmap](../roadmap/roadmap.md) : C4 acquise d'emblée ; Q-63 levée pour J2. [p-rm-open-questions](../roadmap/open-questions.md) : Q-63 tranchée → pdr-0049.

## Réexaminer si
- Du temps se libère avant le gel : ajouter un scénario pour FR-05, FR-09 ou FR-11 (Must) ;
- une régression sur l'une de ces exigences passe la revue.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée ; Q-63 tranchée (coupe C4). Parole du porteur (conversation avec l'assistant, 2026-10-29), en réponse au tableau des questions présenté juste avant : « Pour les questions, utilise tes recommandations » | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
