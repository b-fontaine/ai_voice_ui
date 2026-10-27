---
id: test-bdd-hooks-steps
title: bdd_widget_test — hooks et steps réutilisables
tags: [bdd, hooks, steps, reuse]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/bdd_widget_test]
links: [test-bdd-build-yaml, test-bdd-app-running-fixture, test-bdd-feature-syntax]
---
# Partager steps et cycle de vie entre features

## Steps prédéfinis (v3.0.4, extrait de la liste de 20)
- `The app is running`
- `I see {..} text` et `I don't see {..} text`
- `I see {..} widget`, `I see exactly {..} {..} widgets`
- `I tap {..} text` et `I tap {..} icon`
- `I enter {..} into {..} input field`
- `I dismiss the page`
- `I wait`
- `The screen matches golden {..}` : compare à `goldens/<name>.png`, écrit les diffs dans `failures/`

## Réutilisation
- **Steps locaux :** générés une seule fois dans `step/` (ou `stepFolderName`), éditables, regroupables en sous-dossiers.
- **Steps partagés entre packages :** `externalSteps` dans `build.yaml` ou dans un `bdd_options.yaml` publié par un package `*_test_kit`. Les autres packages l'importent via `include:`.
- **Convention proposée (opinion) :** un package `voice_test_kit` fournit :
  - les fakes (runner voix, transport A2UI)
  - les steps métier (`the voice agent says {..}`, `the voice agent calls show_screen with {..}`)

## Hooks (`addHooks: true`)
Fichier généré : une classe abstraite `Hooks` à méthodes statiques (`FutureOr<void>`), dans `./hook` par défaut :
- `beforeAll()` et `afterAll()` : sans argument.
- `beforeEach(String title, [List<String>? tags])`
- `afterEach(String title, bool success, [List<String>? tags])` : appelé même en cas d'échec.
(signatures lues dans `lib/src/hook_file.dart` de la 3.0.4)
- Usage : réinitialiser la DI (`getIt.reset()`), les `MockInterceptor` et les fakes globaux.

## ⚠️ Pièges
- La logique d'un hook est invisible dans le `.feature`. Y mettre uniquement de la technique (reset), jamais une précondition métier : celle-ci va dans `Background`.
