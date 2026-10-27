---
id: arch-error-handling
title: Gestion d'erreurs par couche (exceptions → Result → état)
tags: [error-handling, result, failure, freezed, logging]
status: opinion
updated: 2026-10-26
sources: [https://docs.flutter.dev/app-architecture/design-patterns/result]
links: [arch-result-pattern, arch-either-vs-result, arch-freezed, proj-avw-risks, ma-real-tool-results]
---
# Une règle par couche

| Couche | Ce qu'elle fait des erreurs |
|---|---|
| service / data source | `try/catch` des exceptions techniques (réseau, WebRTC, WebSocket), retour d'un `Result.error(...)` |
| repository | traduit l'erreur en **failure métier typée**, gère retry et fallback, logue avec contexte |
| use-case / Bloc | `switch` exhaustif sur le Result, émet un état `failure(...)` |
| UI | affiche l'état. Aucun `try/catch` |

```dart
@freezed
sealed class VoiceFailure with _$VoiceFailure {
  const factory VoiceFailure.micPermissionDenied() = MicPermissionDenied;
  const factory VoiceFailure.ephemeralKeyExpired() = EphemeralKeyExpired;
  const factory VoiceFailure.transport(String detail) = TransportFailure;
  const factory VoiceFailure.toolExecution(String tool, String detail) = ToolExecutionFailure;
}
```

**Flux longs (session temps réel) :**
- Les erreurs arrivent dans le `Stream<AgentEvent>` sous forme d'événement `AgentEvent.error(failure)`, plutôt que par `addError`. Le flux reste ainsi typé et ne se ferme pas.

**Erreurs d'outils :**
- Renvoyer la vraie erreur au modèle sous forme de résultat d'outil (`function_call_output` chez OpenAI, `FunctionResponse` chez Gemini).
- Ne jamais renvoyer un `{"status":"ok"}` factice (`proj-avw-risks` #5).

**Globales :**
- `FlutterError.onError` et `PlatformDispatcher.instance.onError` sont branchés sur le logging et la télémétrie (OTel chez saaster).
- Utiliser `package:logging` plutôt que `debugPrint`.

⚠️ Pièges
- Ne pas attraper `Error` (bugs de programmation) : seulement `Exception`.
- Ne pas avaler une erreur dans un repository sans log ni failure.
