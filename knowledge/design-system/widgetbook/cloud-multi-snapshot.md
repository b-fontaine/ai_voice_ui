---
id: ds-widgetbook-cloud-multi-snapshot
title: Widgetbook Cloud — multi-snapshots (matrice thème × locale × viewport)
tags: [widgetbook, widgetbook-cloud, snapshot, design-system]
status: verified
updated: 2026-10-28
sources: [https://docs.widgetbook.io/cloud/snapshots/multi-snapshot, https://docs.widgetbook.io/cloud/snapshots/overview, https://raw.githubusercontent.com/widgetbook/widgetbook/main/packages/widgetbook_annotation/lib/src/use_case.dart, https://docs.widgetbook.io/addons/viewport-addon]
links: [ds-widgetbook-cloud, ds-widgetbook-addons, ds-widgetbook-knobs, ds-widgetbook-setup]
---
# Multi-snapshots : plusieurs captures par use case

Par défaut, chaque use case produit un seul snapshot. Avec les multi-snapshots, il en produit un par configuration (thème, locale, appareil).

## Déclaration
- **Matrice d'addons :** une map nommée dans `@App(cloudAddonsConfigs: {...})`. Exemple : `'German Dark'` = viewport iPhone 12 + locale `de` + thème sombre.
- Configs disponibles : `AlignmentAddonConfig`, `LocalizationAddonConfig`, `SemanticsAddonConfig` (expérimental), `ThemeAddonConfig`, `TextScaleAddonConfig`, `ViewportAddonConfig`, `ZoomAddonConfig`, plus des configs custom.
- **Variantes de knobs :** déclarées sur `@UseCase(cloudKnobsConfigs: …)` (type `KnobsConfigs?`) avec des `*KnobConfig`. Nom vérifié dans le source de `widgetbook_annotation` 3.11.0. L'exemple de la page doc utilise `cloudAddonsConfigs` sur `@UseCase` : c'est une **coquille**, ce nom n'existe que sur `@App` (tranché par le code source, aucun erratum officiel).
- `ViewportAddonConfig` est défini dans le package **`widgetbook`**, pas dans `widgetbook_annotation` : le fichier qui porte `@App` importe les deux.

## Coût
Par use case : snapshots = (configs de knobs) × (configs d'addons) ; un use case sans knob config compte pour 1. `cloudExclude: true` exclut un use case. Comme la facturation est au snapshot, il faut choisir une matrice **minimale et représentative**. Matrice type (opinion) : Light / Dark / Dark texte ×2 / fenêtre étroite.

## ⚠️ Pièges
- L'ancienne URL `/cloud/reviews/multi-snapshot` renvoie une 404. La bonne est `/cloud/snapshots/multi-snapshot`.
