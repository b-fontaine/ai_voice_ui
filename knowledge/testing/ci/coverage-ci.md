---
id: test-coverage-ci
title: Coverage et CI — flutter test --coverage, very_good test
tags: [coverage, ci, very_good_cli, lcov]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/very_good_cli, https://cli.vgv.dev/docs/commands/test]  # + `flutter test --help` (Flutter 3.47.8)
links: [test-very-good-analysis, test-golden-alchemist, test-integration-test, proj-sk-patterns]
---
# Mesurer et imposer la couverture en CI

- **Flutter seul :** `flutter test --coverage` écrit `coverage/lcov.info` (défaut de `--coverage-path`, confirmé par `flutter test --help` en Flutter 3.47.8). Aussi : `--branch-coverage`, `--merge-coverage`. Rapport HTML : `genhtml coverage/lcov.info -o coverage/html` (paquet `lcov`).
- **very_good_cli 1.5.0** (publiée le 2026-09-08) :
  ```bash
  dart pub global activate very_good_cli
  very_good test -r --coverage --min-coverage 90 \
    --exclude-coverage "**/*.g.dart **/*.freezed.dart **/*.config.dart" \
    --test-randomize-ordering-seed random -x e2e
  ```

## Flags de `very_good test`
- `--coverage` et `--min-coverage <pct>` : fait échouer le job sous le seuil.
- `--exclude-coverage` : globs séparés par des espaces.
- `--[no-]optimization` : activé par défaut, désactivé automatiquement avec `--platform` ; un fichier s'en exclut avec le tag `skip_very_good_optimization`.
- `--collect-coverage-from` : `imports` (défaut) ou `all`.
- `-r` : packages imbriqués (monorepo des agents).
- `-t` / `-x` : tags inclus et exclus.
- `-j` : concurrence (4 par défaut).
- `--update-goldens`.

## Pipeline proposé (opinion)
1. `dart format --set-exit-if-changed .` puis `flutter analyze`.
2. `dart run build_runner build -d` (bdd_widget_test, injectable).
3. `very_good test -r --coverage --min-coverage` (unit, widget, BDD et CI goldens).
4. Job nocturne : `patrol test` ou `integration_test` sur émulateur.

## ⚠️ Pièges
- L'optimisation regroupe les fichiers de test dans un même runner (fonctionnement connu, la doc dit seulement « performance optimizations ») : désactiver, ou taguer `skip_very_good_optimization`, si des tests partagent un état global (`getIt`).
- Les fichiers de plateforme exclus via `// coverage:ignore-file` (cf. `proj-sk-patterns`) doivent rester minces.
