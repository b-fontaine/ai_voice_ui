---
id: ds-color-m3-roles
title: Couleur — rôles M3 et paires X/onX
tags: [color, material-3, color-scheme, design-system, accessibility]
status: verified
updated: 2026-10-27
sources: [https://m3.material.io/styles/color/roles, https://api.flutter.dev/flutter/material/ColorScheme-class.html, https://api.flutter.dev/flutter/material/ColorScheme/surfaceVariant.html, https://m3.material.io/styles/color/system/how-the-system-works]
links: [ds-color-from-seed, ds-color-dark-contrast, ds-tokens-theme-extension, ds-a11y-wcag-contrast, ds-component-api]
---
# Une couleur M3 est un rôle, et le contraste n'est garanti que pour les paires prévues

M3 définit **26 rôles standards** en six groupes : primary, secondary, tertiary, error, surface et outline. La même page ajoute des rôles **add-on** (fixed, surface dim/bright, etc.).

## Paires et superpositions
- Le contraste accessible n'est assuré que dans les paires ou ordres prévus : `onPrimary` sur `primary`, `onPrimaryContainer` sur `primaryContainer`… Une combinaison libre peut casser le contraste.
- M3 annonce un **minimum de 3:1** pour ces paires, pas 4.5:1. Le texte courant exige 4.5:1 selon WCAG ([[ds-a11y-wcag-contrast]]).
- Les rôles `*Container` remplissent des éléments de premier plan (boutons). Ils ne colorent **jamais** du texte ou une icône : on utilise `onXContainer`.

## Surfaces
- Cinq surface containers : `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer` (le rôle par défaut selon m3.material.io), `surfaceContainerHigh`, `surfaceContainerHighest`.
- Flutter liste aussi `surfaceBright` et `surfaceDim` parmi les surfaces tonales. Elles remplacent l'ancien modèle de teinte superposée selon l'élévation.

## Contours, fixed, erreur
- `outline` : frontières importantes (contour d'un champ texte). `outlineVariant` : décor (séparateurs), quand les autres éléments offrent déjà 4.5:1.
- Pour délimiter une cible ou créer une hiérarchie : `outline`, ou une couleur à 3:1 contre la surface.
- `primaryFixed`, `secondaryFixed`, `tertiaryFixed` et leurs `*FixedDim` gardent le même ton en clair et en sombre. M3 les déconseille là où le contraste compte.
- Quatre rôles d'erreur : `error`, `onError`, `errorContainer`, `onErrorContainer`.

## Niveaux de contraste
Les rôles gèrent trois niveaux (standard, medium, high), en clair comme en sombre. Un composant custom en profite s'il utilise les bons rôles ([[ds-color-dark-contrast]]).

## Règle du DS (opinion)
Les composants du design system ne référencent **que des rôles** (`Theme.of(context).colorScheme.x` ou une `ThemeExtension` sémantique, voir [[ds-tokens-theme-extension]]), jamais une `Color` littérale. C'est ce qui rend clair, sombre et contraste élevé gratuits, y compris pour les surfaces GenUI.

```dart
final cs = Theme.of(context).colorScheme;
DecoratedBox(
  decoration: BoxDecoration(color: cs.primaryContainer),
  child: Text(label, style: TextStyle(color: cs.onPrimaryContainer)),
);
```

## ⚠️ Pièges
- `ColorScheme.background` et `surfaceVariant` sont dépréciés depuis Flutter v3.18.0-0.1.pre. Remplacer par `surface` et `surfaceContainerHighest`.
- Non vérifié : l'existence de rôles d'erreur « statiques » hors couleur dynamique. Seuls les 4 rôles ci-dessus sont confirmés.
