---
id: arch-import-lint
title: import_lint — interdire des imports entre couches
tags: [lint, imports, architecture, analyzer-plugin, fsd]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/import_lint, https://dart.dev/tools/analyzer-plugins]
links: [arch-analyzer-plugins, arch-fsd-dart-mapping, arch-fsd-layers]
---
# import_lint : règles target / from / except dans analysis_options.yaml

Le package `import_lint` (v2.0.0, observée le 2026-10-26) est un **analyzer plugin natif** :
- il dépend de `analysis_server_plugin` (`^0.3.14`), n'utilise pas `custom_lint`, et requiert **Dart 3.10+** ;
- il fournit aussi une CLI, `dart run import_lint`, utilisable en CI.

**Structure d'une règle :**
- `target` : les fichiers contraints (glob) ;
- `from` : les imports interdits ;
- `except` : les exceptions.

```yaml
# analysis_options.yaml (structure plugins: / import_lint: rules: conforme au README)
plugins:
  import_lint: ^2.0.0
import_lint:
  severity: "error"
  rules:
    domain_is_pure:
      target: "package:voice_agent/src/model/domain/**/*.dart"
      from: "package:flutter/**"
      except: []
    no_ui_in_api:
      target: "package:voice_agent/src/api/**/*.dart"
      from: "package:voice_agent/src/ui/**"
      except: []
```

**Usage FSD/Clean (opinion) :**
- Le pubspec contrôle déjà les frontières entre packages.
- `import_lint` sert **dans** un package :
  - interdire `ui` → `api` ;
  - garder `domain` sans `flutter`, `dio` ni `flutter_webrtc` ;
  - dans le package app, faire respecter `pages` → `widgets` sans dépendance inverse.

⚠️ Pièges
- Après une modification de `plugins:`, il faut **redémarrer l'Analysis Server**.
- `severity` se place directement sous `import_lint:`, au même niveau que `rules:` (README vérifié le 2026-10-26). Le README utilise des globs `*`, `**` et `[!x]` : tester tout glob plus exotique avant la CI.
