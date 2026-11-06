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

Le fil principal se déroule de gauche à droite. Certaines slides ouvrent un **débranchement** (pile verticale reveal) : des slides facultatives numérotées `23.1`, `23.2`… sous la slide `23`, qu'on ne montre que si besoin. `↓` entre dans le débranchement et y avance (en bas de la pile, `↓` rejoint la slide principale suivante) ; `→` passe à la slide principale suivante depuis n'importe quel niveau du débranchement ; `←` revient à la slide principale précédente (au sommet de sa pile). En arrivant sur une slide, ses éléments apparaissent seuls, l'un après l'autre : un seul appui suffit pour passer à la slide suivante.

Débranchements actuels : `23` (WebRTC ou WebSocket) → `23.1` à `23.13` (relais SDP … ports de la voix) ; `27` (La Task : une machine à états) → `27.1` à `27.3` (Message, Part & Artifact … Bindings et versions d'A2A) ; `28` (L'authentification dans A2A) → `28.1` (Patterns multi-agents et voix) ; `30` (Sécurité de bout en bout) → `30.1` (Observabilité et évaluation) ; `39` (Du clic à la confirmation vocale) → `39.1` (Journal du flux A2UI et rejeu). Pour en créer un, envelopper les `<section>` dans une `<section data-start-indexv="0">` : la première est la slide principale, les suivantes le débranchement.

## Raccourcis reveal.js

| Touche | Action |
|---|---|
| `→` / `Espace` / `PgDn` | slide principale suivante, en sautant le débranchement (pendant l'affichage progressif : tout afficher d'un coup) |
| `↓` | entrer dans le débranchement / slide suivante du débranchement |
| `↑` | slide précédente du débranchement |
| `←` / `PgUp` | slide principale précédente, affichée en entier |
| `N` | fenêtre de notes à placer sur le second écran : suit la présentation, affiche les notes en grand, le chrono et le titre de la slide suivante ; `←` `→` `↓` `↑` y pilotent la présentation ; la ligne `↓` annonce la slide suivante du débranchement, `+` `−` règlent la taille, `T` remet le chrono à zéro |
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
