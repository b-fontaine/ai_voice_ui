---
id: ds-tokens-theme-extension
title: Tokens → Flutter — ThemeExtension comme cible
tags: [design-tokens, theme-extension, theming, flutter, design-system]
status: verified
updated: 2026-10-27
sources: [https://api.flutter.dev/flutter/material/ThemeExtension-class.html, https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/]
links: [ds-tokens-dtcg-format, ds-tokens-style-dictionary, ds-tokens-dtcg-theme-package, ds-color-m3-roles]
---
# Les tokens qui ne rentrent pas dans ThemeData vont dans une ThemeExtension

`ThemeExtension<T>` est l'interface officielle pour ajouter des propriétés à `ThemeData`.

- **Enregistrement :** `ThemeData(extensions: [...])`. **Lecture :** `Theme.of(context).extension<T>()`.
- Une sous-classe doit implémenter **`copyWith`** et **`lerp`**. `lerp` rend la transition de thème animable.
- La classe est générique et auto-référente : `class DsSpacing extends ThemeExtension<DsSpacing>`. Le constructeur est `const`.
- Exemple officiel : `flutter create --sample=material.ThemeExtension.1`.

```dart
@immutable
class DsSpacing extends ThemeExtension<DsSpacing> {
  const DsSpacing({required this.xs, required this.sm, required this.md});
  final double xs, sm, md;
  @override
  DsSpacing copyWith({double? xs, double? sm, double? md}) =>
      DsSpacing(xs: xs ?? this.xs, sm: sm ?? this.sm, md: md ?? this.md);
  @override
  DsSpacing lerp(DsSpacing? o, double t) => o == null ? this : DsSpacing(
      xs: lerpDouble(xs, o.xs, t)!, sm: lerpDouble(sm, o.sm, t)!, md: lerpDouble(md, o.md, t)!);
}
extension DsTheme on BuildContext {
  DsSpacing get space => Theme.of(this).extension<DsSpacing>()!;
}
```

## Répartition (opinion)
- Couleurs sémantiques → `ColorScheme`, avec les rôles M3 ([[ds-color-m3-roles]]).
- Texte → `TextTheme`.
- Ce que Material ne modélise pas (espacements, rayons nommés, couleurs métier comme « succès » ou « avertissement », durées) → `ThemeExtension`.
- On génère ces classes, on ne les écrit pas à la main ([[ds-tokens-style-dictionary]]).

## ⚠️ Pièges
- `extension<T>()` renvoie `null` si l'extension n'est pas enregistrée. Fournir les extensions dans **tous** les `ThemeData` : clair, sombre, contraste élevé, et ceux de Widgetbook.
