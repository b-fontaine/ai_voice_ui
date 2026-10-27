---
id: arch-result-pattern
title: Pattern Result officiel (sealed Ok/Error)
tags: [flutter, error-handling, result, sealed-class, official]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/app-architecture/design-patterns/result, https://pub.dev/packages/result_dart]
links: [arch-either-vs-result, arch-error-handling, arch-command-pattern]
---
# Result<T> : rendre les erreurs explicites dans les signatures

En Dart, les exceptions ne sont pas déclarées dans les signatures, et une exception oubliée remonte jusqu'à l'UI. La doc officielle recommande donc que les services et les repositories **retournent un `Result`** au lieu de lever une exception.

```dart
sealed class Result<T> {
  const Result();
  factory Result.ok(T value) => Ok(value);
  factory Result.error(Exception error) => Error(error);
}
final class Ok<T> extends Result<T> { const Ok(this.value); final T value; }
final class Error<T> extends Result<T> { const Error(this.error); final Exception error; }

// ViewModel / Cubit : la gestion des deux cas est exhaustive (sealed)
switch (await repo.getUserProfile()) {
  case Ok(:final value): profile = value;
  case Error(:final error): this.error = error;
}
```

**Avantages :**
- Le compilateur force le traitement de l'erreur.
- Les fallbacks se chaînent simplement : API, puis cache, puis erreur.
- Le `try/catch` reste confiné au service.

**Alternatives pub.dev citées par la doc :** `result_dart` (v2.2.0 observée le 2026-10-26, `AsyncResult`, `fold`/`map`/`flatMap`), `result_type`, `multiple_result`.

⚠️ Pièges
- La classe `Error<T>` masque `dart:core` `Error`. Préfixer l'import ou renommer (`Failure`).
- `Exception` est un type trop large. Pour un domaine riche, typer l'échec avec une union `freezed` (`arch-error-handling`).
