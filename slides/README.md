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

Le talk s'ouvre sur la démo, avant les slides : les slides `1` à `5` y reviennent (couverture, actes, chemin d'une demande, orateur, cas d'usage). Le fil principal compte 37 slides.

Débranchements actuels : `14` (Définir un composant du catalogue) → `14.1` (Les transports possibles pour A2UI) ; `22` (WebRTC ou WebSocket) → `22.1` à `22.13` (relais SDP … ports de la voix) ; `26` (La Task : une machine à états) → `26.1` à `26.9` (Message, Part & Artifact, suivi d'une Task, bindings et versions, spike SP-03, authentification, patterns multi-agents, où tourne chaque agent, sécurité de bout en bout, observabilité) ; `31` (L'orchestrateur et les agents A2A) → `31.1` (Ouvrir la session voix) ; `33` (Du clic à la confirmation vocale) → `33.1` (Journal du flux A2UI et rejeu) ; `35` (Docs vivantes et boucle autonome) → `35.1` (Ce que vous pouvez réutiliser). Pour en créer un, envelopper les `<section>` dans une `<section data-start-indexv="0">` : la première est la slide principale, les suivantes le débranchement.

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
