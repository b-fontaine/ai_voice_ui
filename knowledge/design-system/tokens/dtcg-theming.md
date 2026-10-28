---
id: ds-tokens-dtcg-theming
title: DTCG — thèmes et marques via le module Resolver
tags: [design-tokens, dtcg, theming, dark-mode, design-system]
status: verified
updated: 2026-10-27
sources: [https://www.designtokens.org/tr/2025.10/, https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/]
links: [ds-tokens-dtcg-format, ds-tokens-theme-extension]
---
# Le thématisage DTCG vit dans un module séparé : Resolver

DTCG 2025.10 prend en charge les modes clair/sombre, les variantes d'accessibilité (contraste élevé) et plusieurs marques, avec alias, héritage et références. Mais ces modes **ne sont pas dans le fichier Format** : ils sont décrits par le **module Resolver**.

## Resolver
- **sets :** ensembles de fichiers de tokens ;
- **modifiers :** des axes (thème, marque, contraste) qui ont chacun des `contexts` (`light`, `dark`…) ;
- **resolutionOrder :** ordre d'application, où la dernière valeur l'emporte ;
- références via `$ref`.

## Organisation recommandée (opinion)
Trois couches :
1. **primitives** (`color.blue.500`) ;
2. **sémantiques** (`color.surface`, `color.on-surface`), qui ne contiennent que des alias et varient par mode ;
3. **composants** (`button.primary.bg`), qui ne sont que des alias vers les sémantiques.

Les composants Flutter ne lisent **que** les couches 2 et 3.

## ⚠️ Pièges
- La promesse « sans duplication » n'est tenue qu'en partie. Les marques n'ont pas d'exemple travaillé dans la spec.
- Le contournement par `$defs` est un comportement indéfini, pris en charge de façon inégale selon les outils. Le support du Resolver varie selon le générateur : tester la chaîne de bout en bout.
