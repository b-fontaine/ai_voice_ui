# ActionBar
La décision finale, toujours humaine : appui long pour bloquer, validation désactivée si un critère bloque.

- `data-hold` : maintenir 1,1 s remplit le bouton puis confirme. Évite le clic accidentel en direct et rend le geste visible.
- « Valider » passe en `aria-disabled` avec la raison en infobulle.
- Après confirmation : reçu `gc-receipt` (qui, quand, conséquence). « Bloquer la release · fait ✓ » sans auteur laisse croire que l'IA a décidé seule.
