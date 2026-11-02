---
id: ds-variable-fonts-embedded
title: Polices variables embarquées dans un paquet Flutter (Linux, Impeller) — déclaration, graisses, repli, licences
tags: [typography, fonts, variable-fonts, flutter, packaging, licensing, design-system]
status: sourced
updated: 2026-11-02
sources: [https://github.com/google/fonts/tree/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/spacegrotesk, https://github.com/google/fonts/tree/6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec/ofl/jetbrainsmono, https://docs.flutter.dev/cookbook/design/fonts, https://api.flutter.dev/flutter/dart-ui/FontVariation-class.html]
links: [ds-typography, ds-a11y-wcag-contrast, ds-tokens-style-dictionary]
---
# Une police variable embarquée se déclare sans préfixe, se référence avec, et sa graisse se pose par `FontWeight` et `wght` ensemble

Faits relevés par expérience (Flutter 3.47, Linux, Impeller OpenGLES sous Xvfb, 2026-11-02), pas par une doc unique.

## Fichiers
- Dans `google/fonts`, **Space Grotesk** (axe `wght` 300–700) et **JetBrains Mono** (axe `wght` 100–800) n'existent qu'en **fichiers variables** (`SpaceGrotesk[wght].ttf`). Pas de dossier `static/`. L'axe se lit dans la table `fvar`.
- Épingler la source sur un **commit** du dépôt, pas sur `main` ; noter le SHA-256 de chaque fichier et un test qui le recalcule. Renommer sans crochets (`SpaceGrotesk-Variable.ttf`).
- OFL 1.1 : vérifier l'absence de « Reserved Font Name » avant de dériver (instances statiques par `fonttools`).

## Déclaration et références
- Dans le `pubspec.yaml` **du paquet** : `flutter: fonts: - family: Space Grotesk`, **sans** préfixe. Flutter pose `packages/<paquet>/Space Grotesk` dans le `FontManifest` (vérifié par `flutter build bundle`). Nommer la famille avec le préfixe donne un double préfixe.
- Dans le code, utiliser le nom **préfixé** dans `TextStyle.fontFamily` et `fontFamilyFallback`. Le paramètre `package:` de `TextStyle` préfixe **aussi** `fontFamilyFallback` : il neutralise un repli déjà préfixé.
- Sous `flutter test` **du paquet lui-même**, le préfixe n'est pas posé.

## Graisses
- `FontVariation('wght', n)` + `FontWeight(n)`, `FontVariation` seul et `FontWeight(n)` seul donnent **la même encre** sous Impeller (3 lancements, bruit nul, écart 0,0 % à 500/600/700, deux familles). Un assistant unique qui pose les deux reste sûr et garde `fontWeight` cohérent pour Material.
- Une **police de repli non variable** (DejaVu Sans) reçoit en revanche un gras synthétique si `fontWeight` ≥ 600 : l'écart relevé au premier essai venait de glyphes de repli.
- Les styles `const` ne peuvent pas appeler une fonction : générer aussi la constante `[FontVariation('wght', n)]` depuis le token de graisse.

## Couverture et licences
- Absents des deux polices : ✓ ▲ ▶ ↺ ◆ ★ et l'espace fine insécable U+202F. Lire la table `cmap` pour le savoir (un test de rendu ne voit pas les espaces) et embarquer un repli qui les couvre.
- Redistribuer un repli oblige à en livrer **la licence** : `LicenseRegistry.addLicense` avec chaque texte (OFL ×2, Bitstream Vera/DejaVu), appelé avant `runApp`.

## ⚠️ Pièges
- `flutter_test` ne prouve pas le rendu du vrai moteur : mesurer l'encre (somme de la couverture des pixels via `toImage`) dans une application jetable sous Xvfb.
- Un cache d'assets de test périmé (`build/unit_test_assets`) masque un asset ajouté : le supprimer en cas d'échec inexpliqué.
