---
id: di-named-implementations
title: injectable — @Named pour plusieurs implémentations
tags: [di, injectable, named, voice-runner]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/injectable]
links: [di-registration-annotations, di-environments-order, proj-avw-overview, rt-provider-abstraction]
---
# `@Named` : plusieurs implémentations d'une même interface

`@Named('x')` enregistre une implémentation sous un nom. L'annotation, posée sur le paramètre du constructeur consommateur, choisit celle à injecter.

```dart
@Named('openai')
@LazySingleton(as: IAiRunner)
class OpenAiRealtimeRunner implements IAiRunner {...}

@Named('gemini')
@LazySingleton(as: IAiRunner)
class GeminiLiveRunner implements IAiRunner {...}

@injectable
class VoiceOrchestrator {
  VoiceOrchestrator(@Named('openai') this._runner);
  final IAiRunner _runner;
}
```

- `@named` (minuscule) prend le nom de la classe. `@Named.from(Type)` relit ce nom, ce qui évite les chaînes magiques.
- C'est le pattern d'ai_voice_widget pour `gemini` / `openai` (proj-avw-overview).

**Recommandation projet (opinion) :** si le fournisseur est choisi **à l'exécution** (config utilisateur, A/B), ne pas coder `@Named` en dur dans le consommateur. Injecter une petite factory `VoiceRunnerFactory.create(Provider p)` qui reçoit les deux implémentations nommées. Si le choix dépend du build, préférer `@Environment` ([[di-environments-order]]).

## ⚠️ Pièges
- Les noms sont des chaînes : une faute de frappe n'est détectée qu'au runtime. Centraliser les constantes ou utiliser `@Named.from`.
