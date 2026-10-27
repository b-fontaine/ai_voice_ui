---
id: di-micro-packages
title: injectable — micro-packages pour un workspace multi-packages
tags: [di, injectable, workspace, monorepo, modularity]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/injectable, https://pub.dev/packages/injectable/changelog]
links: [di-setup-versions, di-get-it-scopes, proj-avw-overview, proj-sk-overview, arch-pub-workspaces]
---
# Micro-packages : un module DI par package du workspace

Dans un workspace pub (orchestrateur, voice_agent, genui_agent, core…), chaque package annote son point d'entrée avec `@InjectableInit.microPackage()`. Le générateur produit alors une classe `XxxPackageModule extends MicroPackageModule` au lieu d'une méthode `init`. Le package **app** (racine) l'inclut explicitement.

```dart
// packages/voice_agent/lib/di/voice_agent_module.dart
@InjectableInit.microPackage()
initMicroPackage() {}   // génère VoiceAgentPackageModule

// app/lib/di/injection.dart
@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(CorePackageModule),
    ExternalModule(VoiceAgentPackageModule),
  ],
  externalPackageModulesAfter: [
    ExternalModule(GenUiAgentPackageModule, scope: 'genui'),
  ],
)
void configureDependencies(String env) => getIt.init(environment: env);
```

- **v3 :** `includeMicroPackages` (scan automatique) est supprimé. La liste est désormais explicite, ce qui est plus prévisible.
- `ExternalModule(..., scope: 'x')` place tout le module dans un scope dédié, avec sa propre méthode d'init générée.
- Chaque package ne dépend que des **interfaces** des autres (package `core`/`contracts`), jamais de leurs implémentations.

## ⚠️ Pièges
- Un seul `GetIt.instance` partagé, donc un seul `configureDependencies` dans l'app. Un `getIt` local à un package (cas de `features/ai` dans proj-sk-overview) casse la composition.
- L'environnement passé à la racine s'applique aussi aux modules externes. Annoter les fakes `@test` dans chaque package.
- Le nom du module généré est `<NomDuPackageEnPascalCase>PackageModule` (code d'injectable_generator 3.1.3) : `voice_agent` → `VoiceAgentPackageModule`. La fonction `initMicroPackage(){}` du README n'est jamais appelée, elle sert seulement de support à l'annotation.
