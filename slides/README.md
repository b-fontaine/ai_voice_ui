# Slides — Genesis Canvas (Meetup Flutter Nantes, 12 novembre 2026)

Présentation HTML (reveal.js 5 + Vite), thème « Jarvis » avec fond animé. Fonctionne hors ligne : polices auto-hébergées, aucune ressource distante.

## Lancer

```bash
cd slides
npm install
npm start          # serveur de dev + ouverture du navigateur
npm run build      # version statique dans dist/
npm run preview    # sert dist/
```

Le guide de style (non inclus dans la présentation) : `http://127.0.0.1:5173/styleguide.html`. Composants et conventions : [`STYLEGUIDE.md`](STYLEGUIDE.md).

## Navigation

Les slides s'enchaînent de gauche à droite uniquement (pas de pile verticale). En arrivant sur une slide, ses éléments apparaissent seuls, l'un après l'autre : un seul appui suffit pour passer à la slide suivante.

## Raccourcis reveal.js

| Touche | Action |
|---|---|
| `→` / `Espace` / `PgDn` | slide suivante (pendant l'affichage progressif : tout afficher d'un coup) |
| `←` / `PgUp` | slide précédente, affichée en entier |
| `S` | vue orateur (notes, minuteur, slide suivante) |
| `O` ou `Échap` | vue d'ensemble |
| `F` | plein écran |
| `B` ou `.` | écran noir (pause) |
| `Alt` + clic | zoom sur un élément |

## Export PDF

Ouvrir `http://127.0.0.1:5173/?print-pdf`, puis imprimer depuis Chrome ou Chromium (destination « Enregistrer en PDF », orientation paysage, marges « Aucune », graphiques d'arrière-plan cochés). Le fond animé est désactivé à l'impression.

## Structure

```
slides/
├── index.html              # coquille de la présentation
├── styleguide.html         # planche de démonstration des composants
├── src/
│   ├── main.js             # assemble src/sections/*.html (ordre alphabétique)
│   ├── deck.js             # configuration reveal.js, polices, fond
│   ├── background/hud.js   # fond animé (canvas)
│   ├── theme/              # jarvis.css (base), components.css, code.css
│   └── sections/           # une section du talk par fichier
└── STYLEGUIDE.md
```
