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
| U1 | Espacements et rayons (013 D4 « non tokenisés ») | Ajout des jetons `space-1…8` et `radius-sm/md/lg/pill` comme constantes ; ils règlent **le dedans** des cellules (rayons 16/10/6, pastilles). Les 8 px de 013 sont l'écart entre **zones** de la page (`_gap`) et la marge d'écran : conservés (la gouttière 12 et la marge 32 du design system déplaceraient les rectangles de S-02 et D-01). Les cellules de la grille sont **jointives** (`cellWidth = largeur / colonnes`) : le panneau est **en retrait de 4 px** dans sa cellule pour que deux panneaux voisins gardent 8 px visibles ; la marge interne (padding) reste la **marge actuelle de 16 px** (le `space-6` de 24 px n'est pas appliqué aux cellules : il prendrait 16 px de largeur utile à des textes ≥ 24 px) ; si D-02 à D-05 échouent avec les vraies polices, bordures jointives sans retrait | Disposition 013 prouvée par tests ; NFR-05 exige de la place à 1920×1080 ; le bandeau de 72 px, le rail de 96 px et la rangée basse de 140 px gardent leurs marges |
| U2 | Apparition (013 D3 : 200 ms, 150 ms, 8 px) | `appear` 480 ms (`--gc-med`), `value` 160 ms (`--gc-fast`), translation **10 px** (`gc-rise`), courbe `Cubic(.2, .8, .2, 1)` (`--gc-ease`) ; `status` 400 ms inchangé (pas d'équivalent) ; plancher 60 ms et division par la vitesse de rejeu inchangés. **Pas de flou** « flou → net » | Un flou par surface coûte un `saveLayer` : contraire au périmètre de reconstruction et de peinture de NFR-04 (013 B1) |
| U3 | Séries du graphique (pdr-0064 D8 : couleur par plateforme) | L'identification par plateforme reste, avec des couleurs du design system **hors couleurs de statut et hors `plasma`** (qui n'est « jamais une donnée ») : iOS `ink`, Android `signal`, autre `baseline` ; la série « 3.3 » reste en pointillés (même couleur que sa plateforme) ; le seuil est en `nogo`, en tirets | Le design system dit « courante / précédente » pour une seule plateforme ; l'app trace deux plateformes à l'acte 1 et la lisibilité des deux l'emporte (pdr-0064 D8) |
| U4 | Boutons de la Barre d'actions (pdr-0065 D7) | Apparence reprise : fond `surface-300`, bordure `line-strong` (neutre) ou `nogo` (danger), texte `ink` / `nogo` ; focus `signal`. Interaction inchangée (clic, pas d'appui long) | D1 : apparence seule |
| U5 | Contour pointillé, indicateur d'acte, zone Rejeu (pdr-0063) | Contour de surbrillance en `signal` pointillé ; segment d'acte actif sur `plasma-ghost` ; curseur de rejeu sur `surface-300` ; apparence seule | D1 |
| U6 | Statuts | Fond = `*-ghost`, texte = `go` / `warn` / `nogo`, **toujours le mot** (déjà porté par les puces) ; `go` ajoute le glyphe ✓ (widget séparé, exclu de `Semantics`, pour ne pas changer les textes trouvés par les tests) ; `ink-muted` / `surface-300` pour le neutre | Principe du design system : jamais la couleur seule |
| U7 | Battement (`gc-beacon`) | Parmi les statuts, **seul** le statut Bloquant bat en continu ; les boucles existantes (liaison de délégation, orbe qui parle, cadre de génération) restent. **Toutes** les boucles passent par `SceneMotionScope.loop` et s'arrêtent sous `disableAnimations`, **y compris l'orbe et le squelette**, qui ne le faisaient pas (l'orbe n'est aujourd'hui que sous `TickerMode`). Chaque boucle a son `RepaintBoundary` local | « Si tout clignote, rien ne compte » ; cohérence du réglage d'accessibilité |
| U8 | Orbe et voix | Couleurs de l'orbe en rôles du thème : corps `plasma`, éclair `ink`, voile `orbVeil` ; halo `glow-plasma` quand l'IA parle, rendu par dégradé radial (pas de `MaskFilter.blur` repeint à 60 Hz) ; la logique audio, les états et le niveau ne changent pas | D1 ; coût de peinture (NFR-04) |
| U9 | Panneaux | Dégradé vertical `surface-200` → `surface-100`, bordure `line` 1 px, coins HUD en `line-strong`, rayon 16, ombre `panel` (sans la ligne `inset`, que `BoxShadow` ne sait pas rendre : remplacée par un filet de 1 px peint par le panneau) ; le panneau est une **couche sœur** statique placée **sous** le contenu animé, jamais une enveloppe ; `CellFrame`, `NoDataCell` et `DsSkeleton` perdent leur fond et leur rayon et gardent leur marge. Fond d'écran `void` + grille de points `line` au pas 24 px, peinte une fois dans la frontière de capture de la page | Apparence du design system ; pas de double cadre ; l'ombre ne doit pas être rognée par le `ClipRect` de l'apparition |
| U10 | Animations optionnelles (coupe possible en dernier) | `gc-row` (cascade des lignes de checklist, 180 ms) et `gc-wipe` (tracé du graphique) : livrées seulement si les tâches obligatoires sont vertes avec du temps de reste ; sinon consignées comme non faites | Utile à la scène, non requis par pdr-0083 D2 |
| U11 | Polices | **Variables** (axe `wght`) : Space Grotesk et JetBrains Mono n'existent qu'ainsi dans le dépôt Google Fonts ; poids par `FontVariation('wght', n)` **et** `fontWeight` identiques, posés par un assistant unique (y compris dans le `textTheme` de Material) ; chiffres tabulaires pour les données ; repli `DejaVu Sans` embarqué (déjà licencié dans `testing/real_fonts`) pour les glyphes manquants ; fichiers sans crochets, empreintes SHA-256 consignées avec les polices | pdr-0083 D3 ; ⚠️ rendu variable à vérifier sous Linux dès T10 |
| U12 | Scénario D-06 de 013 (apparition) | Les durées de U2 le rendent rouge tel quel (250 ms, 120 ms en ×2) : D-06 est **recalé** aux durées de U2 (≈ 500 ms ; ≈ 250 ms en ×2) par product-curate, avec renvoi à pdr-0084 U2 ; les tests unitaires d'apparition sont recalés dans la même tâche (T13) | Conséquence directe de U2, pas un changement de comportement |

## Tailles de texte (pdr-0083 D4 : tout ≥ 24 px)

| Style du design system | Taille source | Taille 017 | Hauteur de ligne | Interlettrage | Famille, graisse, couleur |
|---|---|---|---|---|---|
| `kpi-xl` (= `value` de `SceneTheme`) | 76 | 76 si la cellule 624×302 le permet, sinon la plus grande taille qui tient (consignée) | 1,0 | −0,04 em | mono 600, `ink` |
| `verdict` | 28 | 28 | 32/28 | 0,04 em | mono 700, capitales d'affichage, `ink` |
| `data` | 15 | **24** | 1,3 (conserve le calcul de lignes de 013) | 0 | mono 500, chiffres tabulaires, `ink` |
| `label` | 11 | **24** | 1,3 | 0,14 em | mono 500, capitales d'affichage, `ink-muted` |
| `title` | 18 | **24** | 1,2 | 0 | sans 600, `ink` |
| `transcript` | 20 | **24** | 1,3 | 0 | sans 500, `ink` |
| `body` | 15 | **24** | 1,3 | 0 | sans 400, `ink` (secondaire `ink-muted`) |
| `button` | 15 | **24** | 1,3 | 0 | sans 600, `ink` |
| `actIndicator` (existant) | — | 28 | 1,2 | 0 | sans 700, `ink` |
| `ink-faint` | ≥ 13 | ≥ 24 | — | — | graduations et « en veille » uniquement (3,9:1 sur `surface-100`, moins sur `surface-200` et `surface-300` : « grand texte », 3:1) |

**Hauteurs de ligne** : celles de 013 (1,2 à 1,3) sont conservées, pas les rapports de la source (1,47 pour `body`) : `lineHeightOf` fixe le nombre de lignes visibles des avis (D-02 : « 1 à 2 extraits »). **Capitales** : seulement à l'affichage ; les chaînes de données, `Semantics` et textes trouvés par les tests restent inchangés. **`label`** est réservé aux étiquettes HUD en capitales (« AGENTS A2A », « CATALOGUE ») ; les 31 usages actuels sont répartis par T12b : puces de statut, noms d'agents et étagère passent sur `data` ou `body`, non en capitales.

Les styles actuels de `SceneTheme` (`body`, `label`, `value`, `title`, `actIndicator`) gardent leur nom ; `data`, `verdict`, `transcript`, `button` s'ajoutent. Rôles d'orbe ajoutés : `orbVeil` (le corps est `plasma`, l'éclair est `ink`). `onNogo` n'est **pas** ajouté (il ne sert qu'au bouton « Bloquer » rempli par appui long : hors périmètre).

## Scénarios (Gherkin)
Nouveaux ; ajoutés à `product/functional/features/design-system-017.feature` à l'étape Gherkin (product-curate), puis automatisés dans `test/acceptance/`. Les scénarios de 013 (S-02, D-01 à D-07) doivent rester verts **avec les polices embarquées** ; **D-06 est recalé aux durées de U2** (U12). U-01 et U-03 sont des garde-fous : ils sont **déjà verts** avant 017 (U-03 aussi, puisque les polices de test sont celles de 013) et doivent le rester ; U-02, U-04, U-05 et U-06 sont rouges au départ.
- **U-01** Aucun texte sous 24 px : actes 1, 2 et 3 rejoués en 1920×1080, tout texte visible a une taille ≥ 24 px.
- **U-02** Polices embarquées : les valeurs, deltas, seuils et étiquettes sont en JetBrains Mono (chiffres tabulaires), les autres textes en Space Grotesk ; les deux familles viennent des assets du paquet (aucune police chargée au réseau : pas de dépendance `google_fonts`).
- **U-03** Disposition inchangée : avec les polices embarquées, D-01 à D-07 et S-02 restent verts (mêmes rectangles, aucune ellipse de libellé).
- **U-04** Statuts : pour chaque statut, le mot est affiché avec sa couleur de design system ; `go` ajoute ✓ ; les paires texte/fond (fonds `*-ghost` composés sur le panneau) respectent AA.
- **U-05** Mouvement : une surface apparaît en 480 ms avec 10 px de glissement ; sous `disableAnimations` elle apparaît immédiatement, orbe et squelette compris ; parmi les statuts, seul Bloquant bat en continu.
- **U-06** Graphique : séries aux couleurs de l'U3, « 3.3 » en pointillés, seuil `nogo` en tirets.

## Critères d'acceptation
- [ ] Scénarios U-01 à U-06 automatisés et verts ; S-02 et D-01 à D-07 toujours verts (D-06 aux durées de U2)
- [ ] Tests unitaires des unités nouvelles (tokens, thème, mouvement, panneau, statuts, séries)
- [ ] Tokens régénérés : `tokens_hash_test` et `tokens_parity_test` verts
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Capture `app-smoke` à 1920×1080 des scénarios `act1-replay` et d'un scénario des actes 2 et 3, comparée aux `preview.html` de la source : écarts consignés dans `status.md`
- [ ] Aucun texte < 24 px (U-01) ; licences OFL des deux polices livrées avec elles et enregistrées dans `LicenseRegistry`

## Questions ouvertes
- Q-91 tranchée → pdr-0083 D4. Aucune nouvelle question bloquante. Le porteur juge le rendu à 24 px minimum en répétition (pdr-0083, Réexaminer si).
