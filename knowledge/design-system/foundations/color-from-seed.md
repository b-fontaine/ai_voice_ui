---
id: ds-color-from-seed
title: Couleur — ColorScheme.fromSeed et DynamicSchemeVariant
tags: [color, material-3, color-scheme, flutter, theming]
status: verified
updated: 2026-10-28
sources: [https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html, https://api.flutter.dev/flutter/material/DynamicSchemeVariant.html]
links: [ds-color-m3-roles, ds-color-harmony, ds-color-dark-contrast, ds-tokens-theme-extension]
---
# ColorScheme.fromSeed génère tous les rôles d'une graine ; la variante décide de la fidélité

Par défaut, `dynamicSchemeVariant` vaut `DynamicSchemeVariant.tonalSpot`. Cette variante produit des palettes pastel peu colorées, même avec une graine très saturée.

## Variantes (`DynamicSchemeVariant`)
- `tonalSpot` (défaut), `fidelity`, `monochrome`, `neutral`, `vibrant`, `expressive`, `content`, `rainbow`, `fruitSalad`.
- `fidelity` : palettes qui correspondent à la graine. La doc la recommande **si le schéma obtenu est trop sombre**.
- `content` : `primaryContainer` est la graine, ajustée pour le contraste.
- `expressive` : la teinte primaire diffère de la graine.
- `rainbow`, `fruitSalad` : la teinte de la graine n'apparaît pas dans le thème.

## Paramètres
- `contrastLevel` va de -1.0 à 1.0, défaut 0.0. Selon Material, 0.5 = contraste moyen, 1.0 = contraste élevé.
- Tout rôle optionnel non nul (`primary:`, `error:`…) **remplace** la couleur générée pour ce rôle.

```dart
// (opinion) un seul point d'entrée, graine et variante injectées par config
class AppTheme {
  const AppTheme({required this.seed, this.variant = DynamicSchemeVariant.fidelity});
  final Color seed;
  final DynamicSchemeVariant variant;

  ThemeData _build(Brightness b, double contrast) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed, brightness: b,
          dynamicSchemeVariant: variant, contrastLevel: contrast),
        extensions: const [/* DsSpacing, DsStatusColors… */],
      );

  ThemeData get light => _build(Brightness.light, 0);
  ThemeData get dark => _build(Brightness.dark, 0);
  ThemeData get highContrastLight => _build(Brightness.light, 1);
  ThemeData get highContrastDark => _build(Brightness.dark, 1);
}
// MaterialApp(theme: t.light, darkTheme: t.dark,
//   highContrastTheme: t.highContrastLight, highContrastDarkTheme: t.highContrastDark)
```

## Recommandation (opinion)
- Variante explicite, jamais le défaut implicite : un `tonalSpot` pastel surprend souvent la marque.
- Graine et variante viennent des tokens ([[ds-tokens-theme-extension]]), pas d'une constante dans un widget.

## ⚠️ Pièges
- Par construction, la `seedColor` peut n'apparaître dans **aucun** rôle. Pour une couleur de marque exacte, surcharger le rôle ou définir un schéma de base ([[ds-color-harmony]]).
- « Trop terne » n'est pas dans la doc : seul le cas « trop sombre » y figure pour `fidelity`.
- Surcharger un rôle sans surcharger son `onX` peut casser la paire ([[ds-color-m3-roles]]).
