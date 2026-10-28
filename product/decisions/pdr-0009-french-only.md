---
id: pdr-0009-french-only
title: "PDR-0009 — Conversation et interface en français uniquement"
area: decisions
status: validated
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p3, knowledge:rt-gpt-live-session-config, knowledge:rt-transcription]
links: [p-fn-scope, p-fn-requirements, p-ar-frontend, p-ar-backend, p-rm-spikes, p-rm-open-questions, pdr-0012-voice-provider-openai, rt-gpt-live-session-config, rt-transcription, rt-provider-abstraction]
tags: [pdr, decision, language, french, localization]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0009 — Français uniquement

> **En bref.** La conversation vocale, la transcription et tous les textes de l'interface sont en français, et uniquement en français. Aucune autre langue n'est prévue pour le MVP.

Part de l'assistant : mise en forme de la fiche. Aucune recommandation.

## Contexte
- Fiche § 3 « Dans le périmètre » (p. 2) : « Une conversation vocale en français avec l'IA ».
- Fiche § 3 « Hors périmètre » (p. 3) : « Localisation autre que le français ».
- Toutes les phrases clés et les scénarios BDD de la fiche sont en français (`# language: fr`, fiche § 4).

## Hypothèses
- ✅ Le talk est donné en français (déduit des phrases clés de la fiche).
- ⚠️ Hypothèse non confirmée : la qualité de compréhension et de synthèse vocale en français du fournisseur retenu, en salle bruyante. Non vérifié dans la base knowledge → spike dans [p-rm-spikes](../roadmap/spikes.md), lié à [pdr-0012-voice-provider-openai](pdr-0012-voice-provider-openai.md).

## Options
1. **Français uniquement** (retenue).
2. Autres langues : hors périmètre.

## Décision
- Langue unique : **français**, pour la voix (entrée et sortie), la transcription, les textes générés par les agents et les libellés de l'UI.
- Pas d'infrastructure de localisation exigée pour le MVP.

## Raisons
- La fiche ne détaille pas de raison. Lecture de l'assistant, à confirmer : public francophone et réduction du périmètre ([pdr-0001-conference-demo-deliverable](pdr-0001-conference-demo-deliverable.md)).

## Options écartées
- **Localisation autre que le français** : hors périmètre, fiche § 3 (p. 3).

## Conséquences
- **Configuration** : la langue de la session vocale est injectée par configuration, jamais codée en dur (AGENTS.md § 2, [rt-provider-abstraction], [rt-gpt-live-session-config]).
- **Transcription** : la barre de transcription affiche les répliques en français (FR-02, FR-19) [rt-transcription].
- **Agents** : les consignes système et les textes produits par les agents (données des composants, refus avec alternative) sont en français → [p-ar-backend](../architecture/backend.md).
- **Mots de commande** : « Stop », « annule », « Non, plutôt iOS » (FR-16, FR-17) sont des formulations françaises à tester en répétition.

## Réexaminer si
- Le talk est donné dans une conférence non francophone.
- Le spike montre une compréhension insuffisante du français par le fournisseur vocal.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 3) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR | Assistant (mise en forme) |

Pas d'archive brute.
