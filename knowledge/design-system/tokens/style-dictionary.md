---
id: ds-tokens-style-dictionary
title: Pipeline tokens → Dart — Style Dictionary (Terrazzo sans plugin Dart)
tags: [design-tokens, style-dictionary, terrazzo, codegen, flutter]
status: verified
updated: 2026-10-28
sources: [https://styledictionary.com/info/dtcg/, https://github.com/style-dictionary/style-dictionary/releases, https://styledictionary.com/reference/config/, https://styledictionary.com/reference/hooks/formats/predefined/, https://styledictionary.com/reference/hooks/transform-groups/predefined/, https://styledictionary.com/reference/hooks/transforms/predefined/, https://styledictionary.com/reference/logging/, https://styledictionary.com/reference/hooks/formats/, https://terrazzo.app/docs/, https://terrazzo.app/docs/reference/plugin-api/, https://api.flutter.dev/flutter/dart-ui/ColorSpace.html]
links: [ds-tokens-dtcg-format, ds-tokens-theme-extension, ds-tokens-dtcg-theme-package, ds-claude-design-tokens, adr-0005-ds-tokens-style-dictionary]
---
# Style Dictionary génère du Dart nativement ; Terrazzo exige un plugin maison

Au 2026-10-27, **Style Dictionary 5.7.1** (2026-10-24, correctif de sécurité GHSA-m4pr-rgwp-x36r) est le seul des deux à fournir une sortie Flutter intégrée.

## Style Dictionary et le DTCG
- DTCG natif depuis la v4 (2024-06-28). Le format 2025.10 ([[ds-tokens-dtcg-format]]) n'est **pas encore entièrement** supporté : la doc annonce ce travail pour la v5.
- La v5.7.0 (2026-10-16) ajoute les valeurs `duration` du DTCG 2025.10.
- `usesDtcg` n'a en général pas à être défini : le format est détecté seul.

## Sortie Flutter intégrée
- Format `flutter/class.dart` : une classe Dart statique qui importe `package:flutter/material.dart`. Options : `showFileHeader` (défaut `true`), `outputReferences` (défaut `false`), `className` (pas de défaut documenté ; l'exemple produit `class StyleDictionary` à constructeur privé).
- TransformGroups `flutter` et `flutter-separate` : mêmes six transforms (`attribute/cti`, `name/camel`, `color/hex8flutter`, `size/flutter/remToDouble`, `content/flutter/literal`, `asset/flutter/literal`). `flutter-separate` produit un fichier par catégorie, sans préfixe de catégorie.
- `color/hex8flutter` → `Color` hex 8 chiffres, alpha en tête. `size/flutter/remToDouble` multiplie par 16 (ou `basePxFontSize`).
- **Aucun transform `color/*` ne gère OKLCH.**

## Faire échouer la CI
- `log.errors.brokenReferences` vaut `'throw'` par défaut : une référence cassée est fatale.
- `log.warnings` vaut `'warn'` ; le passer à `'error'` en CI rend fatals les avertissements, par exemple les collisions de tokens.

## Générer une ThemeExtension (opinion)
`StyleDictionary.registerFormat({ name, format({ dictionary, platform, options, file }) })` permet un format maison. Proposition interne (la doc ne parle pas de `ThemeExtension`) : émettre des classes `ThemeExtension` avec `copyWith`/`lerp` ([[ds-tokens-theme-extension]]) plutôt que la classe statique.

## Terrazzo (ex-Cobalt)
- `@terrazzo/cli` 2.10.0 (2026-10-21). Plugins officiels npm : css, sass, js, css-in-js, tailwind, vanilla-extract, swift, token-listing. **Pas de plugin Dart/Flutter.**
- Seule voie : le Plugin API (hooks `config`, `lint`, `transform`, `build`, `buildEnd`, option `enforce`).

## Couleurs côté Flutter
`dart:ui` `ColorSpace` ne connaît que `sRGB`, `extendedSRGB` et `displayP3` (repli sRGB sans support P3). Déduction, non lue dans une source : un token OKLCH doit être converti en sRGB ou Display P3 **à la génération**.

## Recommandation (opinion)
- Style Dictionary + format custom `ThemeExtension`, dans le package du design system ([[ds-tokens-dtcg-theme-package]]).
- Second format custom : le `tokens.json` en listes de Claude Design ([[ds-claude-design-tokens]]), décision [[adr-0005-ds-tokens-style-dictionary]].
- Code Dart généré **committé** ; la CI régénère puis lance `git diff --exit-code`. Pratique déduite : aucune source primaire lue ne la prescrit.

## ⚠️ Pièges
- Non vérifié : `color/hex8flutter` accepte-t-il un objet couleur DTCG 2025.10 (`colorSpace`/`components`) ? Prévoir un transform personnalisé, surtout pour OKLCH.
- Non vérifié : support du module Resolver DTCG par Style Dictionary v5 (rien dans les notes de version lues).
- Plugin API Terrazzo : la page cite à la fois `outputFile` et `buildFile(filename, contents)` ; vérifier sur la version installée.
