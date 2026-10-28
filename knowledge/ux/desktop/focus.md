---
id: ux-desktop-focus
title: Focus clavier desktop — FocusNode, parcours et conventions Windows/Fluent
tags: [desktop, focus, keyboard-navigation, accessibility, ux]
status: verified
updated: 2026-10-28
sources: [https://docs.flutter.dev/ui/interactivity/focus, https://learn.microsoft.com/en-us/windows/apps/design/accessibility/keyboard-accessibility, https://learn.microsoft.com/en-us/windows/apps/design/input/guidelines-for-visualfeedback, https://fluent2.microsoft.design/accessibility]
links: [ds-a11y-wcag-focus-target, ux-desktop-shortcuts, ux-desktop-pointer-hover, ds-a11y-flutter-signals]
---
# Sur desktop, le clavier est un mode d'interaction principal, pas un repli

Windows : le clavier doit être traité « as a primary interaction model, not a secondary fallback ». Tout ce qui s'active au pointeur doit s'activer au clavier, au minimum avec Espace et Entrée.

## Règles Flutter (doc focus, au 2026-10-27)
- `FocusNode` : le créer dans le `State` et le libérer dans `dispose()`. Jamais un nœud par `build` : fuites mémoire et perte du focus au rebuild.
- Ne pas partager un `FocusNode` entre plusieurs widgets : ils se disputent ses attributs.
- `autofocus` : au plus un widget par focus scope, sinon le choix est arbitraire. N'agit que si le scope n'a pas déjà de focus.
- Parcours : `ReadingOrderTraversalPolicy` par défaut. `OrderedTraversalPolicy` pour un ordre explicite. `FocusTraversalGroup` délimite une section parcourue comme un groupe.
- Les key events partent du nœud au focus primaire et remontent jusqu'à ce qu'un handler renvoie `KeyEventResult.handled`. Un event non traité à la racine retourne à la plateforme.
- `FocusManager.highlightStrategy` bascule automatiquement entre « touch » et « traditional » (souris/clavier) selon les derniers événements. On peut aussi la verrouiller. `highlightMode` expose le mode courant.

## Conventions Windows / Fluent
- **F6 / Shift+F6** : passer d'une grande région à l'autre (exemple Edge : barre d'adresse, favoris, onglets, contenu). Ce n'est **pas automatique**, il faut l'implémenter.
- Contrôle composite (liste, grille, arbre) : un seul arrêt de tabulation, navigation interne aux flèches. C'est un « common pattern », pas une règle stricte. Dans un arbre où déplier et activer sont distincts, gauche/droite replient et déplient.
- Focus visuals « high visibility » : bordure extérieure 2 px + bordure intérieure 1 px, marge de 1 px autour du contrôle.
- Fluent 2 : ordre de focus en **Z** (gauche → droite, puis haut → bas). Le focus ne doit pas être perdu à la fermeture d'une UI temporaire comme un dialog. Contraste ≥ 3:1 pour les composants interactifs et non textuels.

## Application à une app voix + GenUI (opinion)
- Régions F6 typiques : navigation, transcript voix, surface GenUI, saisie. Chaque région est un `FocusTraversalGroup`.
- Une surface A2UI générée reste un groupe de focus. À sa reconstruction, le focus revient sur un nœud stable plutôt que d'être perdu ([[genui-multiple-surfaces]]).
- L'anneau de focus du DS reprend le double contour 2 px + 1 px et vise les critères de [[ds-a11y-wcag-focus-target]].

## ⚠️ Pièges
- Un handler de touches placé autour d'un `TextField` passe avant la saisie texte et peut avaler des caractères.
- Les classes `FocusTraversalOrder`, `NumericFocusOrder` et `LexicalFocusOrder` ne sont **pas vérifiées** sur api.flutter.dev.
