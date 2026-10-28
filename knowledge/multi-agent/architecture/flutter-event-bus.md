---
id: ma-flutter-event-bus
title: État partagé et bus d'événements côté Flutter (patron)
tags: [multi-agent, flutter, bloc, streams, recommendation]
status: opinion
updated: 2026-10-28
sources: [https://pub.dev/packages/flutter_bloc, https://pub.dev/packages/genui, https://github.com/flutter/genui/tree/main/packages/genui]
links: [proj-avw-genui-bridge, proj-avw-risks, ma-target-architecture, di-get-it-scopes, test-realtime-fake-runner, bloc-emit-foreach, bloc-no-non-serializable-state, rt-provider-abstraction]
---
# Un bus d'événements typé, un BLoC par préoccupation

**Patron :** un bus d'événements d'agents (domaine) expose un `Stream<AgentEvent>` broadcast. `AgentEvent` est une `sealed class`, par exemple :
- `VoiceStateChanged(listening | speaking | thinking)`
- `TranscriptDelta(role, text)`
- `DelegationStarted(id)`, `DelegationProgress(id, msg)`, `DelegationCompleted(id)`
- `SurfaceAdded(surfaceId)`, `SurfaceRemoved(surfaceId)`, `ErrorEvent(...)`

**Producteurs :** le runner vocal, le client orchestrateur, le canal A2UI.
**Consommateurs :** les BLoC de l'UI, l'observabilité, les tests.

- Un Bloc par préoccupation : par exemple un Bloc de session vocale (état de session, micro) et un Bloc de conversation (transcription).
- Les identifiants de délégation en vol permettent d'afficher « je regarde… » à l'écran.
- **L'état GenUI reste hors du BLoC.** `SurfaceController` et `Conversation` de `genui` gèrent leur propre état non sérialisable. Le BLoC ne garde que la liste des `surfaceId`, comme dans [[proj-avw-genui-bridge]].
- Les actions utilisateur sur une surface (`onSubmit`) remontent à l'orchestrateur, pas au modèle vocal directement. Le modèle vocal en est informé par du contexte silencieux.

**Implémentation :**
- Le bus est un singleton à portée de session : un scope get_it ([[di-get-it-scopes]]) recréé à chaque session. Cela évite le bug « dispose puis redémarrage impossible ».
- Un seul `StreamController.broadcast()`. Pas de `MergeStream` recréé à chaque accès.

⚠️ Pièges (repris de [[proj-avw-risks]])
- Annuler les abonnements dans `close()`.
- Émettre réellement l'état `thinking`/`processing`.
- Ne jamais appeler `getIt` dans `build`.

Versions observées le 2026-10-26 : `flutter_bloc` 9.1.1, `bloc` 9.2.1, `rxdart` 0.28.0, `genui` 0.10.4.
