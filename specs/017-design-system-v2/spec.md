# 017 — Application du design system du 2026-11-02 (UI seulement)

> **En bref.** L'app prend l'habillage du design system « Genesis Canvas » du 2026-11-02 : palette, polices embarquées (Space Grotesk, JetBrains Mono), styles de texte, ombres, mouvement, apparence des panneaux, des statuts, du graphique et de l'orbe. Le comportement, les données, le contrat A2UI et la disposition de 013 ne bougent pas, et aucun texte ne passe sous 24 px.

- **Jalon** : avant J7 (`product/roadmap/backlog.md`, section 017) ; EP-04, EP-01.
- **Exigences visées** : NFR-05 (texte ≥ 24 px, lisible du fond de la salle), NFR-04 (60 i/s : périmètre de reconstruction, `RepaintBoundary`), NFR-10 (build reproductible : polices embarquées), FR-04 (apparition en trois temps), RG-09 (`SceneTheme` unique `ThemeExtension`), RG-29.
- **Décisions applicables** : [pdr-0083-design-system-v2-ui-only](../../product/decisions/pdr-0083-design-system-v2-ui-only.md) (D1 portée, D2 fonctionnalité, D3 contraintes, **D4 tailles ≥ 24 px**), [pdr-0075](../../product/decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md), [pdr-0072](../../product/decisions/pdr-0072-design-ergonomics-013.md), [pdr-0079](../../product/decisions/pdr-0079-013-tokens-exception-to-adr-0005.md), [pdr-0062](../../product/decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md), [pdr-0007](../../product/decisions/pdr-0007-closed-catalog-stage-theme.md), [pdr-0017](../../product/decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md) ; [adr-0004](../../knowledge/decisions/adr-0004-ds-visual-base-m3.md), [adr-0005](../../knowledge/decisions/adr-0005-ds-tokens-style-dictionary.md), [adr-0008](../../knowledge/decisions/adr-0008-ds-widgetbook-4-beta.md).
- **Source** : `product/sources/design-system-2026-11-02/` (`tokens.json`, `components/bundle.css`, `components/*/preview.html`). Elle fait foi pour l'**UI** ; la fiche et `product/` font foi pour l'UX et le métier (D1).
- **Notes `knowledge/`** : [ds-tokens-style-dictionary], [ds-tokens-theme-extension], [ds-motion], [ds-a11y-wcag-contrast], [ds-typography], [ds-widgetbook-4-testing], [perf-repaint-boundary], [test-golden-alchemist].

## Hors périmètre
- Tout ce qui est UX ou métier dans les exemples du design system (pdr-0083, Conséquences) : appui long et reçu nominatif sur « Bloquer », règle « À risque » (marge < 0,1 pt), critique des deltas, ordre des agents, nombre de verbatims, bande Décision vide, données et messages d'exemple, **compteur `data-count`** (il afficherait des valeurs intermédiaires qui ne sont pas des données).
- Le contrat A2UI, le catalogue fermé de six composants (pdr-0007, pdr-0014), le backend Go, les agents, le canal app ↔ backend : aucune modification Go.
- La disposition de 013 : rail horizontal de 96 px, cellules de 624×302 et 936×302, marge de 8 px, grille 2×2 puis 3×2, Barre d'actions de 72 px (S-02, D-01 à D-07).
- Le thème clair, le 1366×768, Widgetbook Cloud, l'export vers Claude Design.
- La mesure des 60 i/s au profil `--profile` sur la machine de démo (J7, répétition).

## Décisions d'UI de la boucle (pdr-0062 ; à enregistrer dans la PDR d'assistant de l'étape Définir)

