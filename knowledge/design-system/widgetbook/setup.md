---
id: ds-widgetbook-setup
title: Widgetbook 3.x — installation, @App, @UseCase et navigation générée
tags: [widgetbook, setup, codegen, build-runner, design-system]
status: verified
updated: 2026-10-28
sources: [https://docs.widgetbook.io/quick-start, https://docs.widgetbook.io/use-cases/annotations, https://docs.widgetbook.io/configure/use-case-nav-path, https://pub.dev/packages/widgetbook/changelog, https://pub.dev/packages/widgetbook_annotation/changelog, https://pub.dev/api/packages/widgetbook_generator, https://raw.githubusercontent.com/widgetbook/widgetbook/main/packages/widgetbook_annotation/lib/src/use_case.dart]
links: [ds-widgetbook-versions, ds-widgetbook-addons, ds-widgetbook-monorepo, ds-widgetbook-cloud-multi-snapshot]
---
# Le catalogue est une app Flutter séparée ; le générateur ne produit que `directories`

> Référence Widgetbook 3.x. Pour la 4.0 bêta, voir [[ds-widgetbook-4-setup]] (adoption assumée d'une bêta : [[adr-0008-ds-widgetbook-4-beta]]).

**Quick start officiel :** `flutter create widgetbook --empty` (variante : `--platforms=web,macos`), puis renommer le package en `widgetbook_workspace` dans `widgetbook/pubspec.yaml` pour éviter le conflit avec le package `widgetbook`. Ensuite :
`flutter pub add widgetbook widgetbook_annotation dev:widgetbook_generator dev:build_runner`, et l'app (ou le DS) à cataloguer en dépendance `path`.

## Versions compatibles au 2026-10-27
| Package | Version | Contrainte |
|---|---|---|
| `widgetbook` | 3.25.0 | Dart >=3.10, Flutter >=3.44 |
| `widgetbook_annotation` | 3.11.0 | Dart >=3.10 |
| `widgetbook_generator` (dev) | 3.24.0 | Dart >=3.10, `analyzer` >=8.2 <14 |
| `widgetbook_cli` | 3.15.0 | **Dart >=3.11** |

```dart
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'main.directories.g.dart'; // généré à côté de lib/main.dart

@widgetbook.App()
class CatalogApp extends StatelessWidget {
  const CatalogApp({super.key});
  @override
  Widget build(BuildContext context) => Widgetbook.material(
        directories: directories, // seule partie générée
        addons: [/* configurés à la main, voir ds-widgetbook-addons */],
      );
}

@widgetbook.UseCase(name: 'Primary', type: DsButton, path: '[Atoms]/buttons')
Widget dsButtonPrimary(BuildContext context) =>
    Center(child: DsButton(label: 'Valider', onPressed: () {}));
```
Génération : `dart run build_runner build -d` (commande et `Widgetbook.material(directories: …)` tirées du Quick Start).

## Paramètres de `@UseCase` (annotation 3.11.0)
`name` et `type` (requis), `designLink`, `path`, `cloudKnobsConfigs`, `exclude` (défaut `false`), `cloudExclude` (défaut `false`). Les configs d'addons multi-snapshot vont sur `@App(cloudAddonsConfigs: …)` ([[ds-widgetbook-cloud-multi-snapshot]]).

## Chemin de navigation
- Par défaut, il suit l'emplacement du fichier **du composant**.
- `nav_path_mode: use-case` (options du builder `widgetbook_generator:use_case_builder` dans `build.yaml`) le base sur le fichier **du use case**.
- `path` le surcharge localement ; un segment entre crochets devient une catégorie (`[Interactions]/buttons`).

## ⚠️ Pièges
- `type` = le composant catalogué (`DsButton`), **pas** le widget renvoyé par le builder (`Center`). Sinon l'entrée de navigation est fausse.
- Depuis la 3.0, la génération ne couvre que `@App` et `@UseCase`. Addons, `appBuilder` et autres propriétés se règlent dans le constructeur `Widgetbook`.
- `widgetbook_cli` exige Dart 3.11 : vérifier le SDK de la CI avant de l'ajouter.
- Non vérifié : pièges propres à `widgetbook_generator` 3.24.0 (son changelog n'a pas été lu).
