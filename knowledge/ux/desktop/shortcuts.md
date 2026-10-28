---
id: ux-desktop-shortcuts
title: Raccourcis clavier desktop — Shortcuts/Actions et conventions Windows/macOS
tags: [desktop, keyboard-shortcuts, shortcuts-actions, accessibility, ux]
status: verified
updated: 2026-10-27
sources: [https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts, https://docs.flutter.dev/ui/adaptive-responsive/input, https://learn.microsoft.com/en-us/windows/apps/design/input/keyboard-accelerators, https://learn.microsoft.com/en-us/windows/apps/design/input/access-keys, https://developer.apple.com/design/human-interface-guidelines/keyboards]
links: [ux-desktop-focus, ux-desktop-menus, ux-desktop-undo-dnd-windows, ux-desktop-platform-kits]
---
# Un raccourci Flutter = un Intent résolu par une Action dans le sous-arbre focalisé

**Flutter (doc lue au 2026-10-27) :**
- `Shortcuts` associe un `ShortcutActivator` à un `Intent`. `LogicalKeySet` est remplacé par `ShortcutActivator`. `SingleActivator` = une touche + modificateurs optionnels.
- Le raccourci ne se déclenche que si le sous-arbre (ou un descendant) **a le focus et est visible**. Les exemples officiels enveloppent le sous-arbre dans `Focus(autofocus: true)`.
- Résolution : `Actions.invoke` remonte les `Actions` ancêtres jusqu'au type d'Intent. Une Action n'est invoquée que si `isEnabled(intent)` est vrai ; si l'Action trouvée est désactivée, la recherche s'arrête là. `Actions.maybeInvoke` = `maybeFind` + `invokeAction`, et renvoie `null` si rien n'est trouvé.
- L'état commun à toutes les invocations va dans le **constructeur de l'Action**, pas dans l'Intent.
- `CallbackShortcuts` (`Map<ShortcutActivator, VoidCallback>`) : alternative légère sans Intent/Action.

```dart
class SaveIntent extends Intent { const SaveIntent(); }
class SaveAction extends Action<SaveIntent> {
  SaveAction(this._bloc); // dépendance injectée, pas dans l'Intent
  final EditorBloc _bloc;
  @override
  Object? invoke(SaveIntent intent) { _bloc.add(const EditorSaveRequested()); return null; }
}
Shortcuts(
  shortcuts: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): const SaveIntent()},
  child: Actions(actions: {SaveIntent: SaveAction(bloc)},
      child: Focus(autofocus: true, child: editor)),
);
```

**Windows :**
- Accélérateurs homogènes entre applications : Undo `Ctrl+Z`, Redo `Ctrl+Y`, Select all `Ctrl+A`, Rename `F2`, Refresh `F5`/`Ctrl+R`, Save `Ctrl+S`, Close `Ctrl+W`, Find `Ctrl+F`, zoom par défaut `Ctrl+0`, volet suivant/précédent `F6`/`Shift+F6`.
- Documenter l'accélérateur dans le libellé du menu ou le tooltip : « Copy (Ctrl+C) ».
- Un accélérateur est global par défaut (`ScopeOwner` nul). Windows recommande de limiter ceux d'un menu contextuel à son parent (« scoped ») ; exemple Outlook : `Ctrl+B` seulement dans le formulaire d'envoi, `Ctrl+1` dans toute l'app.
- **Localiser** les accélérateurs : en espagnol, le gras est `Ctrl+N` et non `Ctrl+B`.
- Access keys : `Alt` + caractères pressés en séquence (badges « keytips » à l'appui sur `Alt`). Préférer 1 caractère, 2 au maximum. Pas de collision dans une même portée, éviter I/1 et O/0.

**macOS (Apple HIG) :**
- En général, ne pas détourner un raccourci standard. Ordre d'affichage : Control, Option, Shift, Command.
- Command est le modificateur principal, Shift le secondaire, Option pour les commandes rares. Éviter Control, déjà utilisé par le système.
- Standards : `Cmd+,` réglages, `Cmd+Q` quitter, `Cmd+A` tout sélectionner, `Cmd+F` rechercher, `Cmd+.` annuler une opération.

## Recommandations (opinion)
- Déclarer une table de raccourcis par plateforme, `Ctrl` sous Windows/Linux, `Cmd` (`meta: true`) sous macOS. **Non vérifié** dans la doc Flutter lue.
- Les Actions déclenchent des events Bloc. Le tooltip et le menu affichent le raccourci de la plateforme courante.

## ⚠️ Pièges
- Un listener global `HardwareKeyboard` n'est pas géré par le framework. C'est à vous de le couper quand l'utilisateur tape dans un champ ou quand le widget est masqué. Cas critique : `Delete`/`Backspace` avec des `TextField` enfants.
- Les key events passent **avant** la saisie texte. Un handler placé autour d'un `TextField` peut avaler la touche ([[ux-desktop-focus]]).
