# Guide de style — thème Jarvis

Planche de démonstration vivante : `npm start`, puis ouvrir `/styleguide.html` (elle n'est **pas** incluse dans la présentation).

## Règles de base

- **Taille logique d'une slide : 1600 × 900 px (16:9).** Reveal.js met à l'échelle. Toutes les tailles ci-dessous (police, marges) sont dans ce repère. Garder une marge de sécurité d'environ 60 px en bas (numéro de slide et contrôles en bas à droite).
- **Une section = un fichier** `src/sections/NN-<slug>.html`, qui contient une ou plusieurs `<section>`. L'ordre de la présentation est l'ordre alphabétique des fichiers. Pas de `<html>` ni de `<body>` dans ces fichiers.
- Texte courant : 36 px (Rajdhani). Ne pas descendre sous 22 px, même pour une légende.
- Titres : `h1` 84 px, `h2` 54 px (titre de slide, souligné automatiquement), `h3` 34 px cyan, `h4` 26 px ambre. Tout est en majuscules Orbitron.
- Couleurs : cyan `#00e5ff` = accent principal ; ambre `#ffb300` = secondaire ; rouge `#ff4d5e` = alerte, **rare** ; vert `#4dffb0` = vérifié. Variables CSS : `--j-cyan`, `--j-amber`, `--j-red`, `--j-green`, `--j-text`, `--j-text-muted`, `--j-text-dim`.
- Les slides sont en `text-align: left` par défaut. Ajouter `class="center"` à la `<section>` pour centrer.
- Notes orateur : `<aside class="notes">…</aside>` (touche **S**).
- Hors ligne : aucune ressource distante. Une image se met dans `public/` (ou `src/assets/`) et se référence en relatif.
- **Sources** : chaque fait technique cite son origine (`knowledge/` ou `product/`) avec `.refs`. Une PDR « proposée » porte `.badge--proposed`, une question ouverte `.badge--open` : jamais présentées comme acquises.

## Intensité du fond animé

Attribut `data-hud` sur une `<section>` :

| Valeur | Effet |
|---|---|
| *(absent)* / `normal` | fond standard |
| `high` | fond plus présent (titres de chapitre, couverture) |
| `low` | fond atténué, scanlines coupées : **slides denses** (diagrammes, code, tableaux) |
| `off` | fond éteint (seul le dégradé reste) |

Le fond pulse légèrement à chaque changement de slide et de fragment. Il est figé si le système demande `prefers-reduced-motion: reduce`, et se met en pause quand l'onglet est caché.

```html
<section data-hud="low"> … </section>
```

## Utilitaires

`.accent` (cyan) · `.amber` · `.alert` · `.ok` · `.muted` · `.dim` · `.mono` · `.title-font` · `.glow` · `.glow-amber` · `.lead` (chapô) · `.big` · `.small` · `.upper` · `.eyebrow` (sur-titre ambre) · `.divider` · `.row` (flex en ligne, `.row.center`) · `.stack` (espacement vertical) · `.mt-0/1/2` · `.mb-0` · `.avatar` (portrait rond, image locale).

## 1. Slide de titre de section

```html
<section class="chapter" data-hud="high">
  <p class="chapter-num">Chapitre <b>02</b></p>
  <h2>GenUI &amp; A2UI</h2>
  <div class="chapter-rule"></div>
  <p class="subtitle">Sous-titre du chapitre</p>
</section>
```

## 2. Panneau HUD

Coins de cadre lumineux. Variantes : `.hud-panel--amber`, `.hud-panel--alert`.

```html
<div class="hud-panel">
  <p class="panel-title">Objectif</p>
  <p>Contenu du panneau.</p>
</div>
```

## 3. Grilles

`.grid-2`, `.grid-3`, `.grid-4`, `.grid-1-2`, `.grid-2-1` (gouttière 32 px). Modificateurs : `.stretch-items` (hauteurs égales, utile avec des cartes), `.center-items`.

```html
<div class="grid-2">
  <div>Colonne gauche</div>
  <div>Colonne droite</div>
</div>
```

## 4. Cartes

Coin coupé, liseré supérieur coloré. Variantes : `.card--amber`, `.card--alert`. `.card-icon` : pastille ronde (numéro ou symbole).

```html
<div class="grid-3 stretch-items">
  <div class="card">
    <span class="card-icon">01</span>
    <h3>Titre</h3>
    <p>Une idée par carte, trois lignes au plus.</p>
  </div>
  <div class="card card--amber">…</div>
</div>
```

## 5. Puces

Toutes les `ul`/`ol` sont stylées : losange cyan, tiret au 2ᵉ niveau, numéros ambre `01, 02…` pour `ol`. Variantes de `ul` : `.amber-list`, `.check-list` (✓ vert), `.cross-list` (✕ rouge), `.plain` (sans puce), `.compact` (serré).

```html
<ul>
  <li class="fragment rise-in">Premier point</li>
  <li>Deuxième point
    <ul><li>sous-point</li></ul>
  </li>
</ul>
<ul class="check-list"><li>Fait vérifié</li></ul>
```

## 6. Badges et sources

| Classe | Sens |
|---|---|
| `.badge--accepted` | décision acceptée (PDR / ADR) |
| `.badge--proposed` | décision **proposée** (non tranchée) |
| `.badge--open` | question ouverte `Q-xx` |
| `.badge--verified` | fait vérifié |
| `.badge--opinion` | recommandation interne (`status: opinion`) |
| `.badge--neutral` | étiquette neutre (`alpha`, `pré-1.0`…) |
| `.badge--plain` | à combiner : retire le point lumineux |

```html
<span class="badge badge--proposed">pdr-NNNN proposée</span>
<span class="badge badge--open">Q-xx ouverte</span>
```

`.refs` : ligne de sources en bas de slide (préfixe `SRC //` automatique), positionnée en absolu au bas de la `<section>`.

```html
<p class="refs">[id-de-note] · product/architecture/overview.md</p>
```

## 7. KPI

Variantes : `.kpi--amber`, `.kpi--alert`. Unité dans `<small>`.

```html
<div class="kpi-row">
  <div class="kpi"><span class="kpi-value">42<small>ms</small></span><span class="kpi-label">Libellé</span></div>
  <div class="kpi kpi--amber"><span class="kpi-value">7</span><span class="kpi-label">Libellé</span></div>
</div>
```

## 8. Timeline horizontale

Une colonne par jalon (autant que d'éléments). `.is-now` : point ambre (situation actuelle) ; `.is-future` : pointillés (à venir, non acquis).

```html
<div class="timeline">
  <div class="tl-item fragment rise-in">
    <span class="tl-date">2024</span>
    <span class="tl-title">Jalon</span>
    <span class="tl-text">Deux lignes au plus.</span>
  </div>
  <div class="tl-item is-now">…</div>
  <div class="tl-item is-future">…</div>
</div>
```

## 9. Diagramme boîtes et flèches

### 9a. En HTML/CSS (simple, en ligne ou en colonne)

`.flow` (horizontal) ou `.flow.flow--vertical`. Boîtes `.node` (variantes `--amber`, `--alert`, `--ghost` en pointillés, `--round` en pilule ; `<small>` = sous-titre mono). Flèches `.arrow` avec flux de données animé ; variantes `--amber`, `--back` (sens inverse), `--both` (double pointe), `--static` (sans animation). Libellé : `.arrow-label` (au-dessus) ou `.arrow-label--below`.

```html
<div class="flow">
  <div class="node node--round">Voix<small>micro</small></div>
  <div class="arrow"><span class="arrow-label">audio</span></div>
  <div class="node">Service<small>backend</small></div>
  <div class="arrow arrow--amber arrow--back"><span class="arrow-label arrow-label--below">réponse</span></div>
  <div class="node node--amber">Agent</div>
</div>
```

### 9b. En SVG inline (architectures)

Mettre `class="diagram"` sur le `<svg>` et dessiner dans un `viewBox` en pixels logiques (ex. `0 0 1400 520`). Classes : `.d-zone` + `.d-zone-label` (cadre de zone en pointillés), `.d-node` (`--amber`, `--ghost`), `.d-label`, `.d-sub`, `.d-link` (trait en tirets **qui défilent** ; `--amber`, `--back`, `--static`), `.d-link-label`, `.d-arrowhead` (`--amber`) pour les marqueurs, `.d-packet` (paquet lumineux qui suit un chemin via `<animateMotion>`). Les `id` de marqueurs doivent être **uniques dans toute la présentation** (préfixer par la section).

```html
<svg class="diagram" viewBox="0 0 1000 300" width="1000" height="300" role="img" aria-label="Client vers service">
  <defs>
    <marker id="s02-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path class="d-arrowhead" d="M0,0 L10,5 L0,10 z" />
    </marker>
  </defs>
  <rect class="d-node" x="40" y="100" width="280" height="100" rx="4" />
  <text class="d-label" x="180" y="140">Client</text>
  <text class="d-sub" x="180" y="175">Flutter</text>
  <rect class="d-node d-node--amber" x="680" y="100" width="280" height="100" rx="4" />
  <text class="d-label" x="820" y="150">Service</text>
  <path id="s02-l1" class="d-link" d="M320,150 L680,150" marker-end="url(#s02-arrow)" />
  <text class="d-link-label" x="500" y="135">requête</text>
  <circle class="d-packet" r="6">
    <animateMotion dur="1.6s" repeatCount="indefinite"><mpath href="#s02-l1" /></animateMotion>
  </circle>
</svg>
```

Note : `<animateMotion>` (SMIL) ne respecte pas `prefers-reduced-motion` ; les tirets CSS, si.

## 10. Diagramme de séquence

`.seq` avec `--n` = nombre d'acteurs. Les `.seq-actor` forment la première ligne ; les lignes de vie sont tracées automatiquement dans `.seq-body`. Chaque `.seq-msg` porte `--from` et `--to` (numéros d'acteurs, 1 à n). Sens droite → gauche : ajouter `.is-back`. Réponse (ambre, pointillés fins) : `.is-reply`. Remarque centrée : `.seq-note`. Acteur ambre : `.seq-actor--amber`.

```html
<div class="seq" style="--n: 3">
  <div class="seq-actor">App</div>
  <div class="seq-actor">Backend</div>
  <div class="seq-actor seq-actor--amber">Agent</div>
  <div class="seq-body">
    <div class="seq-msg fragment" style="--from: 1; --to: 2"><span class="seq-label">requête</span></div>
    <div class="seq-msg fragment" style="--from: 2; --to: 3"><span class="seq-label">tâche</span></div>
    <div class="seq-msg is-back is-reply fragment" style="--from: 3; --to: 1"><span class="seq-label">résultat</span></div>
    <div class="seq-note">une remarque</div>
  </div>
</div>
```

## 11. Tableau comparatif

`table.compare`. `.hl` sur les cellules d'une colonne (en-tête compris) pour la mettre en avant (ambre). Marqueurs de cellule : `.yes` (✓), `.no` (✕), `.partial` (◐).

```html
<table class="compare">
  <thead><tr><th>Critère</th><th>A</th><th class="hl">B (retenue)</th></tr></thead>
  <tbody>
    <tr><th>Critère 1</th><td class="yes">oui</td><td class="hl partial">partiel</td></tr>
  </tbody>
</table>
```

## 12. Bloc de code

Coloration highlight.js (thème cyan/ambre). `data-title` sur `<pre>` = barre de titre. `data-trim` retire l'indentation. `data-line-numbers="1|3-5"` affiche les numéros et met en évidence des lignes, étape par étape. Taille 22 px, hauteur max 560 px. Pour du HTML dans le code, l'échapper ou entourer de `<script type="text/template">`.

```html
<pre data-title="main.dart"><code class="language-dart" data-trim data-line-numbers="1|3-4">
void main() {
  runApp(const App());
}
</code></pre>
```

## 13. Citation

```html
<blockquote>
  <p>Une citation courte.</p>
  <cite>Auteur, source, date</cite>
</blockquote>
```

## 14. Fragments stylés

Les fragments s'affichent **automatiquement** en arrivant sur la slide (`src/autoplay.js`, 650 ms entre deux fragments, 2,2 s pour les étapes de surlignage de code). Réglages par `<section>` : `data-autoplay-step="1200"` (délai en ms) ou `data-autoplay="off"` (fragments au clic). Pas de piles verticales : une `<section>` par slide, dans l'ordre.

En plus des fragments natifs de reveal.js (`fade-up`, `highlight-red`…) :

| Classe | Effet |
|---|---|
| `fragment glow-in` | apparition avec flash lumineux |
| `fragment scan-in` | balayage gauche → droite (effet scanner) |
| `fragment rise-in` | montée depuis le bas |
| `fragment hl-cyan` / `hl-amber` / `hl-alert` | élément déjà visible, surligné au clic |
| `fragment dim-after` | s'atténue quand le fragment suivant apparaît |

```html
<li class="fragment scan-in">Apparaît en balayage</li>
<span class="fragment hl-amber">mot surligné</span>
```

## 15. Chrome fixe

`index.html` contient le cadre d'écran (`.hud-chrome`) : quatre coins et deux libellés. Pour les modifier, éditer directement `index.html`. La barre de progression et le numéro de slide (`c/t`) sont stylés dans `src/theme/jarvis.css`.
