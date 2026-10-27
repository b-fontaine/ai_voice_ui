---
id: arch-command-pattern
title: Pattern Command officiel (Command0/Command1)
tags: [flutter, mvvm, command, state, official]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/app-architecture/design-patterns/command]
links: [arch-result-pattern, arch-official-components]
---
# Command : encapsuler l'état d'une action du ViewModel

Un `Command<T>` est une classe abstraite qui étend `ChangeNotifier` et enveloppe une action asynchrone. Ce n'est **pas** une classe du SDK Flutter : elle vient de l'app exemple Compass et se copie dans le projet. Il expose :
- `running`, `error`, `completed` (des `bool`)
- `result`, de type `Result<T>?` (`null` pendant l'exécution)

Il **empêche la ré-entrée** : un double tap ne déclenche pas deux appels.

**Variantes :**
- `Command0<T>` : sans argument, s'appelle avec `execute()`.
- `Command1<T, A>` : un argument, s'appelle avec `execute(a)`.

```dart
// ViewModel
late final load = Command0(_load)..execute();
// View
ListenableBuilder(
  listenable: viewModel.load,
  builder: (_, child) => viewModel.load.running
      ? const CircularProgressIndicator() : child!,
)
```

**Effets ponctuels (SnackBar, navigation) :** écouter la command, traiter le résultat, puis appeler `clearResult()`. Sinon l'effet se rejoue à chaque notification.

**Équivalent BLoC (opinion) :** chez Septeo (BLoC + freezed), le même besoin se couvre par :
- un état `@freezed` portant `status` (`idle/running/success/failure`) ;
- un transformer `droppable()` de `bloc_concurrency` contre la ré-entrée.

Le pattern Command est utile seulement si on adopte des ViewModels `ChangeNotifier`. Ne pas mélanger les deux styles dans une même feature.
