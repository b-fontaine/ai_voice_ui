---
id: arch-analyzer-plugins
title: Analyzer plugins natifs (Dart 3.10) vs custom_lint
tags: [lint, analyzer-plugin, custom_lint, tooling]
status: verified
updated: 2026-10-26
sources: [https://dart.dev/tools/analyzer-plugins, https://pub.dev/packages/custom_lint]
links: [arch-import-lint, test-very-good-analysis]
---
# Écrire ses propres règles d'architecture

Depuis **Dart 3.10**, l'analyzer supporte nativement des plugins (package `analysis_server_plugin`, `^0.3.0` dans l'exemple de la doc). On les déclare sous `plugins:` dans `analysis_options.yaml`, à la racine du package ou du workspace :

```yaml
plugins:
  my_arch_rules:
    path: tools/my_arch_rules   # plugin local
    diagnostics:
      no_cross_feature_import: true
```

**Fonctionnement :**
- Les **warnings** des plugins sont actifs par défaut. Les **lint rules** doivent être activées explicitement.
- Ignorer un diagnostic : `// ignore: my_arch_rules/no_cross_feature_import`.
- Un plugin est un package avec `lib/main.dart`, une variable `plugin` de haut niveau et une classe `Plugin` qui surcharge `register`. On peut y ajouter rules, fixes et assists.
- Il fonctionne dans l'IDE comme avec `dart analyze` / `flutter analyze`, donc en CI.

**`custom_lint`** (0.8.1, publiée il y a environ 13 mois au 2026-10-26) :
- c'est l'ancienne approche, sans avis de dépréciation sur pub.dev.

**Recommandation (opinion) :**
- Pour un projet neuf : `import_lint` (déjà natif), plus un petit plugin natif maison seulement si une règle manque, par exemple « une feature n'importe pas une autre feature ».
- Ne pas démarrer avec `custom_lint`.

⚠️ Pièges
- Dans un plugin, `print` ne s'affiche pas (isolate séparé) : il faut logger dans un fichier.
- Redémarrer l'Analysis Server après chaque changement de `plugins:`.
