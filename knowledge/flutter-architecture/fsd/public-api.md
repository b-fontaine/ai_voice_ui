---
id: arch-fsd-public-api
title: FSD — public API d'une slice (index) et cross-imports @x
tags: [fsd, public-api, barrel, encapsulation]
status: verified
updated: 2026-10-26
sources: [https://feature-sliced.design/docs/reference/public-api, https://feature-sliced.design/docs/guides/migration/from-v2-0]
links: [arch-fsd-layers, arch-fsd-dart-mapping, arch-import-lint]
---
# Chaque slice expose un contrat ; le reste est privé

Une slice expose un **public API**, en général un fichier index qui ré-exporte ses éléments. C'est « un contrat entre un groupe de modules et le code qui l'utilise ».

**Règles :**
- Exposer **uniquement le nécessaire**.
- Éviter `export *` : on perd la lisibilité du contrat, et on fait fuiter des internes dont d'autres dépendront.
- Imports **relatifs à l'intérieur** d'une slice, **absolus entre slices** (alias).
- Dans `shared/ui` et `shared/lib`, préférer **un index par composant ou lib** à un index global.
- Cross-imports entre entités : notation standardisée **`@x`** depuis v2.1. Exemple : `entities/A/@x/B` est l'API que A expose spécifiquement à B. À limiter au strict minimum.

**Transposition Dart (opinion) :**
- L'index devient le fichier de librairie du package ou de la slice, avec des `export ... show X, Y;` explicites.
- Le privé va dans `lib/src/`. La convention Dart (`implementation_imports`) signale déjà les imports de `src/` d'un autre package.

```dart
// packages/features/voice_agent/lib/voice_agent.dart
export 'src/ui/voice_button.dart' show VoiceButton;
export 'src/model/voice_session_cubit.dart' show VoiceSessionCubit, VoiceSessionState;
```

⚠️ Pièges
- La doc FSD note que les fichiers index facilitent les imports circulaires et que trop d'index ralentissent le serveur de dev (contexte JS). En Dart, éviter de même un barrel global : un barrel par slice, avec `show`.
