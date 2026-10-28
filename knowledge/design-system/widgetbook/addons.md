---
id: ds-widgetbook-addons
title: Widgetbook 3.x — addons intégrés et ordre d'enveloppement
tags: [widgetbook, addons, theme, viewport, design-system]
status: verified
updated: 2026-10-28
sources: [https://docs.widgetbook.io/addons/overview, https://docs.widgetbook.io/llms.txt, https://pub.dev/packages/widgetbook/changelog, https://docs.widgetbook.io/addons/semantics-addon]
links: [ds-widgetbook-versions, ds-widgetbook-api-history, ds-widgetbook-cloud-multi-snapshot, ds-tokens-theme-extension]
---
# Les addons enveloppent chaque use case, et leur ordre compte

> Référence Widgetbook 3.x. Le projet utilise la 4.0 bêta ([[adr-0008-ds-widgetbook-4-beta]]) : voir [[ds-widgetbook-4-args-addons]].

Un addon enveloppe **tous** les use cases dans un widget qu'on règle depuis l'interface Widgetbook : thème, taille d'écran, locale… On les déclare une fois, dans la liste `addons:` du widget racine `Widgetbook`.

**Ordre :** le premier addon de la liste est le wrapper **le plus externe**, le dernier le plus interne.
- `ViewportAddon` vient **avant tous les autres** addons. Sinon, par exemple, `AlignmentAddon` centre le viewport et non le use case.
- `SemanticsAddon` vient **après tous les autres**, car ceux-ci peuvent ajouter des nœuds de sémantique.

## Addons intégrés (3.x)
`Alignment`, `Builder`, `Custom`, `Grid`, `Inspector`, `Localization`, `Text Scale`, `Theme`, `Time Dilation`, `Viewport`, `Zoom`.
- `ViewportAddon` : n'est plus expérimental depuis 3.15.0 (`@experimental` retiré).
- `SemanticsAddon` et `TimeDilationAddon` : portent encore `@experimental` dans les sources de la 3.25.0. Ruptures possibles à chaque version mineure.
- `AccessibilityAddon` : déprécié depuis 3.8.0. Le remplacer par `BuilderAddon` + le package `accessibility_tools`.
- `DeviceFrameAddon` : déprécié depuis 3.15.0 au profit de `ViewportAddon`.

## Configuration type du projet (opinion)
```dart
Widgetbook.material(
  directories: directories, // généré
  addons: [
    ViewportAddon(Viewports.all),          // externe : la « fenêtre »
    MaterialThemeAddon(themes: [
      WidgetbookTheme(name: 'Light', data: AppTheme.light()),
      WidgetbookTheme(name: 'Dark', data: AppTheme.dark()),
    ]),
    LocalizationAddon(locales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates),
    TextScaleAddon(min: 1.0, max: 2.0),
    GridAddon(8),                          // contrôle de la grille 8 dp
    AlignmentAddon(),                      // centre le use case
    SemanticsAddon(),                      // toujours en dernier (expérimental)
  ],
);
```
Les noms de paramètres exacts sont à vérifier sur l'API 3.25 avant de copier ce code.

## ⚠️ Pièges
- Mettre `ThemeAddon` avant le viewport : le thème s'applique alors hors du cadre de l'appareil. Aucune page de doc actuelle ne cite `ThemeAddon` : la règle se déduit de « Viewport avant tous les autres » (et du changelog 3.1.0 pour `DeviceFrameAddon`).
- Ajouter un addon après `SemanticsAddon` : ses nœuds de sémantique échappent à l'inspection.
- Toujours fournir les thèmes du **package DS**, jamais un `ThemeData` recréé dans l'app catalogue.
