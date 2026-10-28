---
id: ux-desktop-undo-dnd-windows
title: Undo/redo, glisser-déposer et multi-fenêtres sur desktop
tags: [desktop, undo-redo, drag-and-drop, multi-window, ux]
status: verified
updated: 2026-10-27
sources: [https://developer.apple.com/design/human-interface-guidelines/undo-and-redo, https://developer.apple.com/design/human-interface-guidelines/drag-and-drop, https://pub.dev/packages/super_drag_and_drop, https://flutter.dev/blog/desktop-windowing-apis, https://learn.microsoft.com/en-us/windows/apps/design/input/keyboard-accelerators]
links: [ux-desktop-shortcuts, ux-desktop-menus, ux-ai-human-in-the-loop, genui-user-actions]
---
# Rendre undo/redo visible et doubler le glisser-déposer d'une commande annulable

## Undo / redo (Apple HIG)
- Placer Undo et Redo en tête du menu Edit : `Cmd+Z` et `Shift+Cmd+Z`. Windows : `Ctrl+Z` et `Ctrl+Y`.
- Ne pas limiter le nombre d'annulations sans nécessité.
- Rendre visible le résultat de chaque undo/redo et nommer la cible dans le libellé : « Undo Typing ».

## Glisser-déposer (Apple HIG)
- Proposer d'autres façons de faire, par exemple une commande de menu. C'est une recommandation, pas une obligation.
- Permettre d'annuler un dépôt (« prefer letting people undo »).
- Afficher l'image de glissement dès environ 3 points de déplacement. Indiquer si la destination accepte le contenu.
- En règle générale, un dépôt dans le même conteneur **déplace**, un dépôt dans un autre conteneur **copie**. Option force la copie dans le même conteneur.
- Flutter : `super_drag_and_drop` **0.9.1** stable (0.10.0-dev.2 en préversion, au 2026-10-27). Il fait du drag & drop natif entre applications sur Android, iOS, Linux, macOS, Web et Windows. Sur web, le drag sortant reste limité au même onglet.

## Multi-fenêtres
- Au 2026-08-24 (blog Flutter), l'API `WindowController`/`Window` et `DialogWindowController`/`DialogWindow` n'existe que sur le canal **main**, derrière `flutter config --enable-windowing`. Elle peut encore changer.
- Au 2026-10-27 : aucune annonce officielle de passage en stable n'a été trouvée.

## Application au projet (opinion)
- L'historique d'undo est un état de Bloc (pile d'events inversibles). Il couvre les modifications de formulaires GenUI avant leur envoi à l'agent.
- Une action d'agent déjà exécutée (outil réel) ne s'annule pas par `Ctrl+Z`. On demande une confirmation avant ([[ux-ai-human-in-the-loop]]).
- Ne pas bâtir de fonction clé sur le multi-fenêtres tant que l'API est expérimentale.

## ⚠️ Pièges
- Non vérifiés : la version stable de Flutter qui embarquerait le multi-fenêtres, et le support plateforme par plateforme. Selon une source tierce non confirmée, Flutter 3.47.5 stable ne propose pas `--enable-windowing`.
- Pas de source primaire lue sur la mémorisation de la taille et de la position des fenêtres, ni sur la sélection multiple (Shift-clic, Ctrl/Cmd-clic).
