---
id: ds-widgetbook-api-history
title: Widgetbook 3.x — historique d'API à connaître (dépréciations)
tags: [widgetbook, changelog, deprecation, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/widgetbook/changelog, https://pub-web-s1.flutter-io.cn/packages/widgetbook/versions/3.14.2/changelog]
links: [ds-widgetbook-versions, ds-widgetbook-addons]
---
# Historique 3.x : éviter le code obsolète des vieux tutoriels

> Référence Widgetbook 3.x. Le projet utilise la 4.0 bêta ([[adr-0008-ds-widgetbook-4-beta]]) : voir [[ds-widgetbook-4-beta]].

Entrées vérifiées une à une dans le changelog officiel :

| Version | Changement |
|---|---|
| 3.1.0 | Use cases enveloppés dans un `ColoredBox` et non plus un `Scaffold`. `ThemeAddon` doit venir **après** `DeviceFrameAddon`. |
| 3.8.0 | `AccessibilityAddon` déprécié, remplacé par `BuilderAddon` (+ `accessibility_tools`). |
| 3.10.0 | Paramètre `scales` de `TextScaleAddon` déprécié. |
| 3.11.0 | `WidgetbookCloudIntegration` déprécié : on peut le supprimer. Minimum Dart 3.3.0 et Flutter 3.19.0. |
| 3.12.0 | Ajout de `ViewportAddon` (expérimental), futur remplaçant de `DeviceFrameAddon`. |
| 3.13.0 | Ajout de `SemanticsAddon` (expérimental). `device_frame` remplacé par `device_frame_plus`. |
| 3.14.0 | `ViewportData.id` supprimé au profit de `ViewportData.name`. Ajout de `safeAreas`. |
| 3.14.1 | Correctif « Support Flutter 3.32.0 » (pas un nouveau minimum). |
| 3.15.0 | `DeviceFrameAddon` déprécié au profit de `ViewportAddon`. `@experimental` retiré de `ViewportAddon`. |
| 3.16.0 | Minimum Dart 3.7, Flutter 3.29. |
| 3.20.0 | Minimum Dart 3.8, Flutter 3.32. |
| 3.21.0 | Minimum Dart 3.9, Flutter 3.35. |
| 3.22.0 | Minimum Dart 3.10, Flutter 3.38. |
| 3.24.0 | Minimum Flutter 3.44 (inchangé en 3.25.0). |

## ⚠️ Pièges
- C'est un historique, pas un état courant. Au 2026-10-27 (3.25.0), `SemanticsAddon` et `TimeDilationAddon` sont encore `@experimental` ; revérifier à chaque montée.
- Les minimums 3.11.0 (Dart 3.3/Flutter 3.19) sont obsolètes : la 3.25.0 exige Dart 3.10 et Flutter 3.44, ce que Flutter 3.47 satisfait.
- Comme les use cases ne sont plus dans un `Scaffold`, un widget qui exige un ancêtre `Material`/`Scaffold` (`SnackBar`, `TextField`) doit l'inclure dans son use case ou passer par un `BuilderAddon`.
