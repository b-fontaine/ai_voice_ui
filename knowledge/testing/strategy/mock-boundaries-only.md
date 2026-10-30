---
id: test-mock-boundaries-only
title: Ne mocker que les frontières du système
tags: [mock, fake, architecture, tdd]
status: opinion
updated: 2026-10-26
sources: []
links: [test-mocktail-vs-mockito, test-realtime-fake-runner, proj-sk-patterns, proj-avw-voice-runners, di-testing, test-flutter-real-fonts-overflow]
---
# Les doublures ne remplacent que ce qui sort du processus ou n'est pas déterministe

On ne remplace par un mock ou un fake que les **frontières** :
- réseau : HTTP, WebSocket, WebRTC
- plateforme : micro, haut-parleur, permissions
- horloge, aléatoire, stockage

La logique métier interne (orchestrateur, mappers, BLoC) est testée avec ses vraies collaboratrices.

## Frontières du projet
- **Runner voix :** l'interface `IAiRunner` (cf. `proj-avw-voice-runners`), remplacée par un fake qui pilote des `StreamController`.
- **Transport A2UI / LLM GenUI :** remplacé par un fake qui rejoue des messages JSON enregistrés.
- **Serveur de clés éphémères :** remplacé par un stub HTTP, par exemple via un environnement `@test` en DI (`proj-sk-patterns`).
- **Horloge :** `fakeAsync` et `package:clock` (cf. `test-fake-async-streams`).

## Fake ou mock ?
- **Fake :** implémentation simple et à état. À préférer pour les flux et les protocoles, car il est réutilisable entre unit, widget et BDD.
- **Mock (mocktail) :** pour vérifier une interaction ponctuelle (`verify(...).called(1)`).

## ⚠️ Pièges
- Mocker ses propres classes internes fige l'implémentation : le moindre refactor casse les tests.
- Un mock de `Stream` sans `close()` fait pendre `blocTest` et `pumpAndSettle`.
