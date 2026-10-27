---
id: bloc-no-cubit
title: Règle projet — Bloc uniquement, Cubit interdit
tags: [bloc, rule, cubit, traceability, lint]
status: opinion
updated: 2026-10-26
sources: [https://bloclibrary.dev/bloc-concepts/, https://bloclibrary.dev/lint-rules/prefer_bloc/, https://pub.dev/packages/bloc_lint, https://pub.dev/packages/bloc, https://github.com/felangel/bloc/blob/master/packages/bloc_lint/lib/recommended.yaml]
links: [bloc-event-transformers, bloc-observer, bloc-emit-foreach, bloc-sealed-freezed, bloc-packages-versions, test-bloc-test]
---
# Règle : on utilise `Bloc`, jamais `Cubit`

**Décision projet :** toute logique d'état passe par une classe qui étend `Bloc<Event, State>` avec des events scellés. `Cubit` est interdit, même pour un état « simple ».

**Pourquoi (arguments tirés de la doc officielle bloc) :**
1. **Traçabilité.** Bloc donne « the sequence of state changes as well as exactly what triggered those changes ». `onTransition` et `BlocObserver.onEvent`/`onTransition`/`onDone` n'existent que pour Bloc. Dans une app multi-agents (orchestrateur, voix, GenUI), savoir **quel événement** (tool call, VAD, action utilisateur) a provoqué un état est indispensable pour déboguer.
2. **Transformations d'événements.** Seul Bloc accepte un `EventTransformer` par handler (`restartable`, `droppable`…). C'est vital pour les flux audio et les commandes vocales concurrentes (→ [[bloc-event-transformers]]).
3. **Contrat d'API.** Les events forment une API publique scellée et typée, sérialisable dans les logs. Avec Cubit, n'importe quelle méthode publique devient une API.
4. **Homogénéité.** Un seul style de code pour les humains et pour les agents IA qui génèrent du code.

**Coût accepté :** plus de verbosité (une classe d'event par action). La doc reconnaît que Cubit est « more concise ».

**Mise en application :**
```yaml
# analysis_options.yaml (bloc_lint 0.4.3)
include: package:bloc_lint/recommended.yaml
bloc:
  rules:
    - prefer_bloc        # signale tout Cubit (absent de recommended.yaml)
    # avoid_public_bloc_methods est déjà dans recommended.yaml
```
Exécuter `dart pub global activate bloc_tools`, puis `bloc lint .` en CI.

## ⚠️ Pièges
- La doc décrit `prefer_bloc` comme « purely a stylistic rule ». C'est un choix d'équipe, pas une exigence technique.
- Le skill `flutter-scaffold-feature` propose « BLoC ou Cubit ». Dans ce projet, toujours choisir Bloc.
