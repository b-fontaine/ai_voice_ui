# Genesis Canvas

Le système visuel de Genesis Canvas, la démo d'UI générative pour piloter une release mobile à la voix : des agents A2A composent l'écran en direct via A2UI, l'humain tranche. Style HUD de salle de contrôle : fond nuit, une seule couleur vivante, des chiffres qui se lisent du dernier rang.

## Principes

1. **Une couleur vivante.** `signal` (cyan) = ce qui est en train de se passer : série courante, agent au travail, flux A2UI. `plasma` (violet) = la voix de l'orchestrateur. Elles ne se mélangent jamais en dégradé.
2. **Le rouge est rare.** `nogo` est la seule couleur qui pulse. Si tout clignote, rien ne compte.
3. **Chaque chiffre dit contre quoi il se mesure.** « −0,07 pt vs seuil », « −0,28 pt vs 3.3 ». Pas de delta orphelin.
4. **Les données sont en mono.** JetBrains Mono tabulaire pour tout ce qui se compare ; Space Grotesk pour les mots.
5. **Le mouvement montre le travail des agents**, pas de la décoration : un panneau qui apparaît, une ligne qui s'écrit, un cadre qui tourne pendant la génération. Tout s'arrête sous `prefers-reduced-motion`.
6. **L'humain décide.** La décision finale est un appui long avec un reçu nominatif.

## Fondations visuelles

- **Fond** : `void` + grille de points `line` au pas `space-6` (24px). Les panneaux sont en `surface-200` → `surface-100`, bordure `line`, coins HUD en `line-strong`, rayon `radius-lg`, ombre `panel`.
- **Statuts** : `go` ✓, `warn`, `nogo`, toujours avec le mot. `go` et `nogo` diffèrent en luminance, pas seulement en teinte.
- **Séries** : courante `signal` pleine ; précédente `baseline` pointillée ; seuil `nogo` en tirets. Jamais deux bleus proches.
- **Texte** : `ink` sur toutes les surfaces (≥ 15:1), `ink-muted` pour le secondaire (≥ 7:1), `ink-faint` réservé aux graduations et à l'état « en veille » (3,9:1, ≥ 13px).
- **Typo** : `kpi-xl` 76px pour LE chiffre, `transcript` 20px, `title` 18px, `data` 15px mono, `label` 11px capitales espacées.

## Mouvement

Variables dans `components/bundle.css` : `--gc-fast` 160 ms (survol, appui), `--gc-med` 480 ms (apparition d'un panneau `gc-rise`), `--gc-slow` 1,4 s (compteurs, jauges, tracé). Courbe `--gc-ease` = cubic-bezier(.2,.8,.2,1).

| Animation | Quand |
| --- | --- |
| `gc-rise` (flou → net, +10px) | un composant A2UI arrive à l'écran |
| `gc-row` (cascade 180 ms) | l'agent écrit les lignes de la checklist |
| `gc-wipe` | tracé du graphique |
| compteur `data-count` | KPI qui descend de 100 % vers sa valeur |
| `gc-spin` + `gc-scan` | cadre de génération actif |
| `gc-beacon` | seul le statut Bloquant |
| `gc-wave`, `gc-orbring` | l'IA parle |

## Iconographie

Pas de pictogrammes illustratifs. Glyphes typographiques seulement : ✓ (validé), ▲ (franchissement), ▶ ↺ (rejeu), ◆ (génération), points de statut. Pas d'emoji.

## Règles pour la démo

- **Cohérence des chiffres** : la moyenne 7 j du graphique = le KPI ; le delta affiché = la différence réelle. Dans les captures d'origine, « −0,54 pt » ne correspond ni au seuil (−0,07) ni à la 3.3 (−0,28) : quelqu'un dans la salle le verra.
- **« À risque »** doit avoir une règle écrite (ici : marge < 0,1 pt). Sinon un 99,57 % ≥ 99,50 % marqué orange paraît arbitraire.
- **Ordre des agents fixe** entre les actes.
- **Transcription propre**, 2 lignes max, jamais tronquée par « … ».
- **Pas de zone vide** : à l'acte 1, la bande Décision vide laisse un trou ; masquez-la ou montrez-la en attente.

## Consommer

Charger `tokens.css` puis `components/bundle.css` (qui importe Space Grotesk et JetBrains Mono depuis Google Fonts). Les composants sont des classes `gc-*` en HTML/CSS ; voir chaque `components/<Nom>/preview.html`. Pour Flutter, transposer les tokens dans un `ThemeExtension` et les durées dans des `Duration` constantes.
