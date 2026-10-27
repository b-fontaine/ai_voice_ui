---
id: di-no-service-locator
title: Anti-pattern — service locator dans les widgets et les blocs
tags: [di, anti-pattern, bloc, widgets, get_it]
status: opinion
updated: 2026-10-26
sources: [https://engineering.verygood.ventures/architecture/ffca/presentation/, https://bloclibrary.dev/tutorials/flutter-todos/]
links: [di-testing, bloc-providers-selector, di-registration-annotations, proj-avw-risks, proj-sk-patterns]
---
# Pas de `getIt<T>()` dans un Bloc ni dans `build`

**Règle projet :** `getIt` n'est appelé qu'à la **racine de composition**, c'est-à-dire dans le `create:` d'un `BlocProvider` au niveau page/route, ou dans le router. Les Blocs et services reçoivent leurs dépendances **par le constructeur**.

La doc bloc dit que le Bloc « relies on an instance of the repository to be injected via constructor ». VGV construit les dépendances avec Provider et `context.read()`, sans service locator.

```dart
// ✅ page = racine de composition
class VoicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<VoiceSessionBloc>()..add(const VoiceEvent.started()),
        child: const VoiceView(),
      );
}
// ❌ dans un Bloc :   final repo = getIt<AuthRepo>();
// ❌ dans un build :  final s = getIt<Service>(); s.doX();
```

**Pourquoi :**
- Les dépendances deviennent explicites dans la signature.
- Les tests se passent de conteneur (→ [[di-testing]]).
- On évite de créer une nouvelle factory à chaque rebuild.

Les deux projets Septeo violent cette règle :
- `getIt` est appelé dans `build` (proj-avw-risks #7).
- `login_bloc.dart:14` utilise un service locator (proj-sk-patterns).

## ⚠️ Pièges
- `BlocProvider(create:)` est paresseux et appelé une seule fois : c'est le bon endroit. `BlocProvider.value(value: getIt<...>())` ne ferme **pas** le Bloc.
