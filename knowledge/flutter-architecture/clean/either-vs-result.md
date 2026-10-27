---
id: arch-either-vs-result
title: Either (fpdart) vs Result — quel type d'échec
tags: [error-handling, either, result, fpdart, functional]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/fpdart, https://github.com/SandroMaglione/fpdart, https://pub.dev/packages/result_dart, https://docs.flutter.dev/app-architecture/design-patterns/result]
links: [arch-result-pattern, arch-error-handling]
---
# Either<L, R> ou Result<T> ?

La Clean Architecture « à la Reso Coder » utilise `Either<Failure, T>`, historiquement de `dartz`. Depuis les sealed classes de Dart 3, un `Result` sealed maison suffit, et c'est l'approche officielle Flutter.

| Option | Version pub.dev (2026-10-26) | Remarque |
|---|---|---|
| `Result` maison (doc Flutter) | — | zéro dépendance, `switch` exhaustif |
| `result_dart` | 2.2.0 | `Result<S>` (échec = `Exception` par défaut), `ResultDart<S,F>`, `AsyncResult` |
| `fpdart` | 1.2.0 (≈ oct. 2025), 2.0.0-dev.3 (≈ 2024) | `Either`, `TaskEither`, `Option` ; README GitHub : v2 « prévue pour rester en pré-release » |
| `dartz` | — | non vérifié ; déclaré mais inutilisé dans ai_voice_widget (`proj-avw-risks`) |

**Recommandation (opinion) :**
- Utiliser un `Result<T, F extends Failure>` sealed maison dans `shared`, ou `result_dart`, plutôt que fpdart. fpdart a une API large, et sa v2 est figée en dev.
- `F` est une union `@freezed` de failures par domaine.
- Les extensions `map`/`flatMap` s'écrivent en 20 lignes.

⚠️ Pièges
- Ne pas mélanger `Either` et `Result` dans le même codebase.
- Un `Result` dont l'erreur est typée `Exception` perd l'exhaustivité métier.
