---
id: pdr-0030-llm-budget-20-eur
title: "PDR-0030 — Budget LLM total de 20 € pour l'ensemble des modèles"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p7, knowledge:rt-gpt-live-overview]
links: [p-fn-nfr, p-ar-security, p-ar-quality, p-ar-backend, p-rm-open-questions, pdr-0012-voice-provider-openai, rt-gpt-live-overview]
tags: [pdr, decision, cout, budget, nfr-11]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0030 — Budget LLM : 20 €

> **En bref.** Le porteur fixe un **budget total de 20 € pour l'ensemble des modèles** (GPT-Live et LLM texte des agents). Tranche Q-13 sur le montant. Le plafond par session et par répétition de NFR-11 et son mécanisme sont des **propositions de l'assistant**, dérivées de ce budget, non décidées.

Part de l'assistant : consignation ; propositions dérivées (voir ci-dessous).

## Contexte
- NFR-11 (fiche § 5) : « Coût d'une répétition complète connu et plafonné », sans montant (Q-13).
- GPT-Live : 0,05 $/min facturé à la seconde ; LLM texte facturé à part [rt-gpt-live-overview].

## Hypothèses
- ✅ Montant donné par le porteur, qui l'appuie sur une expérience comparable (environ 10 € pour une présentation du saaster kit).
- Le porteur n'a pas précisé ce que couvre le budget (talk seul, ou aussi développement et répétitions). Par prudence, l'assistant suit toute la consommation ; ce n'est pas une hypothèse de la décision.
- Le coût par répétition sera mesuré (`usage.seconds` journalisé, [p-ar-quality](../architecture/quality.md)) ; ce n'est pas une hypothèse de la décision.

## Options
Aucune alternative documentée : le porteur a fixé le montant.

## Décision
- Budget total : **20 €** pour tous les modèles (voix et texte).

Propositions de l'assistant, **non décidées** (dérivées du budget, révisables sans PDR) : un plafond par session et par répétition (NFR-11), fixé après la première mesure de coût (J2) ; un plafond configurable côté backend (`limits.budget`, `limits.max_session_s`) et la journalisation de la consommation par session.

## Raisons
- Parole du porteur (2026-10-29) : « Pour les modèles LLM, j'ai un budget de 20€. ça devrait suffire pour l'ensemble des modèles. J'ai déjà fait ce genre de présentation (pour le saaster kit) et ça m'a couté la moitié de ce montant. »

## Options écartées
- Aucune.

## Conséquences
- [p-fn-nfr](../functional/nfr.md) : NFR-11 précisé (budget total 20 € ; plafond par répétition proposé par l'assistant), texte de la fiche inchangé.
- [p-ar-security](../architecture/security.md), [p-ar-backend](../architecture/backend.md) : plafond injecté par configuration (proposition).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-13 tranchée.

## Réexaminer si
- La consommation mesurée projette un dépassement des 20 € avant le talk.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « j'ai un budget de 20€. ça devrait suffire pour l'ensemble des modèles » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Revue : périmètre « développement, répétitions et talk compris » retiré (non dit par le porteur) ; plafond par session de NFR-11 et `limits.*` requalifiés en propositions de l'assistant | Assistant |

Pas d'archive brute.
