---
id: perf-bloc-scoped-rebuilds
title: BLoC — limiter les rebuilds (buildWhen, BlocSelector, context.select)
tags: [bloc, rebuild, buildWhen, BlocSelector, flutter_bloc]
status: verified
updated: 2026-10-26
sources:
  - https://bloclibrary.dev/flutter-bloc-concepts/
  - https://pub.dev/packages/flutter_bloc
links: [perf-avoid-rebuilds, perf-audio-visualizer-60hz, proj-avw-overview, bloc-providers-selector]
---
# Ne reconstruire que sur le morceau d'état qui change

Version : `flutter_bloc` **9.1.1**, la dernière sur pub.dev au 2026-10-26 (publiée en 2025-05).

```dart
// 1. Filtre explicite
BlocBuilder<VoiceBloc, VoiceState>(
  buildWhen: (prev, curr) => prev.status != curr.status,
  builder: (context, state) => StatusChip(state.status),
);

// 2. Projection : rebuild seulement si la valeur sélectionnée change (==)
BlocSelector<VoiceBloc, VoiceState, bool>(
  selector: (s) => s.isSpeaking,
  builder: (context, speaking) => MicIcon(active: speaking),
);

// 3. Dans un petit widget feuille
final name = context.select((ProfileBloc b) => b.state.name);
```

- `listenWhen` est l'équivalent pour les effets de bord dans `BlocListener`.
- La valeur sélectionnée doit être **immuable** et comparable. Avec `@freezed`, l'égalité est générée.
- Éviter `context.select` ou `context.watch` à la racine d'un gros `build` : isoler dans un `Builder` ou un `BlocSelector`.

## ⚠️ Pièges
- **Ne jamais faire transiter l'audio ou le niveau RMS à 60 Hz par l'état du BLoC.** Chaque émission déclenche des comparaisons et des rebuilds, ce qui produit du jank. Le BLoC porte l'état métier (idle, recording, speaking) ; les données haute fréquence passent par `ValueListenable` ou un `Stream` lu par un painter (voir [[perf-audio-visualizer-60hz]]).
- Un `buildWhen` qui oublie un champ donne une UI figée sur un état obsolète. Préférer `BlocSelector`, typé sur ce qui est affiché.
