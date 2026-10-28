---
id: ux-desktop-pointer-hover
title: Pointeur et survol desktop — curseurs, FocusableActionDetector, tooltips
tags: [desktop, pointer, hover, tooltip, ux]
status: verified
updated: 2026-10-27
sources: [https://docs.flutter.dev/ui/adaptive-responsive/input, https://api.flutter.dev/flutter/material/Tooltip/waitDuration.html, https://learn.microsoft.com/en-us/windows/apps/design/controls/tooltips, https://fluent2.microsoft.design/accessibility]
links: [ux-desktop-focus, ux-desktop-shortcuts, ds-a11y-wcag-contrast, ds-component-api]
---
# Un contrôle custom desktop gère curseur, survol, focus et raccourcis ensemble

Doc Flutter (entrées adaptatives, au 2026-10-27) :
- **Curseur :** `MouseRegion(cursor: SystemMouseCursors.click)` dans un widget custom. C'est la seule consigne explicitement présentée « On desktop ».
- **Contrôle custom :** `FocusableActionDetector` réunit dans un widget le focus, le survol et les raccourcis (actions, bindings, callbacks de surbrillance). La doc le recommande pour intégrer un contrôle au parcours Tab.
- **Boutons Material :** ils gèrent le focus, sauf si `overlayColor` est transparent. Dans ce cas, il faut gérer vous-même l'état de focus et le tester (la doc le laisse entendre sans l'écrire).

```dart
FocusableActionDetector(
  mouseCursor: SystemMouseCursors.click,
  onShowHoverHighlight: (v) => setState(() => _hover = v),
  onShowFocusHighlight: (v) => setState(() => _focus = v),
  actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed())},
  child: DsChipVisual(hover: _hover, focus: _focus),
);
```

## Tooltips
- Flutter : `Tooltip.waitDuration` vaut **0 ms** par défaut, donc le tooltip apparaît dès le survol.
- Windows :
  - le tooltip s'affiche au survol, au focus clavier ou à l'appui long ;
  - l'utiliser avec parcimonie et le garder concis ;
  - ne pas répéter un texte visible, ne pas y mettre de contrôle interactif ;
  - il est **nécessaire** pour un bouton de barre d'outils qui n'affiche qu'une icône.

## Recommandations (opinion)
- Un état visuel distinct pour le survol et pour le focus, piloté par les callbacks du détecteur. L'état visuel reste local au widget (pas de Bloc pour un survol).
- Contraste des états de survol et de focus : au moins 3:1, comme le demande Fluent 2 pour les composants interactifs. Voir [[ds-a11y-wcag-contrast]] (critère WCAG 1.4.11).
- Fixer un `waitDuration` non nul dans le thème du DS si l'affichage immédiat gêne. Le tooltip d'un bouton-icône affiche le raccourci ([[ux-desktop-shortcuts]]).

## ⚠️ Pièges
- Non vérifiés : les valeurs par défaut de `showDuration`, `exitDuration` et `triggerMode`, ainsi que le détail de `MouseRegion.onEnter`/`onExit`.
- Les états d'interaction Material 3 (hover, pressed) n'ont pas été consultés sur m3.material.io.
