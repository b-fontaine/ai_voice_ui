---
id: arch-official-layers
title: Guide officiel Flutter — couches UI et Data (+ domaine optionnel)
tags: [flutter, architecture, mvvm, official]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/app-architecture/guide]
links: [arch-official-components, arch-official-use-cases, arch-official-recommendations, arch-clean-flutter-layers]
---
# Deux couches obligatoires, une optionnelle

La séparation des responsabilités est « le principe le plus important » du guide officiel : une app Flutter se découpe en **couche UI** et **couche Data**, avec une **couche domaine** (use-cases) optionnelle. Le guide se présente comme des lignes directrices, pas des règles strictes.

| Couche | Contenu | Rôle |
|---|---|---|
| UI | Views + ViewModels (MVVM) | afficher l'état, recevoir les interactions |
| Domain (optionnel) | Use-cases (= interactors) | logique complexe, multi-repositories ou réutilisée |
| Data | Repositories + Services | source de vérité, accès aux données externes |

**Flux unidirectionnel :**
- Services (données brutes) → Repositories (modèles de domaine) → [Use-cases] → ViewModels (état UI) → Views.
- Les interactions remontent par des **commands** du ViewModel.

**Cardinalités :**
- View ↔ ViewModel : 1-1. Le guide définit une *feature* par ce couple.
- ViewModel ↔ Repository : n-n.
- Repository ↔ Service : n-n.
- **Les repositories ne se connaissent jamais entre eux.**

⚠️ Pièges
- Le guide ne parle ni de BLoC ni de Clean Architecture. Le « ViewModel » officiel est un `ChangeNotifier`, mais un Cubit/Bloc tient le même rôle (cf. projets Septeo, `proj-avw-overview`).
- Le dossier `domain/` du guide contient des **modèles**, pas forcément des use-cases.