| # | Point (pdr-0083, Conséquences) | Décision de la boucle | Raison |
|---|---|---|---|
| U1 | Espacements et rayons (013 D4 « non tokenisés ») | Ajout des jetons `space-1…8` et `radius-sm/md/lg/pill` comme constantes ; ils règlent **le dedans** des cellules (padding des panneaux 24, rayons 16/10/6, pastilles). Gouttière 8 px et marge d'écran de 8 px de 013 conservées (la gouttière 12 et la marge 32 du design system déplaceraient les rectangles de S-02 et D-01) | Disposition 013 prouvée par tests ; NFR-05 exige de la place à 1920×1080 |
| U2 | Apparition (013 D3 : 200 ms, 150 ms, 8 px) | `appear` 480 ms (`--gc-med`), `value` 160 ms (`--gc-fast`), translation **10 px** (`gc-rise`), courbe `Cubic(.2, .8, .2, 1)` (`--gc-ease`) ; `status` 400 ms inchangé (pas d'équivalent) ; plancher 60 ms et division par la vitesse de rejeu inchangés. **Pas de flou** « flou → net » | Un flou par surface coûte un `saveLayer` : contraire au périmètre de reconstruction et de peinture de NFR-04 (013 B1) |
| U3 | Séries du graphique (pdr-0064 D8 : couleur par plateforme) | L'identification par plateforme reste, avec des couleurs du design system **hors couleurs de statut et hors `plasma`** (qui n'est « jamais une donnée ») : iOS `ink`, Android `signal`, autre `baseline` ; la série « 3.3 » reste en pointillés (même couleur que sa plateforme) ; le seuil est en `nogo`, en tirets | Le design system dit « courante / précédente » pour une seule plateforme ; l'app trace deux plateformes à l'acte 1 et la lisibilité des deux l'emporte (pdr-0064 D8) |
| U4 | Boutons de la Barre d'actions (pdr-0065 D7) | Apparence reprise : fond `surface-300`, bordure `line-strong` (neutre) ou `nogo` (danger), texte `ink` / `nogo` ; focus `signal`. Interaction inchangée (clic, pas d'appui long) | D1 : apparence seule |
| U5 | Contour pointillé, indicateur d'acte, zone Rejeu (pdr-0063) | Contour de surbrillance en `signal` pointillé ; segment d'acte actif sur `plasma-ghost` ; curseur de rejeu sur `surface-300` ; apparence seule | D1 |
| U6 | Statuts | Fond = `*-ghost`, texte = `go` / `warn` / `nogo`, **toujours le mot** (déjà porté par les puces) ; `go` ajoute le glyphe ✓ (widget séparé, exclu de `Semantics`, pour ne pas changer les textes trouvés par les tests) ; `ink-muted` / `surface-300` pour le neutre | Principe du design system : jamais la couleur seule |
| U7 | Battement (`gc-beacon`) | Une animation en boucle **seulement** pour le statut Bloquant (et les boucles existantes : liaison de délégation, orbe qui parle, cadre de génération) ; tout s'arrête sous `disableAnimations` | « Si tout clignote, rien ne compte » |
| U8 | Orbe et voix | Couleurs de l'orbe en `plasma` / `plasma-ghost`, halo `glow-plasma` quand l'IA parle ; la logique audio, les états et le niveau ne changent pas | D1 |
| U9 | Panneaux | Dégradé vertical `surface-200` → `surface-100`, bordure `line` 1 px, coins HUD en `line-strong`, rayon 16, ombre `panel` ; fond d'écran `void` + grille de points `line` au pas 24 px, peinte une fois (`RepaintBoundary`) | Apparence du design system |
| U10 | Animations optionnelles (coupe possible en dernier) | `gc-row` (cascade des lignes de checklist, 180 ms) et `gc-wipe` (tracé du graphique) : livrées seulement si les tâches obligatoires sont vertes avec du temps de reste ; sinon consignées comme non faites | Utile à la scène, non requis par pdr-0083 D2 |
| U11 | Polices | **Variables** (axe `wght`) : Space Grotesk et JetBrains Mono n'existent qu'ainsi dans le dépôt Google Fonts ; poids par `FontVariation('wght', n)` ; chiffres tabulaires pour les données ; repli `Noto Sans` / `DejaVu Sans` (présentes sur la machine de démo Linux) | pdr-0083 D3 ; ⚠️ rendu variable à vérifier sous Linux (T01) |

