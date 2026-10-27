---
id: arch-freezed
title: freezed 4.x pour entités, états et unions
tags: [freezed, immutability, sealed-class, codegen, bloc]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/freezed, https://pub.dev/packages/freezed/changelog, https://dart.dev/blog/announcing-dart-3-13, https://docs.flutter.dev/app-architecture/recommendations]
links: [arch-dto-mappers, arch-error-handling, arch-official-recommendations, proj-avw-overview, bloc-sealed-freezed]
---
# freezed : immuabilité, égalité profonde, copyWith, unions scellées

La doc Flutter **recommande** `freezed` ou `built_value` pour générer des modèles immuables. Les projets Septeo l'utilisent déjà pour les events et states BLoC (`proj-avw-overview`).

**Versions (pub.dev, 2026-10-26) :** `freezed` **4.0.3**.
- 4.0.0 (22/08/2026) :
  - supporte les **primary constructors** (stables en Dart 3.13) et analyzer 13 ;
  - **breaking** : retire `final` dans les paramètres de constructeur (le changelog le lie à Dart 3.13 ; non confirmé par l'annonce officielle Dart 3.13).
- 3.0.0 (25/02/2025) :
  - une classe freezed doit être `abstract` ou `sealed` ;
  - mode « mixte » (constructeur classique) ;
  - `when`/`map` retirés, puis remis en 3.1.0 ; le README les range sous « (Legacy) » et conseille `switch`.

```dart
@freezed
abstract class ToolCall with _$ToolCall {           // entité
  const factory ToolCall({required String id, required String name,
      required Map<String, Object?> args}) = _ToolCall;
}
@freezed
sealed class VoiceState with _$VoiceState {         // état / union
  const factory VoiceState.idle() = VoiceIdle;
  const factory VoiceState.listening() = VoiceListening;
  const factory VoiceState.speaking() = VoiceSpeaking;
  const factory VoiceState.failure(VoiceFailure f) = VoiceFailureState;
}
// consommer avec switch (pattern matching), pas when/map
```

**Usage proposé (opinion) :**
- Utiliser freezed pour les entités, les états Bloc et les failures.
- `json_serializable` seulement sur les DTO de `data/`.

⚠️ Pièges
- Le coût de build_runner croît avec le nombre de modèles (la doc Flutter le signale). Un package par feature dans le workspace limite le périmètre de régénération.
- Les objets GenUI non sérialisables ne vont pas dans un état freezed (`proj-avw-genui-bridge`).
