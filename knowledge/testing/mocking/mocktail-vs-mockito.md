---
id: test-mocktail-vs-mockito
title: mocktail vs mockito
tags: [mock, mocktail, mockito, pub.dev]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/mocktail, https://pub.dev/packages/mockito]
links: [test-mocktail-essentials, test-mock-boundaries-only, test-bloc-mockbloc-whenlisten]
---
# Choisir mocktail : aucune génération de code

Versions observées sur pub.dev le 2026-10-26 :
- **mocktail 1.0.5** (éditeur felangel.dev, publiée le 2026-04-10). Les mocks s'écrivent à la main (`class MockX extends Mock implements X {}`), sans build_runner.
- **mockito 5.8.1** (publiée le 2026-08-06). Le README désigne `@GenerateNiceMocks` comme l'API recommandée, avec génération via `dart run build_runner build`.

| Critère | mocktail | mockito |
|---|---|---|
| Codegen | non | oui (recommandé) |
| Syntaxe | `when(() => x.f())` | `when(x.f())` |
| Arguments custom avec `any()` | `registerFallbackValue` | géré par le code généré |
| Cohérence avec bloc_test | `MockBloc` repose sur mocktail | — |

## Recommandation (opinion)
mocktail, pour trois raisons :
- un projet qui utilise déjà build_runner (bdd_widget_test, injectable) n'a pas besoin de fichiers `.mocks.dart` en plus : et ajouter des fichiers `.mocks.dart` alourdit la boucle `watch` ;
- l'écosystème bloc_test est aligné sur mocktail ;
- les fakes écrits à la main restent préférés pour les frontières à flux (cf. `test-mock-boundaries-only`).

## ⚠️ Pièges
- Ne pas importer les deux librairies dans un même fichier : les noms `when`, `any` et `verify` entrent en conflit (conflit d'imports Dart, pas une règle documentée).
