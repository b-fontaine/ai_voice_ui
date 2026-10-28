---
id: adr-0005-ds-tokens-style-dictionary
title: "ADR-0005 — Génération des design tokens avec Style Dictionary"
tags: [adr, decision, design-tokens, style-dictionary, dtcg]
status: opinion
updated: 2026-10-28
sources: []
links: [ds-tokens-style-dictionary, ds-tokens-dtcg-format, ds-tokens-dtcg-theming, ds-tokens-theme-extension, ds-tokens-dtcg-theme-package]
---
# ADR-0005 — Tokens DTCG dans Git, générés en Dart par Style Dictionary

- **Statut :** acceptée le 2026-10-28.
- **Décideur :** porteur du projet, qui retient la recommandation de l'assistant.
- **Portée :** générique.

## Contexte
- Le format DTCG 2025.10 est stable : c'est un *Final CG Report* du W3C, pas un standard [[ds-tokens-dtcg-format]].
- Générateurs candidats :
  - Style Dictionary 5.7.1 : DTCG natif, format `flutter/class.dart`, mais pas d'OKLCH [[ds-tokens-style-dictionary]] ;
  - `dtcg_theme` 0.7.1 : jeune, et son import Figma n'est pas éprouvé [[ds-tokens-dtcg-theme-package]] ;
  - Terrazzo : pas de plugin Dart ;
  - écriture à la main.

## Décision
- La source de vérité est un ensemble de fichiers `.tokens.json` DTCG dans le dépôt, organisés en primitives, sémantiques et composants [[ds-tokens-dtcg-theming]].
- Style Dictionary 5.x, avec un **format custom** qui génère des `ColorScheme`/`TextTheme` et des `ThemeExtension` [[ds-tokens-theme-extension]].
- Les couleurs OKLCH sont converties en sRGB ou Display P3 au moment de la génération.
- Le code généré est committé. En CI : régénération puis `git diff --exit-code`, avec `log.warnings: 'error'`.

## Raisons
- C'est l'outil de référence, maintenu et extensible (`registerFormat`). Il rejette les références cassées par défaut.
- Le format custom permet d'obtenir des `ThemeExtension` animables (`lerp`), ce que `flutter/class.dart` ne fait pas.

## Options écartées
- **`dtcg_theme` :** trop peu adopté. À reconsidérer après un spike.
- **Terrazzo :** il faudrait écrire un plugin Dart.
- **Écriture à la main :** pas de source de vérité partagée avec l'outil de design.

## Hypothèses non confirmées
- Style Dictionary (Node) est disponible en CI et sur les postes de dev. Il faut épingler la version.
- Le transform `color/hex8flutter` n'accepte peut-être pas les objets couleur DTCG 2025.10 : un transform custom est probablement nécessaire (non vérifié).

## Quand réexaminer
- Style Dictionary v5 prend entièrement en charge DTCG 2025.10 et le Resolver.
- Un générateur Dart natif mûr apparaît.
- L'outil de design exporte directement en Dart ([[adr-0007-ds-design-tool-claude-design]]).

## Historique
- 2026-10-28 — portée précisée lors du nettoyage de knowledge/ (porteur).
