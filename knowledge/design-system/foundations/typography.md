---
id: ds-typography
title: Typographie M3 — TextTheme, échelle fixe, polices hors ligne
tags: [typography, text-theme, material-3, google-fonts, design-system]
status: verified
updated: 2026-10-27
sources: [https://api.flutter.dev/flutter/material/TextTheme-class.html, https://docs.flutter.dev/release/breaking-changes/3-19-deprecations, https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-typescale.scss, https://m3.material.io/styles/typography/type-scale-tokens, https://m3.material.io/styles/typography/applying-type, https://m3.material.io/foundations/layout/breakpoints/overview, https://pub.dev/packages/google_fonts]
links: [ds-tokens-theme-extension, ds-spacing-shape-elevation, ds-material-ui-decoupling, ds-tokens-dtcg-format]
---
# L'échelle de types M3 est une table fixe de 15 rôles : on change les polices, pas les tailles

`TextTheme` expose les 15 noms M3. Tailles M3 2021 (px logiques, Large/Medium/Small) :

| Rôle | Tailles |
|---|---|
| display | 57 / 45 / 36 |
| headline | 32 / 28 / 24 |
| title | 22 / 16 / 14 |
| body | 16 / 14 / 12 |
| label | 14 / 12 / 11 |

- Ces tailles viennent de `Typography.material2021` / `englishLike2021`. La page API de `TextTheme` affiche encore les tailles 2018 (96/60/48…) : ne pas s'y fier.
- **Noms 2018 supprimés** avec les dépréciations de Flutter 3.19 (dépréciés depuis 3.1) : `headline1`→`displayLarge`, `bodyText1`→`bodyLarge`, `caption`→`bodySmall`, `button`→`labelLarge`, `overline`→`labelSmall`.
- **Tokens line-height** (material-web v0_192) : display-large 57/64px, body-medium 14/20px, label-small 11/16px. title-medium/small et label-* utilisent `weight-medium`, les autres `weight-regular` (références, pas valeurs numériques).
- **30 styles depuis Expressive** : 15 baseline + 15 emphasized (`md.sys.typescale.emphasized.*`). Les composants Material n'utilisent pas les styles emphasized par défaut.

## Personnaliser
- M3 conseille de changer les typefaces brand/plain, la hauteur de ligne et l'interlettrage, et **d'éviter de modifier les tailles** (rendu et reflow des composants). Répéter les ajustements pour baseline **et** emphasized.
- Hauteur de ligne : 1,2 × la taille pour title/headline/display, environ 1,5 × pour body/label. Les tokens réels s'en écartent (57/64 ≈ 1,12 ; 14/20 ≈ 1,43).
- Longueur de ligne : 40 à 60 caractères à tous les breakpoints, en jouant sur marges et styles.
- L'échelle M3 se présente comme une table fixe de valeurs ; aucun ratio modulaire n'apparaît dans les sources lues (voir Pièges).

## Polices hors ligne (google_fonts 9.0.0 au 2026-10-27)
- Les fichiers de police déclarés dans les assets du pubspec passent **avant** le fetch HTTP.
- `GoogleFonts.config.allowRuntimeFetching = false` coupe toute requête vers fonts.google.com (défaut `true`).
- Le fetch runtime met en cache sur disque et exige sur macOS l'entitlement `com.apple.security.network.client`.
- Ajouter la licence de chaque police (`OFL.txt`) via `LicenseRegistry.addLicense` dans `main()`.

```dart
void main() {
  GoogleFonts.config.allowRuntimeFetching = false; // polices en assets uniquement
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], ofl);
  });
  runApp(const App());
}
```

## Recommandation (opinion)
Desktop + web : embarquer les polices en assets et couper le fetch, pour un rendu déterministe (goldens, Widgetbook) et sans dépendance réseau. Le thème texte du DS surcharge famille, line-height et interlettrage, jamais les tailles M3.

## ⚠️ Pièges
- Non vérifié : aucune source primaire M3 ou Flutter n'a été lue sur les échelles modulaires (ratio 1,25…). Ne pas en introduire sans source.
- Non vérifié : que `Typography.material2021` soit la typographie par défaut quand `useMaterial3` vaut `true` (seul ce défaut `true` est confirmé). À contrôler dans le code de `ThemeData`.
