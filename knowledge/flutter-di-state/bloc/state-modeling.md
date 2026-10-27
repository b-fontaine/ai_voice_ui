---
id: bloc-state-modeling
title: Modéliser l'état — union scellée ou classe + status
tags: [bloc, state, vgv, best-practice]
status: verified
updated: 2026-10-26
sources: [https://engineering.verygood.ventures/development/state_management/bloc_state_handling/, https://bloclibrary.dev/naming-conventions/]
links: [bloc-sealed-freezed, bloc-naming, bloc-no-non-serializable-state]
---
# Union scellée ou classe unique avec un `status` ?

VGV distingue deux modèles d'état :

- **Classe unique + enum `XxxStatus`** (`initial`, `loading`, `success`, `failure`) avec `copyWith`. À utiliser quand les données **s'accumulent** au fil des étapes (formulaire multi-étapes, valeurs chargées indépendamment) : « the data emitted in previous steps should not be lost in newer emits ».
- **Union scellée (ou classe abstraite), une classe par état** : à utiliser quand les données d'un état ne sont plus utiles au suivant. Chaque état ne porte que ses données (jamais `null` une fois matché), et l'UI fait un `switch` exhaustif.

**Application au projet (opinion) :**
- Session vocale : **union scellée** (`idle` / `connecting` / `listening` / `speaking` / `failure`). Ce sont de vrais états d'une machine à états.
- Transcription, historique des tours, liste de surfaces GenUI : **classe unique** freezed avec `status`, car l'historique s'accumule.
- Mélange possible : une union dont certains cas portent un sous-objet `Conversation` commun.

**Bonnes pratiques VGV :**
- Dans un `catch`, appeler `addError(e, s)`, puis émettre un état d'échec **qui conserve** les saisies de l'utilisateur.
- Revalider dans le Bloc avant d'émettre un succès, pas seulement dans l'UI.

## ⚠️ Pièges
- Une union scellée fait perdre les données entre deux états (passer de `listening` à `failure` efface la transcription). Si l'UI doit l'afficher, elle doit vivre dans un champ partagé.
- Les exemples VGV de cette page utilisent Cubit. Le raisonnement s'applique tel quel à Bloc (→ [[bloc-no-cubit]]).
