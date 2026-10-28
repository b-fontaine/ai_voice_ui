---
id: ds-widgetbook-4-args-addons
title: Widgetbook 4.0 bêta — Args typés, addons, ThemeAddon<T> et material_ui
tags: [widgetbook, args, addons, theme, material-ui, design-system]
status: verified
updated: 2026-10-28
sources: [https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/args/enum_arg.dart, https://github.com/widgetbook/widgetbook/blob/v4/docs/args/enum.mdx, https://raw.githubusercontent.com/widgetbook/widgetbook/refs/heads/v4/docs/assets/guides/v4-migration/prompt.md, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/addons/locale_addon.dart, https://github.com/widgetbook/widgetbook/blob/v4/docs/addons/overview.mdx, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/addons/viewport_addon/viewports/macos_viewports.dart, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/addons/theme_addon/theme_addon.dart, https://github.com/widgetbook/widgetbook/issues/2044, https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz]
links: [ds-widgetbook-4-stories, ds-material-ui-decoupling, adr-0004-ds-visual-base-m3, ds-tokens-theme-extension, ds-widgetbook-addons]
---
# Les knobs deviennent des Args typés ; le thème material_ui passe par `ThemeAddon<T>`

Signatures relevées dans le code de 4.0.0-beta.14 (2026-10-28).

## Args
- `BoolArg(bool value, {String? name})` et `StringArg(String value, {String? name})`.
- `IntArg(int value, {String? name, style = const InputIntArgStyle()})`, ou `style: SliderIntArgStyle(min:, max:, divisions:)`.
- `EnumArg<T extends Enum>(T value, {name, required values, labelBuilder = enumLabelBuilder, style = const DropdownSingleArgStyle()})`.
- `SingleArg(value, {required values, ...})`.
- Styles de choix : `DropdownSingleArgStyle` (défaut) et `SegmentedSingleArgStyle`, sous-classes scellées de `SingleArgStyle`.
- Chaque type a sa variante `Nullable*` (`NullableBoolArg`, `NullableStringArg`, `NullableEnumArg`…). Les knobs `orNull` deviennent des args nullables.

## Addons de beta.14
- **Présents :** Alignment, Builder, Grid, Locale, TextScale, TimeDilation, Zoom, Semantics, Theme (Material et Cupertino), Viewport.
- **Supprimés :** `DeviceFrameAddon` (→ `ViewportAddon`/`ViewportMode`), `InspectorAddon` et `AccessibilityAddon` (dès alpha.3).
- **Renommés :** `LocalizationAddon` → `LocaleAddon`. Pour les addons maison, `Addon.buildUseCase` → `Addon.apply` (alpha.4).
- **Signatures :** `ThemeAddon<T>(Map<String, T> themes, ThemeBuilder<T> builder)`, `MaterialThemeAddon(Map<String, ThemeData> themes)`, `LocaleAddon(locales, [delegates = const []])` (assert : `locales` non vide), `TextScaleAddon([double scale = 1])`, `GridAddon([int dimension = 50])`, `SemanticsAddon([bool enabled = false])`, `AlignmentAddon([Alignment alignment = Alignment.center])` et `ZoomAddon([double ratio = 1])`.
- À chaque addon correspond un Mode : `MaterialThemeMode(name, theme)`, `LocaleMode`, `TextScaleMode(double)`, `SemanticsMode(bool)`, `ViewportMode(ViewportData)`…
- **Ordre :** le premier addon de la liste est le plus externe. `ViewportAddon` vient avant tous les autres, `SemanticsAddon` (expérimental) après tous les autres.
- **Viewports desktop :** `MacosViewports.desktop`, `WindowsViewports.desktop` et `LinuxViewports.desktop` (1920x1080), `MacosViewports.macbookPro` (1770x970), tous en pixelRatio 2. `Viewports.all` couvre iOS, Android, macOS, Windows, Linux, et inclut `Viewports.none`.

## material_ui : issue #2044 (ouverte, 2026-10-02)
`MaterialThemeAddon` est typé contre `package:flutter/material.dart` et refuse un `ThemeData` de `material_ui` ([[adr-0004-ds-visual-base-m3]]). Le mainteneur conseille le `ThemeAddon<T>` générique avec un builder maison : c'est une contrainte, pas un blocage. L'exemple officiel fait déjà ainsi : `ThemeAddon<AppThemeData>({...}, (context, theme, child) { return AppTheme(data: theme, child: child); })`. Esquisse pour le projet (opinion, noms `material_ui` non vérifiés) :
```dart
import 'package:material_ui/material_ui.dart' as m;
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

final addons = [
  ViewportAddon(Viewports.all),
  ThemeAddon<m.ThemeData>(
    {'Light': DsTheme.light(), 'Dark': DsTheme.dark()},
    (context, theme, child) => m.Theme(data: theme, child: child),
  ),
  LocaleAddon(AppLocalizations.supportedLocales, AppLocalizations.localizationsDelegates),
  AlignmentAddon(),
  SemanticsAddon(), // toujours en dernier
];
```

## ⚠️ Pièges
- **Collision `ThemeMode` :** `package:widgetbook/widgetbook.dart` exporte `ThemeMode<T>` (le Mode de `ThemeAddon`), homonyme de l'enum Flutter qu'utilise `Config.themeMode`. Si un fichier importe les deux, utiliser `hide` ou un préfixe. Déduit des exports, non testé par compilation.
- `AlignAddon` est un addon **maison** de l'exemple officiel. L'addon du package s'appelle `AlignmentAddon`.
- Le prompt de migration officiel écrit `BooleanArg`, `SegmentedArgStyle` et `SingleArg([...])`, qui n'existent pas dans beta.14 ([[ds-widgetbook-4-risks]]).
- **Non vérifié :** le contrôle UI de `TextScaleAddon`, ainsi que `CupertinoThemeAddon`, `TimeDilationAddon`, les args et addons personnalisés.
