---
id: arch-go-router
title: go_router 18.x — navigation recommandée
tags: [go_router, routing, navigation, deep-link]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/go_router, https://pub.dev/packages/go_router/changelog, https://pub.dev/packages/go_router_builder, https://docs.flutter.dev/app-architecture/recommendations]
links: [arch-official-recommendations, arch-recommended-structure, proj-sk-patterns]
---
# go_router : « la voie préférée pour 90 % des apps » (doc Flutter)

**Versions (pub.dev, 2026-10-26) :** `go_router` **18.1.1**, `go_router_builder` **4.5.2**.

**Statut :** le package est **feature-complete**. L'équipe Flutter se concentre sur les bugs et la stabilité ; pas de développement actif de fonctionnalités, mais les contributions communautaires restent bienvenues (section Roadmap du README).

**Jalons du changelog :**
- 18.0.0 : migration vers `material_ui`/`cupertino_ui`, minimum **Flutter 3.44 / Dart 3.12**.
- 17.0.0 (breaking) : les navigations de `ShellRoute` notifient les observers de `GoRouter` par défaut (option `notifyRootObserver`).
- 16.0.0 (breaking) : changements de `GoRouteData` ; correctif : des URL ne différant que par la casse (`/Home`, `/home`) sont des routes distinctes.

**Briques utiles :**
- `redirect` (async, avec `BuildContext`) + `refreshListenable` : garde d'authentification ou de session.
- `ShellRoute` : navigateur interne. `StatefulShellRoute` (depuis 7.1.0) : préserve l'état de chaque branche, utile pour un shell persistant « assistant ».
- Routes typées : `@TypedGoRoute<LoginRoute>(path: '/login')` + `class LoginRoute extends GoRouteData with $LoginRoute`, générées par `build_runner`.

**Placement FSD (opinion) :**
- Le `GoRouter` vit dans la couche `app`.
- Chaque page expose sa route (ou sa `GoRouteData`) dans son public API.
- Le pattern modulaire de saaster (un module par feature qui ajoute ses routes, import `deferred`) est réutilisable (`proj-sk-patterns`).

⚠️ Pièges
- `AppRouter.addRoute` de saaster ne notifie pas le `ValueNotifier` (`proj-sk-patterns`).
- La surface GenUI n'est **pas** une route : c'est un widget piloté par l'agent, dans la page assistant.
