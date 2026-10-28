---
id: ds-widgetbook-4-setup
title: Widgetbook 4.0.0-beta.14 — packages, build.yaml, CLI init et Config
tags: [widgetbook, setup, codegen, build-runner, beta, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/api/packages/widgetbook, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/CHANGELOG.md, https://github.com/widgetbook/widgetbook/blob/v4/examples/full_example/build.yaml, https://github.com/widgetbook/widgetbook/blob/v4/examples/full_example/pubspec.yaml, https://github.com/widgetbook/widgetbook/blob/v4/docs/quick-start.mdx, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook_cli/lib/src/templates/main_template.dart, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/runner.dart, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/framework/config.dart, https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz, https://docs.widgetbook.io/~v4/whats-new-in-v4]
links: [adr-0008-ds-widgetbook-4-beta, ds-widgetbook-4-stories, ds-widgetbook-4-args-addons, ds-widgetbook-4-risks, ds-widgetbook-monorepo, ds-widgetbook-4-spike]
---
# En v4, un seul package `widgetbook` (générateur et tests inclus) plus `build_runner`

Au 2026-10-28 : `widgetbook 4.0.0-beta.14` (2026-09-11) exige Dart >=3.10.0 <4.0.0 et Flutter >=3.38.0. Le `latest` stable de pub.dev reste 3.25.0 : la préversion doit être demandée explicitement.

## Dépendances
- Depuis 4.0.0-alpha.5, générateur et `widgetbook_test` sont **fusionnés** dans `widgetbook`.
- **Ne pas ajouter** `widgetbook_generator` (dernière v4 : alpha.4, nov. 2025), `widgetbook_test` (alpha.3) ni `widgetbook_annotation` (aucune 4.x, dernière 3.11.0).
- Pubspec de l'exemple officiel `examples/full_example` (branche v4), copie fidèle :
```yaml
environment:
  sdk: ^3.13.0
  flutter: ^3.47.0

dependencies:
  flutter:
    sdk: flutter
  widgetbook: ^4.0.0-beta.14

dev_dependencies:
  build_runner: ^2.10.1
```
- `^2.10.1` vient de l'exemple : widgetbook n'impose pas de minimum à `build_runner`. **Projet (opinion) :** épingler la version **exacte** `widgetbook: 4.0.0-beta.14`, sans `^`. La doc v4 avertit que l'API peut casser entre versions mineures ([[ds-widgetbook-4-risks]], [[adr-0008-ds-widgetbook-4-beta]]).

## build.yaml : trois builders embarqués
- `story_builder` : `lib/**.stories.dart` → `.stories.g.dart`, en `auto_apply: dependents`. Depuis beta.1, l'extension est `*.g.dart` (et non plus `*.book.dart`).
- `components_builder` : produit `components.g.dart`, en `auto_apply: dependents`. Génération : `dart run build_runner build`.
- `telemetry` : télémétrie anonyme, en `auto_apply: root_package` (`build_to: cache`). L'exemple officiel la désactive :
```yaml
targets:
  $default:
    builders:
      widgetbook:telemetry:
        enabled: false
```

## CLI `widgetbook init` (expérimentale)
- `widgetbook_cli 4.0.0-beta.14` (2026-09-11, **Dart >=3.11**) suit le numéro de widgetbook : `dart pub global activate widgetbook_cli 4.0.0-beta.14`. La doc écrit un placeholder `{{ versions.cli }}`.
- `widgetbook init` accepte `--package`, `--output` et `--empty`. Le caractère expérimental vient d'un `logger.warn` du code source, pas de la doc.
- Elle crée un sous-dossier `widgetbook/` (projet `widgetbook_workspace`) contenant :
  - `lib/main.dart` → `runWidgetbook(config)` ;
  - `lib/widgetbook.config.dart` → `final config = Config(components: components, addons: [...])`, qui importe `components.g.dart` ;
  - `test/widgetbook_test.dart` → `await testWidgetbook(config)`, via `package:widgetbook/test.dart`.
- Sans `--empty`, elle génère aussi des `*.stories.dart` pour les widgets existants.

## Point d'entrée et `Config`
- `Widgetbook.material` n'existe plus. `runWidgetbook(Config config)` appelle `runApp(WidgetbookApp(config: config))`.
- Paramètres nommés de `Config` (beta.14) : `initialRoute='/'`, `components=const []`, `appBuilder=materialAppBuilder` (un `MaterialApp` avec `home: Material(child: child)`), `home=const DefaultHomePage()`, `addons`, `integrations`, `lightTheme`, `darkTheme`, `themeMode=ThemeMode.system`, `header`, `scrollBehavior=const MaterialScrollBehavior()`, `scenarioConfig`, `accessibilityConfig`, `docsBuilder=defaultDocsBuilder`, `foldersExpandedByDefault=true`.

## ⚠️ Pièges
- Le template de test importe `package:widgetbook_workspace/widgetbook.config.dart` en dur : corriger l'import si le package est renommé.
- **Vérifié par le spike** (2026-10-28) : compilation sous Flutter 3.47.8 / Dart 3.13.7 et `build_runner` dans un membre de pub workspace. Les types des paramètres du widget doivent être importés dans le `*.stories.dart`, puisque le code généré est un `part` ([[ds-widgetbook-4-spike]]).
