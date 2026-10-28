---
id: ds-component-api
title: API d'un composant DS — calquer les boutons Material
tags: [component-api, button-style, widget-state, theming, design-system]
status: verified
updated: 2026-10-27
sources: [https://api.flutter.dev/flutter/material/FilledButton-class.html, https://api.flutter.dev/flutter/material/ButtonStyle-class.html, https://dart.dev/effective-dart/design, https://docs.flutter.dev/cookbook/design/themes, https://api.flutter.dev/flutter/material/ThemeData/extensions.html]
links: [ds-tokens-theme-extension, ds-atomic-design, ds-a11y-flutter-signals, ds-widgetbook-knobs, ux-desktop-pointer-hover]
---
# Un composant DS s'inspire de FilledButton : 3 couches de style, styles nullables, variantes par constructeurs nommés

## Le modèle Material
- **Trois couches** : défaut (`defaultStyleOf`), thème (`FilledButtonTheme` pour un sous-arbre, `ThemeData.filledButtonTheme` pour l'app), paramètre `style` du widget.
- **`ButtonStyle`** : toutes les propriétés valent `null` ; une valeur absente retombe sur le défaut, dérivé de `colorScheme` et `textTheme`. Beaucoup sont des `WidgetStateProperty` (pressed, hovered, focused, disabled). `styleFrom()` pour les changements globaux, `merge` comble les champs `null`.
- **Variantes par constructeurs nommés**, pas par enum : `FilledButton.tonal`, `.icon`, `.tonalIcon`.
- **Effective Dart** : AVOID positional boolean parameters ; préférer arguments nommés, constructeurs ou constantes nommés.
- **Surcharge locale** : `Theme(data: Theme.of(context).copyWith(...))` plutôt qu'un `ThemeData` complet.
- **Tokens maison** : `ThemeData.extensions` reçoit des `ThemeExtension` ([[ds-tokens-theme-extension]]).

## Règles pour les composants `Ds*` (opinion)
- Ils lisent **uniquement le thème** (`ColorScheme`, `TextTheme`, extensions) : aucune couleur ni taille en dur.
- États exposés comme en Material : désactivé quand `onPressed == null`, `loading` nommé, hover/focus via `WidgetStateProperty`.
- `Semantics` explicites (libellé, bouton, état) pour le lecteur d'écran ([[ds-a11y-flutter-signals]]).
- Chaque variante = un use case Widgetbook ([[ds-widgetbook-knobs]]).

```dart
class DsButton extends StatelessWidget {
  const DsButton({super.key, required this.label, this.onPressed, this.loading = false})
      : _variant = _Variant.primary;
  const DsButton.tonal({super.key, required this.label, this.onPressed, this.loading = false})
      : _variant = _Variant.tonal;
  final String label;
  final VoidCallback? onPressed; // null => désactivé
  final bool loading;            // nommé, jamais positionnel
  final _Variant _variant;
  // build(): FilledButton / FilledButton.tonal, style lu du thème
}
```

## ⚠️ Pièges
- Non vérifié : l'ordre exact de priorité entre `style` et `FilledButtonTheme` n'est pas énoncé sur la page API.
- L'application de la règle Effective Dart aux variantes de widgets est une lecture interne, pas une consigne de la page.
