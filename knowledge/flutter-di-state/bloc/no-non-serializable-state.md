---
id: bloc-no-non-serializable-state
title: Ce qui ne doit PAS entrer dans l'état d'un Bloc
tags: [bloc, state, genui, a2ui, audio, anti-pattern]
status: opinion
updated: 2026-10-26
sources: []
links: [proj-avw-genui-bridge, bloc-emit-foreach, bloc-state-modeling, bloc-providers-selector, di-get-it-scopes, genui-voice-bridge, ma-flutter-event-bus, perf-audio-visualizer-60hz]
---
# Garder hors de l'état les objets vivants et non sérialisables

L'état d'un Bloc est un **instantané immuable et comparable** (une valeur). Un objet vivant n'a pas sa place dans l'état : il a une identité, des listeners, des ressources natives ou un état interne mutable.

**À exclure de l'état :**
- **Objets GenUI / A2UI** : `GenUiConversation`, `A2uiMessageProcessor`, host de `GenUiSurface`, catalogues. C'est la décision d'ai_voice_widget (proj-avw-genui-bridge) : non sérialisables, mutables en interne.
- `RTCPeerConnection`, `MediaStream`, sockets Live, `StreamController`, `AudioRecorder`, handles `flutter_soloud`.
- Buffers audio PCM, frames FFT brutes, `BuildContext`, `Widget`, `AnimationController`.

**Où les mettre :**
- Ils vivent dans un **service** injecté, à durée de vie de session (scope get_it, → [[di-get-it-scopes]]).
- L'état ne porte que des **références sérialisables** :
  - `surfaceIds: List<String>`, `status`, `isAiSpeaking`, `level`
  - la dernière erreur, la transcription sous forme de texte.
- L'UI rend la surface avec `GenUiSurface(host: service.host, surfaceId: id)`. Le Bloc dit **quoi** afficher, le service détient **comment**.

```dart
@freezed
abstract class AssistantState with _$AssistantState {
  const factory AssistantState({
    @Default(AssistantStatus.idle) AssistantStatus status,
    @Default(<String>[]) List<String> surfaceIds,  // ✅ ids
    // ❌ GenUiConversation conversation,
  }) = _AssistantState;
}
```

**Test rapide :** si l'état ne peut pas être `toJson()` puis rejoué dans un `blocTest` avec `seed`, il contient un objet vivant.

## ⚠️ Pièges
- `==` sur un objet vivant compare des identités : l'UI ne se reconstruit pas, ou se reconstruit à tort.
- Fermer ces objets relève du service ou du scope, jamais de `Bloc.close()` s'ils sont partagés.
