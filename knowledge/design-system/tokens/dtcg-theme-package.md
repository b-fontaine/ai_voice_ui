---
id: ds-tokens-dtcg-theme-package
title: dtcg_theme — générateur DTCG → ThemeExtension (jeune)
tags: [design-tokens, dtcg, codegen, package, design-system]
status: verified
updated: 2026-10-27
sources: [https://pub.dev/packages/dtcg_theme]
links: [ds-tokens-style-dictionary, ds-tokens-theme-extension]
---
# dtcg_theme 0.7.1 : simple mais non éprouvé

`dtcg_theme` est une CLI Dart (environ septembre 2026, éditeur vérifié bomsamdi.com). Elle convertit des fichiers DTCG `.tokens.json` en **ThemeExtension typées**, avec une constante par mode (`AppTokens.light` / `AppTokens.dark`, ou `defaults` sans modes).

## Points positifs
- C'est une `dev_dependency` : le code généré n'importe que Flutter, sans dépendance à l'exécution.
- Elle n'utilise pas build_runner : `dart run dtcg_theme`, avec `--watch` en édition et `--check` en CI pour détecter un code généré périmé. Configuration dans `dtcg.yaml`, à côté du `pubspec.yaml`.
- Types pris en charge : color, dimension (px, rem), number, duration, fontFamily, fontWeight, cubicBezier, typography, shadow, border, transition, gradient (→ `Color`, `TextStyle`, `List<BoxShadow>`, `Gradient`…).

## Limites
- Son propre README dit que les imports Figma Variables et Tokens Studio **n'ont pas été vérifiés sur de vrais exports**.
- Pas de mapping vers `CupertinoThemeData`. Ne gère pas les bordures dashed/dotted, les ombres internes, `strokeStyle` seul ni les expressions.
- Adoption très faible (environ 237 téléchargements, 0 like), Dart ≥ 3.8 requis. Incohérence entre la version affichée (0.7.1) et l'extrait d'installation (`^0.1.0`).

## Verdict (opinion)
Candidat à **prototyper**, pas une dépendance à retenir sans spike. Le comparer à Style Dictionary ([[ds-tokens-style-dictionary]]). Une dépendance de génération se remplace facilement, puisque le code généré est committé.
