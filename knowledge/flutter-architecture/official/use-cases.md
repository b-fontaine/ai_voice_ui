---
id: arch-official-use-cases
title: Use-cases optionnels — quand les ajouter
tags: [flutter, architecture, domain, use-case, official]
status: verified
updated: 2026-10-28
sources: [https://docs.flutter.dev/app-architecture/guide, https://docs.flutter.dev/app-architecture/recommendations]
links: [arch-official-layers, arch-clean-flutter-layers, arch-clean-fsd-combo]
---
# Use-cases : « seulement quand c'est nécessaire »

Le guide officiel classe la couche domaine en **Conditional**. On extrait un use-case (aussi appelé *interactor*) seulement si la logique remplit au moins une de ces conditions :
- elle fusionne les données de **plusieurs repositories** ;
- elle est très complexe ;
- elle est **réutilisée** par plusieurs ViewModels.

Un use-case est « une simple classe utilitaire aux entrées et sorties bien définies ».

**Relations :**
- Use-case ↔ Repository : n-n.
- Un ViewModel peut dépendre à la fois de use-cases **et** de repositories en direct. Le guide n'impose pas de tout faire passer par un use-case.

| Pour | Contre |
|---|---|
| moins de duplication entre ViewModels | plus de classes, plus de charge cognitive |
| testabilité, lisibilité | plus de mocks, plus de boilerplate |

**Cas d'un orchestrateur multi-agents (opinion) :** il remplit les trois critères :
- il combine la session voix, la surface GenUI et le contexte métier ;
- il est complexe ;
- il est partagé.

Il justifie donc des use-cases explicites (par exemple « router une intention utilisateur », « déléguer l'UI à l'agent GenUI »). Pour un CRUD simple, on reste sans use-case.

⚠️ Pièges
- La Clean Architecture « dogmatique » (un use-case par appel de repository) contredit la recommandation officielle. saaster_kit le fait déjà (`proj-sk-overview`) : à n'appliquer que là où c'est utile.
