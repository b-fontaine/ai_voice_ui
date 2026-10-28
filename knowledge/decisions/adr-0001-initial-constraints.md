---
id: adr-0001-initial-constraints
title: "ADR-0001 — Contraintes techniques initiales imposées par le porteur du projet"
tags: [adr, decision, flutter, architecture, bloc, di, tdd, bdd]
status: opinion
updated: 2026-10-28
sources: []
links: [adr-0002-orchestrator-backend, adr-0003-backend-go, bloc-no-cubit, arch-recommended-structure]
---
# ADR-0001 — Contraintes initiales

- **Date :** 2026-10-26
- **Statut :** acceptée
- **Décideur :** porteur du projet. Ces contraintes ont été imposées dans la demande initiale et n'ont pas été évaluées par un panel.
- **Portée :** générique, avec contexte d'origine propre au projet (voir « Contexte d'origine (non générique) »).

## Décision
- **Client :** Flutter, avec des exigences de performance web, mobile et desktop (formulées dans la demande initiale).
- **Architecture :** Clean Architecture et Feature Sliced Design.
- **DI :** `get_it` + `injectable`.
- **État :** `flutter_bloc`, **Cubit interdit** (justification a posteriori dans [[bloc-no-cubit]]).
- **Méthode :** TDD, plus BDD avec `bdd_widget_test`.
- **Cible fonctionnelle :** voix temps réel voice-to-voice (GPT-Live ou Gemini Live), UI générée (`genui` / A2UI), plusieurs agents qui communiquent (orchestrateur, voix, GenUI) via des standards (A2A, A2UI, MCP).
- **Projets de référence :** `~/septeo/ai_voice_widget` et `~/septeo/septeo_saaster_kit`.

## Contexte d'origine (non générique)
Les contraintes Architecture, DI, État et Méthode sont réutilisables telles quelles. Les passages suivants décrivent le projet d'origine ; un lecteur d'un autre projet les ignore :
- **« web, mobile et desktop »** (ligne Client) : cible de plateformes du contexte d'origine, formulée dans sa demande initiale. Ce n'est pas une contrainte générique.
- **Cible fonctionnelle** (voix, `genui`/A2UI, agents A2A/MCP) : périmètre fonctionnel du projet d'origine.
- **Projets de référence** (`~/septeo/...`) : dépôts de l'organisation, utiles comme retours d'expérience (notes `proj-*`), pas comme contrainte.
- **Reprise dans `AGENTS.md`** (conséquences) : fichier du dépôt d'origine, absent si `knowledge/` est copié seul.

## Hypothèses
Aucune : ces contraintes ont été données explicitement par le porteur.

## Quand réexaminer
Seulement à la demande du porteur. L'assistant ne les remet pas en cause de lui-même.

## Conséquences
- Les notes `arch-*`, `di-*`, `bloc-*` et `test-*` détaillent l'application de ces règles.
- Elles sont reprises comme règles non négociables dans `AGENTS.md`.

## Historique
- 2026-10-28 — portée précisée lors du nettoyage de knowledge/ (porteur).
