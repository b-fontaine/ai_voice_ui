---
id: arch-official-recommendations
title: Les 17 recommandations officielles et leur priorité
tags: [flutter, architecture, best-practice, official]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/app-architecture/recommendations]
links: [arch-official-layers, arch-freezed, arch-go-router, arch-result-pattern, arch-command-pattern]
---
# Recommandations officielles (docs.flutter.dev, consultées le 2026-10-26)

**Strongly recommend**
- Couches Data et UI clairement définies.
- Pattern repository dans la couche data.
- MVVM (ViewModel + View) dans la couche UI.
- Pas de logique dans les widgets.
- Flux de données unidirectionnel.
- Modèles de données immuables.
- Injection de dépendances : le guide cite `provider` et veut éviter les objets globaux.
- **Repositories abstraits**, pour avoir une implémentation par environnement.
- Tester chaque composant isolément puis ensemble.
- Écrire des **fakes**, et du code qui en tire parti.

**Recommend**
- `Command` pour les événements utilisateur.
- `freezed` ou `built_value` pour les modèles immuables (attention au coût de build).
- `go_router`, « la voie préférée pour 90 % des apps ».
- Nommage par rôle : `HomeViewModel`, `HomeScreen`, `UserRepository`, `ClientApiService`. Utiliser `ui/core/` plutôt que `/widgets`, pour éviter les collisions avec le SDK.

**Conditional**
- `ChangeNotifier`/`Listenable` : le choix du state management est une affaire de préférence.
- Couche domaine (use-cases).
- Modèles API séparés des modèles de domaine, recommandés pour les grosses apps.

**Écarts Septeo assumés (opinion) :**
- BLoC au lieu de `ChangeNotifier` (autorisé, c'est « Conditional »).
- get_it/injectable au lieu de `provider`, ce qui reste de la DI. Mais `getIt` ne doit pas être appelé dans `build` ni dans un BLoC (`proj-sk-patterns`).
