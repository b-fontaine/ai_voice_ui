# 019 — Fidélité au design system pour l'UI, animations comprises

> **En bref.** L'app reprend la **structure visuelle** de chaque composant du design system du 2026-11-02 (`components/<Nom>/preview.html` et `bundle.css`) aux **tailles du design system** (le minimum de 24 px est retiré, NFR-05 suspendue) et ses **animations** (README § Mouvement). L'UX, les données, le contrat A2UI et la grille de page (rail de 96 px, rectangles des cellules) ne bougent pas. Elle vérifie aussi l'indicateur d'acte en rejeu.

- **Jalon** : avant J7 (`product/roadmap/backlog.md`, section 019) ; EP-04, EP-01.
- **Exigences visées** : FR-04 (apparition en trois temps), FR-06, NFR-04 (60 i/s : périmètre de reconstruction, `RepaintBoundary`), NFR-05 (**suspendue** : contraste AA maintenu, plus de seuil de taille), RG-09 (`SceneTheme` unique `ThemeExtension`), RG-29.
- **Décisions applicables** : [pdr-0087](../../product/decisions/pdr-0087-design-system-fidelity-no-24px-minimum.md) (D1 tailles, D2 fidélité, D3 animations, D4 portée inchangée, D5 la fonctionnalité) ; [pdr-0083](../../product/decisions/pdr-0083-design-system-v2-ui-only.md) D1 à D3 (UI seulement, polices embarquées, contraintes) ; [pdr-0084](../../product/decisions/pdr-0084-017-design-system-ui-details-assistant-decided.md) pour ce que pdr-0087 ne remplace pas (U3 séries, U4 boutons, U5, U6, U7, U9, U11, U12, U15 a, b, d) ; [pdr-0075](../../product/decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md) ; [pdr-0062](../../product/decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md) ; [pdr-0017](../../product/decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md) ; [pdr-0007](../../product/decisions/pdr-0007-closed-catalog-stage-theme.md) ; **détails d'interface de cette fonctionnalité : [pdr-0088](../../product/decisions/pdr-0088-019-design-system-fidelity-ui-details-assistant-decided.md)** (tranchés par la boucle, contestables).
- **Source** : `product/sources/design-system-2026-11-02/` (`tokens.json`, `components/bundle.css`, `components/*/preview.html`, `components/EcranActe3/preview.html` pour l'écran composé). Elle fait foi pour l'**UI** ; la fiche et `product/` font foi pour l'UX et le métier (pdr-0083 D1).
- **Notes** : [p-ar-design-system](../../product/architecture/design-system.md), [p-ar-design-system-look](../../product/architecture/design-system-look.md) ; `ds-motion`, `ds-a11y-wcag-contrast`, `ds-tokens-style-dictionary`, `ds-tokens-theme-extension`, `perf-repaint-boundary`, `ds-widgetbook-4-*`.

## Contexte
017 a appliqué les jetons (couleurs, polices embarquées, ombres, durées) mais gardé la structure visuelle de 013 et la règle des 24 px, qui grossit tout. La capture de 017 (`.omc/state/loop/snapshots/20261102-214513-act3-replay.png`) s'écarte des `preview.html` : pas de jauge ni de zone sous la courbe, pas de tableau pour la checklist, verbatims sans carte, rail et barre vocale sans leur habillage, aucune des animations `gc-row`, `gc-wipe`, `gc-spin`/`gc-scan`, compteur. Le porteur veut « un design un peu plus attractif » : 019 comble l'écart.

## Périmètre

| Zone de l'app | Source (`components/…`) | Ce qui change (apparence seulement) |
|---|---|---|
| Échelle de texte (`SceneTheme`) | `tokens.json` § type, `bundle.css` | Tailles du design system : `kpi-xl` 76, `verdict` 28, `data` 15, `label` 11 (capitales, interlettrage 0,14 em), `title` 18, `transcript` 20, `body` 15, `button` 15, plus les micro-styles de `bundle.css` (badge 12, tick 12, chip 13, vitesse 12, delta 14, méta de verbatim 12…) ; plus de plancher de 24 px |
| Panneaux | `bundle.css` `.gc-panel` | Remplissage 20/24, en-tête `gc-panel__head` (étiquette à gauche, statut à droite), coins HUD à 8 px du bord, apparition `gc-rise` avec **flou → net** et échelle .985 |
| `KeyIndicator` | `KeyIndicator/` | Valeur 76 px et unité 36 px, lueur `nogo` sur la valeur si bloquante, **jauge** `gc-gauge` (remplissage, marque de seuil avec étiquette, repère 3.3), deltas en deux colonnes : « Tendance » (`trend`) puis « vs <étiquette de la comparaison> » (pas de « vs seuil » calculé : Q-94) ; valeur et unité dans un seul `Text.rich` |
| `TrendChart` | `TrendChart/` | Légende à traits, grille, axe des valeurs, **zone sous la série courante**, **zone de franchissement** du seuil, point de tête, annotation « ▲ seuil franchi » et valeur de tête |
| `ReleaseChecklist` | `ReleaseChecklist/` | **Tableau** critère · seuil · valeur · statut (en-têtes en `label` ; l'en-tête de la 3e colonne est neutre, aucune version en dur), lignes en `surface-200` à coins arrondis, liseré `nogo` de 3 px sur les lignes bloquantes, verdict en grande puce, compteur « n bloquants / total » |
| `ReviewSentiment` | `ReviewSentiment/` | **Barre de répartition** positifs / négatifs, légende, verbatims en **cartes** `surface-300` (note et plateforme à gauche) |
| `ActionBar`, boutons | `ActionBar/` | Boutons `gc-btn` (44 px, rayon `md`), danger (lueur `nogo`), désactivé en tirets ; étiquette du bandeau (le `title` de la surface `/actions`, pas un littéral) |
| `StatusBadge` | `StatusBadge/` | Puce pilule 26 px, capitales, interlettrage 0,08 em, grande puce 40 px pour le verdict |
| `AgentRail` | `AgentRail/` | Étiquette « Agents A2A », **tuiles** (nom, état), orchestrateur en `plasma` (point lumineux, bordure), au travail (bordure et état `signal`, barre indéterminée), terminé (point `go`, ✓) ; les 5 autres états de l'app (en attente, échec, hors périmètre, interrompu, en veille) gardent leur rendu actuel, habillé aux jetons ; liaisons de délégation (015) à revérifier |
| Barre vocale (`TopBar`, `StageBar`, orbe) | `VoiceBar/`, `EcranActe3/` | Orbe à **anneaux**, transcription « VOUS » / « IA » avec curseur, **onde** quand l'IA parle, **sélecteur d'actes en segments** (01 ✓ / 02 ✓ / 03), boutons du haut `sm` (micro avec point d'enregistrement, « Faire taire », « Remettre à vide » fantômes) |
| `GenerationFrame` | `GenerationFrame/` | Cadre animé (arc tournant `gc-spin`, balayage `gc-scan`, étiquette « <Agent> · génère ») autour de la surface en cours de génération, fondu à la fin |
| Pied (`CatalogShelf`, `ReplayBar`, `ProtocolPanel`) | `ConsoleDock/` | Catalogue en **puces** (utilisée / nouvelle `gc-flash`), rejeu (boutons icône, piste et poignée, vitesses en segments, étiquette « Direct »), flux A2UI en **liste mono** défilante (`#nn`, genre en `signal`) |

## Animations (README § Mouvement, `bundle.css` ; pdr-0087 D3, pdr-0088)

Durées 160 ms (`fast`), 480 ms (`med`), 1,4 s (`slow`), courbe `cubic-bezier(.2,.8,.2,1)` ; **tout s'arrête sous `disableAnimations`** (une seule source : `SceneMotionScope`) et **toute boucle a son `RepaintBoundary`** local.

| Niveau | Animations |
|---|---|
| **A (obligatoires)** | `gc-rise` (flou → net, +10 px, échelle .985) ; `gc-row` (lignes de la checklist en cascade, 180 ms de décalage) ; `gc-wipe` (tracé du graphique, de gauche à droite) ; compteur `data-count` (KPI de 100 % vers sa valeur) ; transitions de largeur de la jauge et de la barre de répartition (`--gc-slow`) ; `gc-spin` + `gc-scan` (cadre de génération, dernier tour puis fondu) ; `gc-beacon` (statut Bloquant seul) ; `gc-wave` et `gc-orbring` (l'IA parle) ; `gc-flash` (composant de catalogue nouvellement utilisé) |
| **B (coupables en dernier)** | `gc-indet` (barre indéterminée d'un agent au travail), `gc-blink` (curseur de transcription, point « Direct », point d'enregistrement, étiquette du cadre), `gc-ring` (anneau du point de tête), `gc-breathe` (noyau de l'orbe), apparition ligne à ligne du flux A2UI (`gc-row` à 350 ms) |

Les captures `app-smoke` tournent **sans animation** (`_animationsOff` en mode scénario et en capture) : les animations se prouvent par des tests de widget à horloge simulée (présence, durées, état final, arrêt sous `disableAnimations`), jamais par la capture.

## Exclusions (UX et métier : inchangés, pdr-0087 D4)
Appui long et reçu nominatif (le clic de la Barre d'actions reste un clic ; pas de remplissage `gc-hold`), « Valider » désactivé tant qu'un critère bloque, règle « À risque », valeurs et deltas affichés, nombre de verbatims, ordre des agents, données d'exemple, « Recommandation IA » et reçu du design system (aucune source de données dans l'app), clic sur l'indicateur d'acte qui passe à l'acte suivant (pdr-0063), contrat A2UI, grille de page, rail de 96 px, rectangles de cellules (sauf nécessité tranchée dans pdr-0088).

## À vérifier : l'indicateur d'acte en rejeu
La capture `act3-replay` de 017 affiche « Acte 1/3 · Créer ». **Confirmé à la lecture du code (revue du plan P8), à verrouiller par un test (T40)** : effet attendu du mode scénario (`GenesisCanvasPage._reachAct` ne fait rien en mode scénario ni pendant le rejeu : « un message rejoué ou vivant ne décrit pas l'avancement de la démo »), non un bogue de l'app ; en rejeu réel (`ReplayActive`) l'indicateur affiche « Acte 4 · Rejeu ». Si le test infirme l'hypothèse, correction (bogue) ; sinon, consigner l'effet et, si utile à la lecture des captures, l'expliquer dans `app-smoke` (hors périmètre de la boucle : `tools/loop/` est interdit) via `status.md`.

## Scénarios (Gherkin)
Nouveaux ; ajoutés à `product/functional/features/design-system-019.feature` à l'étape Gherkin (product-curate), puis automatisés dans `test/acceptance/`. Tests de 013 et 017 qui fixent des tailles ≥ 24 px (U-01, D-02…) ou la structure d'avant (U-04…) : **recalés** par 019 avec renvoi à pdr-0087 ; ceux qui fixent des rectangles de cellules (S-02, D-01, D-03, D-07…) restent verts.
- **V-01** Échelle de texte : chaque style de `SceneTheme` a la taille de `tokens.json` ; aucun texte visible aux actes 1 à 3 n'est hors de cette échelle (remplace U-01).
- **V-02** KeyIndicator : jauge avec remplissage proportionnel, marque de seuil étiquetée, repère étiqueté par la comparaison ; deltas alignés « Tendance » et « vs <comparaison> » ; donnée absente ou illisible → élément absent et chaîne telle quelle, jamais inventé ; aucun « vs seuil ».
- **V-03** TrendChart : légende, grille, axe, zone sous la série courante, zone de franchissement à partir de l'abscisse interpolée du premier franchissement strict du seuil (Android 3.4 vaut 0,50 à J4 : « dès J5 »), point de tête, annotation de franchissement dérivée de la série (absente si pas de franchissement).
- **V-04** ReleaseChecklist : tableau à quatre colonnes (en-tête de valeur neutre), ligne bloquante teintée avec liseré, verdict en grande puce, compteur « n bloquants / total » tiré des codes de niveau par une fonction pure.
- **V-05** ReviewSentiment : barre de répartition, légende, verbatims en cartes.
- **V-06** Rail : étiquette, tuiles, trois états (orchestrateur, au travail, terminé) avec leurs couleurs.
- **V-07** Barre vocale : orbe à anneaux, transcription « VOUS » / « IA », segments d'actes (fait / actif / à venir), boutons du haut.
- **V-08** Cadre de génération autour de la surface en cours, retiré quand elle est complète.
- **V-09** Actions et statuts : apparence des boutons (neutre, danger, désactivé en tirets) et des puces (pilule 26 px, capitales).
- **V-10** Pied : puces du catalogue, rejeu (piste, vitesses), flux A2UI en liste mono.
- **V-11** Contraste : tout texte de moins de 24 px est à 4,5:1 au moins sur son fond réel (jamais `ink-faint` ni `agentIdle`) ; garde sur les usages de `inkFaint` (pdr-0088 F12).
- **A-01** Apparition : une surface apparaît en 480 ms, de flou et de 10 px vers le net ; immédiate sous `disableAnimations` (remplace U-05 pour le flou).
- **A-02** Cascade : les lignes de la checklist apparaissent l'une après l'autre (180 ms de décalage).
- **A-03** Tracé : le graphique se dévoile de gauche à droite ; le point de tête apparaît ensuite.
- **A-04** Compteur et jauges : le KPI descend de 100 % à sa valeur en 1,4 s ; la jauge et la barre de répartition se remplissent.
- **A-05** Cadre de génération : tourne pendant la génération, un dernier tour puis fondu à la fin.
- **A-06** Voix : onde et anneaux seulement quand l'IA parle ; seul Bloquant bat parmi les statuts ; une nouvelle puce de catalogue s'illumine.
- **A-07** Mouvement réduit : aux actes 1 à 3, en scénario puis sous `disableAnimations`, aucune animation ne tourne sur toute la page (`transientCallbackCount == 0`, pied et panneau du protocole compris), état final affiché.
- **I-01** Indicateur d'acte : en rejeu réel, « Acte 4 · Rejeu » ; en mode scénario (fixtures `*-replay` sans vivant), il reste à l'état initial « Acte 1/3 » ; en vivant, il avance jusqu'à 3. Les captures des actes 2 et 3 montrent donc le segment 01 actif.

## Critères d'acceptation
- [ ] Scénarios V-01 à V-11, A-01 à A-07 et I-01 automatisés et verts ; S-02, D-01 à D-07, R-01, RB-01 à RB-03 toujours verts (D-06 et U-0x recalés avec renvoi à pdr-0087 là où la taille ou la durée change)
- [ ] Tests unitaires des unités nouvelles (échelle de texte, mouvement, jauge, zones du graphique, tableau, cartes, tuiles, segments, cadre de génération, puces)
- [ ] Tokens régénérés (`tokens_hash_test`, `tokens_parity_test` verts) si l'échelle de texte ou les durées de `tokens.json` changent
- [ ] `no_hardcoded_style_test` recalé (plus de plancher de 24 px : aucun `fontSize:` littéral hors `packages/shared/design_system`)
- [ ] Widgetbook : les histoires des composants changés compilent et rendent la nouvelle structure
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Captures `app-smoke` 1920×1080 des actes 1, 2 et 3 comparées côte à côte aux `preview.html` : écarts consignés dans `status.md`
- [ ] Contraste AA maintenu (tests existants), mesure des 60 i/s au profil : **J7, répétition** (hors porte)

## Questions ouvertes
Aucune bloquante. À observer en répétition : lisibilité au fond de la salle (pdr-0087 D1, « Réexaminer si »), 60 i/s avec le flou de `gc-rise` (pdr-0088, repli prévu).
