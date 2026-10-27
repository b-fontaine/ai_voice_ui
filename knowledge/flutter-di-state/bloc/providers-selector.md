---
id: bloc-providers-selector
title: BlocProvider, MultiBlocProvider, BlocSelector
tags: [bloc, flutter_bloc, widgets, performance]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/flutter_bloc, https://engineering.verygood.ventures/architecture/ffca/presentation/]
links: [di-no-service-locator, bloc-emit-foreach, bloc-no-non-serializable-state, perf-bloc-scoped-rebuilds, test-bloc-mockbloc-whenlisten]
---
# Fournir et consommer un Bloc dans l'arbre

Widgets de flutter_bloc 9.1.1 :
- `BlocProvider(create:)` **crée et ferme** le Bloc. `BlocProvider.value` **ne le ferme pas** (réservé à un Bloc existant, par exemple passé à une route).
- `MultiBlocProvider` imbrique plusieurs providers à plat. `RepositoryProvider` fournit des services.
- `BlocBuilder` reconstruit l'UI, `BlocListener` déclenche des effets ponctuels (navigation, snackbar, son), `BlocConsumer` combine les deux.
- `BlocSelector<B, S, T>` ne reconstruit que si la **valeur sélectionnée** change : « Unnecessary builds are prevented if the selected value does not change ».

```dart
// Page = composition (Page/View split, opinion)
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => getIt<OrchestratorBloc>()..add(const OrchestratorStarted())),
    BlocProvider(create: (_) => getIt<VoiceSessionBloc>()),
  ],
  child: const AssistantView(),
);

// View : sélection fine, l'onde ne reconstruit que l'indicateur
BlocSelector<VoiceSessionBloc, VoiceState, double>(
  selector: (s) => switch (s) { VoiceListening(:final level) => level, _ => 0 },
  builder: (_, level) => Waveform(level: level),
);
```

- `context.read<B>().add(...)` dans les callbacks, `context.watch`/`select` seulement dans `build`.
- VGV place les providers dans un module ou une page de feature, avec des dépendances lues via `context.read()`.

## ⚠️ Pièges
- `BlocProvider.value(value: getIt<B>())` crée une nouvelle factory à chaque build et ne la ferme jamais.
- Pour des valeurs à haute fréquence (niveau audio), même `BlocSelector` reconstruit à chaque frame. Envisager un `ValueListenable` hors Bloc pour le rendu pur (→ [[bloc-no-non-serializable-state]]).
