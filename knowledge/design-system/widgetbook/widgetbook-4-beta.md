---
id: ds-widgetbook-4-beta
title: Widgetbook 4.0 bêta — vue d'ensemble
tags: [widgetbook, migration, beta, accessibility, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/documentation/widgetbook/4.0.0-beta.9/widgetbook, https://pub.dev/packages/widgetbook/versions, https://pub.dev/api/packages/widgetbook, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/CHANGELOG.md, https://docs.widgetbook.io/~v4/whats-new-in-v4, https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz]
links: [adr-0008-ds-widgetbook-4-beta, ds-widgetbook-versions, ds-widgetbook-4-setup, ds-widgetbook-4-stories, ds-widgetbook-4-testing, ds-widgetbook-4-risks]
---
# La 4.0 remplace UseCase/knobs par Component/Story/Scenario et des Args typés

Informations datées du 2026-10-28 : la dernière préversion est `4.0.0-beta.14` (2026-09-11), la stable reste 3.25.0. Les `@UseCase` et `context.knobs` de la 3.x deviennent des stories (`_Story`) et des args typés (`_Args`).

**Adoption assumée d'une bêta :** [[adr-0008-ds-widgetbook-4-beta]] retient la 4.0.0-beta.14, épinglée en version exacte, malgré l'absence de stable. Règles et repli : [[ds-widgetbook-versions]].

## Ce qui change (détails dans les notes v4)
- **Installation :** un seul package `widgetbook` (générateur et tests fusionnés depuis alpha.5) + `build_runner`. `runWidgetbook(Config(...))` remplace `Widgetbook.material` et `@App` → [[ds-widgetbook-4-setup]].
- **Stories générées :** `*.stories.dart`, `const meta = Meta(W.new)`, variables `$Story`. `@UseCase` devient `_Story` → [[ds-widgetbook-4-stories]].
- **Args typés** à la place des knobs : `BoolArg`, `IntArg`, `DoubleArg`, `StringArg`, `ColorArg`, `DateTimeArg`, `DurationArg`, `EnumArg`, `IterableArg`, `SingleArg`, et leurs variantes `Nullable*` (liste vue en beta.9) → [[ds-widgetbook-4-args-addons]].
- **Addons :** à chaque addon correspond un Mode (`MaterialThemeMode`, `LocaleMode`, `ViewportMode`…). `DeviceFrameAddon`, `InspectorAddon` et `AccessibilityAddon` disparaissent. `LocalizationAddon` devient `LocaleAddon`.
- **Doc intégrée :** `DocBlock` (`ComponentNameDocBlock`, `DartCommentDocBlock`, `StoriesDocBlock`, `StoryDocBlock`, `WidgetDocBlock`…). Viewports prédéfinis pour Android, iOS, macOS, Linux et Windows.
- **Tests :** scénarios et `testWidgetbook(config)` (snapshots PNG et JSON dans `build/.widgetbook`, sans comparaison locale). `Config.accessibilityConfig` (beta.9) évalue des `WidgetbookGuideline` → [[ds-widgetbook-4-testing]].
- **GenUI :** la doc v4 a une section dédiée, sans API spécifique → [[ds-widgetbook-4-genui]].

## Changements depuis la beta.9
- **beta.10 :** `excludeFromTests` ; le cache d'images est vidé entre scénarios.
- **beta.11 :** la preview est reconstruite au changement de story.
- **beta.12 :** les images sont chargées avant le snapshot ; l'état de la preview est conservé.
- **beta.13 :** analyzer 13.x/14.x.
- **beta.14 :** `Config.foldersExpandedByDefault`.

Aucun changement cassant après la beta.9. Les ruptures majeures datent de la beta.4 (`scenarioConfig`) et de la beta.7 (`Meta(W.new)`).

## ⚠️ Pièges
- Risques, cadence, issues ouvertes et erreurs du guide de migration IA : [[ds-widgetbook-4-risks]].
- Les notes `ds-widgetbook-setup`, `-knobs`, `-addons`, `-api-history` et `-testing` décrivent la **3.x**. Elles restent une référence, mais ne s'appliquent pas à un code écrit en v4.
