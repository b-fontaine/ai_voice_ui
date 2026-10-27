---
id: bloc-packages-versions
title: Écosystème bloc — packages et versions
tags: [bloc, flutter_bloc, versions, freezed, bloc_test, bloc_concurrency, bloc_lint]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/bloc, https://pub.dev/packages/flutter_bloc, https://pub.dev/packages/bloc_concurrency, https://pub.dev/packages/bloc_test, https://pub.dev/packages/bloc_lint, https://pub.dev/packages/freezed, https://pub.dev/packages/freezed/changelog]
links: [bloc-no-cubit, bloc-sealed-freezed, bloc-event-transformers, test-bloc-test, di-setup-versions]
---
# Packages bloc : versions observées le 2026-10-26 sur pub.dev

| Package | Version | Rôle |
|---|---|---|
| `bloc` | **9.2.1** | noyau : `Bloc`, `Emitter`, `BlocObserver`, `EventTransformer` |
| `flutter_bloc` | **9.1.1** (dépend de `bloc ^9.0.0`, `provider ^6`) | widgets : `BlocProvider`, `BlocBuilder`, `BlocSelector`… |
| `bloc_concurrency` | **0.3.0** | transformers `sequential`, `droppable`, `restartable`, `concurrent` |
| `bloc_test` | **10.0.0** (dev) | `blocTest`, `MockBloc`, `whenListen` |
| `bloc_lint` | **0.4.3** (dev, Dart ≥ 3.7) | règles de lint, dont `prefer_bloc` |
| `freezed` | **4.0.3** (dev, Dart SDK ≥ 3.13) + `freezed_annotation` **3.1.0** | unions scellées, `copyWith`, `==` |

```yaml
dependencies:
  bloc: ^9.2.1
  flutter_bloc: ^9.1.1
  bloc_concurrency: ^0.3.0
  freezed_annotation: 3.1.0   # freezed 4.0.3 épingle exactement cette version
dev_dependencies:
  bloc_test: ^10.0.0
  bloc_lint: ^0.4.3
  freezed: ^4.0.3
  build_runner: any
```

- ai_voice_widget utilise déjà `flutter_bloc ^9.1.1` (proj-avw-overview).
- `flutter_bloc` 9.1.1 date du 2025-05-02 (environ 18 mois), mais reste la dernière version stable observée.

## ⚠️ Pièges
- freezed est passé en **4.x** (le README renvoie aussi à un guide de migration 3.0). Vérifier le changelog avant de copier d'anciens exemples (`when`/`map` hérités).
- freezed 4.0.3 dépend de `freezed_annotation: 3.1.0` (version exacte) et exige Dart SDK ≥ 3.13. freezed 4.0.0 (2026-08-22) interdit `final` dans les paramètres de constructeur.
