---
id: arch-clean-flutter-layers
title: Clean Architecture en Flutter — domain / data / presentation
tags: [clean-architecture, flutter, repository, use-case, entity]
status: sourced
updated: 2026-10-26
sources: [https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html, https://docs.flutter.dev/app-architecture/guide]
links: [arch-clean-dependency-rule, arch-dto-mappers, arch-either-vs-result, arch-official-use-cases, proj-avw-overview, proj-sk-overview, rt-provider-abstraction]
---
# Découpage Clean usuel en Flutter (convention communautaire)

| Couche | Contenu | Dépend de |
|---|---|---|
| `domain/` | entities (`freezed`, pur Dart), **repositories abstraits**, use-cases, failures | rien (ni Flutter, ni `dio`) |
| `data/` | data sources (remote/local), DTO + mappers, implémentations des repositories | `domain` |
| `presentation/` | Bloc/Cubit (ou ViewModel), pages, widgets | `domain` (+ DI) |

```dart
// domain
abstract interface class VoiceSessionRepository {
  Stream<VoiceEvent> get events;
  Future<Result<void>> start(SessionConfig config);
}
final class StartVoiceSession {           // use-case appelable
  const StartVoiceSession(this._repo);
  final VoiceSessionRepository _repo;
  Future<Result<void>> call(SessionConfig c) => _repo.start(c);
}
```

**Correspondance avec le guide officiel :**

| Officiel | Clean |
|---|---|
| Service | DataSource |
| Repository (abstrait + impl) | idem |
| Use-case optionnel | Use-case |
| ViewModel | Bloc |

La différence principale : Clean place l'interface du repository **dans `domain`** (inversion de dépendance).

**Chez Septeo :** les deux projets suivent `data/domain/presentation` et ajoutent un **Interactor** entre Bloc et domaine (`proj-avw-overview`, `proj-sk-overview`).

⚠️ Pièges
- `domain` ne doit importer ni `package:flutter`, ni un SDK IA (`firebase_ai`, `flutter_webrtc`). À vérifier par lint (`arch-import-lint`).
- Use-case « pass-through » systématique : du boilerplate sans valeur (`arch-official-use-cases`).
- Couches horizontales globales dans une seule app : la frontière entre features est invisible. Voir `arch-fsd-layers`.
