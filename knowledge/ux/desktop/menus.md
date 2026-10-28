---
id: ux-desktop-menus
title: Menus desktop — MenuBar, MenuAnchor, menus contextuels et règles plateforme
tags: [desktop, menus, context-menu, macos, ux]
status: verified
updated: 2026-10-27
sources: [https://api.flutter.dev/flutter/material/MenuAnchor-class.html, https://api.flutter.dev/flutter/widgets/PlatformMenuBar-class.html, https://api.flutter.dev/flutter/widgets/ContextMenuController-class.html, https://api.flutter.dev/flutter/services/BrowserContextMenu-class.html, https://learn.microsoft.com/en-us/windows/apps/design/controls/menus-and-context-menus, https://developer.apple.com/design/human-interface-guidelines/the-menu-bar, https://developer.apple.com/design/human-interface-guidelines/menus]
links: [ux-desktop-shortcuts, ux-desktop-platform-kits, ux-desktop-undo-dnd-windows, ux-desktop-adaptive-layout]
---
# Les menus servent à découvrir les commandes, le menu contextuel aux commandes secondaires

## API Flutter (au 2026-10-27)
- `MenuBar` et `SubmenuButton` créent leur propre `MenuAnchor`. Hors `MenuBar`, on utilise `MenuAnchor` (`menuChildren`, `MenuController`), par exemple pour un menu contextuel en cascade.
- `PlatformMenuBar` (menus natifs) n'est supporté d'origine que sur **macOS**. Ailleurs, il faut un plugin qui définit `WidgetsBinding.platformMenuDelegate`. Le widget n'a aucun rendu : il renvoie son enfant.
- `ContextMenuController` (`show`/`remove`, `removeAny` statique) garantit un seul menu contextuel à la fois dans toute l'app.
- **Web :** le menu du navigateur est actif par défaut et ceux de Flutter masqués. `BrowserContextMenu.disableContextMenu()` le désactive. L'appel ne fait rien hors web.

## Windows
- Un **menu** s'ouvre au clic gauche depuis un bouton ou une barre de menus.
- Un **menu contextuel** s'ouvre au clic droit ou à l'appui long. Il est attaché à un élément et ne contient que des commandes secondaires.
- Une commande fréquente gagne à être directement dans l'UI. Le libellé affiche l'accélérateur ([[ux-desktop-shortcuts]]).

## macOS (Apple HIG)
- Barre de menus : afficher toujours les mêmes éléments. Un élément inutilisable dans le contexte est **désactivé, pas masqué**.
- Garder les menus système dans leur ordre. Prendre en charge les raccourcis standards (Copy, Cut, Paste, Save, Print).
- Ajouter **« … »** au libellé quand l'action demande une saisie supplémentaire.
- Un seul niveau de sous-menu. Au-delà d'environ cinq éléments, envisager un nouveau menu.

## Recommandations (opinion)
- macOS : `PlatformMenuBar` natif. Windows, Linux et web : `MenuBar` du DS.
- Les deux barres sont construites depuis une même liste de commandes (libellé, Intent, raccourci par plateforme) et invoquent les mêmes Actions.
- Sur web, n'appeler `disableContextMenu()` que pour les zones qui ont un menu Flutter (ex. une surface GenUI).

## ⚠️ Pièges
- Sur Windows ou Linux sans delegate, un `PlatformMenuBar` n'affiche rien et ne crée aucun menu natif : il renvoie simplement son enfant.
- Sur macOS, ne pas masquer un élément selon le contexte : le désactiver (HIG barre de menus).
