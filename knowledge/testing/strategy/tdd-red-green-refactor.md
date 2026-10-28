---
id: test-tdd-red-green-refactor
title: TDD en Flutter — cycle red/green/refactor
tags: [tdd, method, flutter]
status: opinion
updated: 2026-10-28
sources: []
links: [test-pyramid-flutter, test-mock-boundaries-only, test-bloc-test, test-bdd-widget-test]
---
# TDD : un test qui échoue avant chaque ligne de production

On écrit d'abord un test qui échoue (**red**), puis le code minimal qui le fait passer (**green**), puis on nettoie sans changer le comportement (**refactor**). On recommence un comportement à la fois.

## Application au projet multi-agents
- **Point d'entrée par couche :**
  - domaine et Bloc : `test` / `blocTest`
  - écran : `testWidgets` ou scénario `.feature`
- **Outside-in :** pour une feature utilisateur (ex. « l'agent vocal affiche l'écran demandé »), on part d'un scénario Gherkin rouge. On descend ensuite en tests unitaires rouges sur l'orchestrateur et le BLoC.
- **Taille de pas :** un seul `expect` nouveau par cycle. Le test passe au vert avec le code le plus bête possible, puis on généralise au refactor.
- **Valeurs attendues indépendantes :** les valeurs attendues sont écrites en dur dans le test, jamais recalculées avec la logique testée.
- **Refactor sous filet :** `flutter test` et `dart analyze` (very_good_analysis) doivent rester verts à chaque étape.

```dart
// RED: Orchestrator n'existe pas encore -> erreur de compilation = rouge
test('route une intention "afficher" vers l’agent GenUI', () {
  final orchestrator = Orchestrator(genUi: fakeGenUi, voice: fakeVoice);
  orchestrator.handle(const Intent.show('factures'));
  expect(fakeGenUi.requests, ['factures']);
});
```

## ⚠️ Pièges
- Écrire le test après coup en le calquant sur l'implémentation produit des tests fragiles et sans valeur de spécification.
- TDD sur du code de plateforme (WebRTC, micro) : on isole ce code derrière une interface et on fait le TDD sur le reste (cf. `test-realtime-fake-runner`).
