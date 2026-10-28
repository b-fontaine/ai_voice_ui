---
id: ds-widgetbook-4-spike
title: Spike Widgetbook 4.0.0-beta.14 — résultats mesurés (2026-10-28)
tags: [widgetbook, spike, beta, material-ui, accessibility, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14, https://github.com/widgetbook/widgetbook/issues/2044, https://github.com/widgetbook/widgetbook/issues/1984, https://github.com/widgetbook/widgetbook/issues/1797]
links: [adr-0008-ds-widgetbook-4-beta, ds-widgetbook-4-args-addons, ds-widgetbook-4-testing, ds-widgetbook-4-risks, ds-a11y-wcag-focus-target]
---
# La beta.14 tient sous Flutter 3.47.8 avec material_ui, à cinq contournements près

Faits **observés en exécutant** le code `spikes/widgetbook4/` (Flutter 3.47.8, Dart 3.13.7, Linux et Chrome), puis reproduits par un vérificateur indépendant (sauf #1984 et les temps de build). Le statut `verified` vaut pour ces mesures, pas pour une doc.

## Ce qui marche
- Pub workspace : DS `material_ui` 1.8.0 + catalogue en `widgetbook: 4.0.0-beta.14`. Durées : `build_runner` 40 s à froid, `build web` 73 s, `--wasm` 76 s, `build linux` 33 s.
- `ThemeAddon<m.ThemeData>` : la bascule Light/Dark fonctionne dans l'UI. L'URL porte l'état (`&theme={name:Dark}`).
- **#1984 non reproduit :** un Bloc injecté par `setup` ne fuit pas entre stories sœurs (clic, hash, retour), avec ou sans `key`.
- **#1797 :** en stratégie hash (par défaut), `#/?path=…` et le rechargement fonctionnent.
- `testWidgetbook` : un `testWidgets` par scénario, PNG + JSON dans `build/.widgetbook/`.

## Contournements obligatoires
1. **`appBuilder` material_ui :** celui par défaut crée un `MaterialApp` de `flutter/material`, et les widgets `material_ui` ne trouvent pas leurs ancêtres. Fournir `m.MaterialApp(home: m.Material(child: …))`. `MaterialThemeAddon` refuse le `ThemeData` de `material_ui` (#2044, confirmé à la compilation).
2. **Imports dans `*.stories.dart` :** le code généré est un `part`. Les types des paramètres (`IconData`, `Key`) doivent y être importés : `widgetbook.dart` n'exporte pas `flutter/widgets`.
3. **Marge autour des stories :** `MinTapTargetGuideline` ignore les nœuds qui touchent le bord de la vue (`isAtBoundary`), et le snapshot est cadré au plus près du contenu. Sans marge, un bouton seul n'est jamais contrôlé. Sans marge, `text-contrast` produit aussi des faux positifs (ratio 1.01). Une marge de 8 px dans l'`appBuilder` suffit.
4. **Règles a11y desktop :** avec `VisualDensity.compact`, les boutons font 40 px. Le jeu `recommended` (48 et 44) échoue, alors que WCAG 2.5.8 (24 px) est respecté. Déclarer `MinTapTargetGuideline(id: 'tap-target-wcag-aa', size: Size(24, 24))`, plus `LabeledTappableGuideline` et `FlutterGuideline(textContrastGuideline, …)`. Ce dernier exige `flutter_test` en `dependencies`.
5. **Scénarios globaux :** déclarer des `ScenarioDefinition` **supprime le scénario implicite « Default »**. Déclarer « Light » **et** « Dark » (`ThemeMode<m.ThemeData>(name, theme, builder)`).

## Limites
- `flutter test --platform chrome` affiche « No tests ran », sans erreur, et le processus peut rester bloqué : rester sur la VM.
- Avertissement de build : `CupertinoIcons` référencée, mais `cupertino_icons` absent.
- Non testé : GenUI (`CachedSurface`), macOS et Windows, les montées de version de bêta.
