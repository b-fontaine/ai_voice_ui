# GenerationFrame
Cadre qui signale qu'un agent est en train d'écrire ce panneau via A2UI.

- Bordure conique tournante (`signal`) + balayage vertical + étiquette `Agent · génère`.
- Remplace le cadre violet pointillé statique : on voit **qui** génère et **que** ça bouge.
- Ajouter `is-done` quand l'agent a fini : un dernier tour puis fondu. Un seul cadre actif à la fois.