## Tailles de texte (pdr-0083 D4 : tout ≥ 24 px)

| Style du design system | Taille source | Taille 017 | Famille, graisse, couleur |
|---|---|---|---|
| `kpi-xl` | 76 | 76 si la cellule 624×302 le permet, sinon la plus grande taille qui tient (consignée) | mono 600, `ink` |
| `verdict` | 28 | 28 | mono 700, capitales, `ink` |
| `data` | 15 | **24** | mono 500, chiffres tabulaires, `ink` |
| `label` | 11 | **24** | mono 500, capitales, interlettrage .14 em, `ink-muted` |
| `title` | 18 | **24** | sans 600, `ink` |
| `transcript` | 20 | **24** | sans 500, `ink` |
| `body` | 15 | **24** | sans 400, `ink` (secondaire `ink-muted`) |
| `button` | 15 | **24** | sans 600, `ink` |
| `ink-faint` | ≥ 13 | ≥ 24 | graduations et « en veille » uniquement (3,9:1 : « grand texte », 3:1) |

Les styles actuels de `SceneTheme` (`body`, `label`, `value`, `title`, `actIndicator`) gardent leur nom ; `data`, `verdict`, `transcript`, `button` s'ajoutent. L'indicateur d'acte (28 px) reste ≥ 24.

## Scénarios (Gherkin)
Nouveaux ; ajoutés à `product/functional/features/design-system-017.feature` à l'étape Gherkin (product-curate), puis automatisés dans `test/acceptance/`. Les scénarios de 013 (S-02, D-01 à D-07) doivent rester verts **avec les polices embarquées**.
- **U-01** Aucun texte sous 24 px : actes 1, 2 et 3 rejoués en 1920×1080, tout texte visible a une taille ≥ 24 px.
- **U-02** Polices embarquées : les valeurs, deltas, seuils et étiquettes sont en JetBrains Mono (chiffres tabulaires), les autres textes en Space Grotesk ; les deux familles viennent des assets du paquet (aucune police chargée au réseau : pas de dépendance `google_fonts`).
- **U-03** Disposition inchangée : avec les polices embarquées, D-01 à D-07 et S-02 restent verts (mêmes rectangles, aucune ellipse de libellé).
- **U-04** Statuts : pour chaque statut, le mot est affiché avec sa couleur de design system ; `go` ajoute ✓ ; les paires texte/fond (fonds `*-ghost` composés sur le panneau) respectent AA.
- **U-05** Mouvement : une surface apparaît en 480 ms avec 10 px de glissement ; sous `disableAnimations` elle apparaît immédiatement ; seul le statut Bloquant bat en continu.
- **U-06** Graphique : séries aux couleurs de l'U3, « 3.3 » en pointillés, seuil `nogo` en tirets.

## Critères d'acceptation
- [ ] Scénarios U-01 à U-06 automatisés et verts ; S-02 et D-01 à D-07 toujours verts
- [ ] Tests unitaires des unités nouvelles (tokens, thème, mouvement, panneau, statuts, séries)
- [ ] Tokens régénérés : `tokens_hash_test` et `tokens_parity_test` verts
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Capture `app-smoke` à 1920×1080 des scénarios `act1-replay` et d'un scénario des actes 2 et 3, comparée aux `preview.html` de la source : écarts consignés dans `status.md`
- [ ] Aucun texte < 24 px (U-01) ; licences OFL des deux polices livrées avec elles et enregistrées dans `LicenseRegistry`

## Questions ouvertes
- Q-91 tranchée → pdr-0083 D4. Aucune nouvelle question bloquante. Le porteur juge le rendu à 24 px minimum en répétition (pdr-0083, Réexaminer si).
