---
id: pdr-0088-019-design-system-fidelity-ui-details-assistant-decided
title: "PDR-0088 — 019 : détails d'interface de la fidélité au design system (échelle de texte, jauge, annotation, animations de niveau B, flou, capitales, indicateur d'acte), tranchés par la boucle"
area: decisions
status: validated
updated: 2026-11-03
sources: [specs/019-design-system-fidelity/spec.md, specs/019-design-system-fidelity/plan.md, product/sources/design-system-2026-11-02/README.md, product/sources/design-system-2026-11-02/tokens.json, product/sources/design-system-2026-11-02/components/bundle.css]
links: [pdr-0087-design-system-fidelity-no-24px-minimum, pdr-0083-design-system-v2-ui-only, pdr-0084-017-design-system-ui-details-assistant-decided, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0063-007-stage-ui-details-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0017-source-hierarchy-sheet-over-mockups, p-ar-design-system, p-ar-design-system-look, p-fn-nfr]
tags: [pdr, decision, design-system, ui, 019]
decision_status: acceptée
decided_on: 2026-11-03
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0088 — 019 : détails d'interface de la fidélité au design system

> **En bref.** Pour mettre en œuvre [pdr-0087](pdr-0087-design-system-fidelity-no-24px-minimum.md), la boucle tranche les détails d'interface que la fiche et le design system laissent muets : échelle de texte complète, domaine de la jauge, annotation du graphique, animations de niveau B, flou de l'apparition, capitales, indicateur d'acte en rejeu. Détails tranchés sous pdr-0062 ; le porteur peut les contester. Les vrais choix (périmètre, mise en scène, budget) restent au porteur.

Part de l'assistant : décisions d'interface prises par la boucle, pas des arbitrages du porteur.

## Contexte
pdr-0087 demande une UI fidèle au design system (structure et animations) sans minimum de 24 px, UX et données inchangées. Le design system est écrit pour un écran de 1440 px en HTML/CSS ; l'app est un écran Flutter de 1920×1080 aux rectangles de cellules fixés (013, 017, 018). Des points ne se transposent pas sans choix.

## Décision
- **F1 Échelle de texte.** `SceneTheme` suit `tokens.json` : `kpi-xl` 76 (mono 600), `verdict` 28 (mono 700), `data` 15 (mono 500), `label` 11 (mono 500, capitales, 0,14 em), `title` 18 (sans 600), `transcript` 20 (sans 500), `body` 15 (sans 400), `button` 15 (sans 600), `actIndicator` 28 conservé (hors design system, 017). **Micro-styles tirés de `bundle.css`** (valeurs littérales du CSS, nommés dans le thème) : `badge` 12 mono 600 (0,08 em, capitales), `badgeLg` 18 mono 600 (0,1 em), `kpiUnit` 36, `delta` 14 mono 500, `tick` 12 mono 500, `legend` 13 mono 500, `chip` 13 mono 500, `speed` 12 mono 500, `quote` 15/22 sans 400, `quoteMeta` 12 mono 600, `agentName` 15 sans 600, `agentState` 12 mono 500, `callout` 12 mono 600. Hauteurs de ligne du design system. Le plancher de 24 px est retiré partout (garde `no_hardcoded_style_test` recalé : aucun `fontSize:` littéral hors du paquet du design system).
- **F2 Disposition conservée à l'extérieur des composants.** Grille de page, marge et gouttière de 8 px, rail de 96 px, rectangles des cellules (624×302, 936×302), barre de rejeu et panneau du protocole (018) : inchangés. À l'intérieur d'une cellule, la structure suit le design system ; avec des textes plus petits, la place libérée sert à la structure (jauge, tableau, cartes), pas à un agrandissement de la cellule. Si un composant ne tient pas dans sa cellule, la boucle l'ajuste dans la cellule (rien ne change de rectangle sans un `Q-xx`).
- **F3 Jauge du KeyIndicator.** Aucune donnée ajoutée : le domaine est **[⌊min(valeur, seuil, 3.3)⌋, 100] %** (soit 99–100 % pour 99,43 / 99,50 / 99,71, comme dans la source : remplissage 43 %, marque 50 %, repère 71 %). Marque de seuil et repère 3.3 **absents** si la donnée est absente. Couleur de remplissage : `nogo` si le statut est bloquant, `warn` si « À risque », `go` sinon (statuts de l'app, règle « À risque » inchangée).
- **F4 Annotation et zones du graphique.** « ▲ seuil franchi dès Jn » est **dérivée de la série courante** (premier point au-dessus du seuil) ; absente sans franchissement ; la valeur de tête (« 0,75 % ») est celle du dernier point. Zone de franchissement : polygone entre la série et le seuil à partir du franchissement. Zone sous la série : `signal-ghost`. Les séries par plateforme de pdr-0084 U3 sont conservées (la zone sous la série ne s'applique qu'à la série courante de la plateforme principale ; autre plateforme sans zone).
- **F5 Flou de `gc-rise`.** L'apparition fait passer le flou de σ 4 à 0 pendant les 480 ms (translation de 10 px, échelle .985), **seulement pendant la transition** (`ImageFiltered` posé à l'entrée et retiré à la fin, dans le `RepaintBoundary` de la cellule), jamais en continu. Remplace pdr-0084 U2 (« sans flou »). **Repli** si la mesure des 60 i/s de J7 le demande : sigma réduit ou flou retiré, sans autre changement (nouvelle PDR).
- **F6 Capitales.** Les étiquettes `label`, les puces de statut, les en-têtes de tableau et les étiquettes de segments se **rendent en capitales** comme le design system ; les textes de données, `Semantics` et clés restent inchangés. Les tests qui cherchaient la casse d'origine sont recalés (pdr-0084 U14 est remplacé par pdr-0087 D2).
- **F7 Boutons.** Apparence du design system seule : le clic reste un clic (pas de remplissage `gc-hold`, ni « Maintenir pour bloquer », ni reçu nominatif, ni « Recommandation IA » : UX et métier, pdr-0087 D4). Le bouton « Bloquer la release » prend le style danger (lueur `nogo`, fond `nogo-ghost`) ; « Valider la release » désactivé : tirets et `ink-faint`, comme la source.
- **F8 Indicateur d'acte.** Reste **un seul bouton** (`act-indicator`, un clic passe à l'acte suivant, pdr-0063) dont l'apparence est le sélecteur en segments (01 ✓ / 02 ✓ / 03 ; le segment actif en `plasma-ghost`). En rejeu réel (`ReplayActive`) : un segment unique « Acte 4 · Rejeu », non cliquable (comportement actuel). **Rien ne change dans la logique** : `_reachAct` ne fait rien en mode scénario ni en rejeu, donc le « Acte 1/3 » des captures `*-replay` est l'effet attendu du mode scénario (hypothèse à confirmer par test à l'étape TDD).
- **F9 Animations de niveau B** (spec § Animations) : reprises elles aussi, derrière le même `SceneMotionScope` et chacune dans son `RepaintBoundary`, mais **coupables en dernier** si le temps manque (comme pdr-0084 U10). Le **point de tête du graphique** a son anneau (`gc-ring`) une fois le tracé fini, en boucle ; l'orbe garde sa respiration (017).
- **F10 Rail.** Les tuiles gardent l'**ordre fixe des agents** et leur contenu ; la barre indéterminée « au travail » est de niveau B. Le rail garde sa hauteur de 96 px ; l'étiquette « Agents A2A » tient à gauche.
- **F11 Cadre de génération.** Appliqué à la surface dont la génération est en cours (`createSurface` reçu, pas encore complète) avec l'étiquette « <Agent> · génère » ; en fin, un dernier tour puis fondu (`is-done`). L'agent affiché est celui du plan reçu (pas de nom codé en dur).

## Raisons
Parole du porteur (pdr-0087) : design « un peu plus attractif », « l'effet visuel manque trop de finitions », « n'oublie pas les animations ». Chaque point ci-dessus est un détail que la fiche ne dit pas ; la source du design system (preview, CSS) fait foi pour l'UI (pdr-0017, pdr-0083 D1). F3 et F4 respectent « données inchangées » (valeurs dérivées, rien d'inventé).

## Options écartées
- Agrandir les cellules ou changer la grille pour mieux imiter l'écran de 1440 px de la source : changerait des rectangles de 013, 017 et 018.
- Garder « sans flou » (U2) : écarté par pdr-0087 D2.
- Reprendre « Maintenir pour bloquer » et le reçu : UX, hors périmètre.
- Supprimer les animations de niveau B : le porteur a demandé les animations du design system sans restriction.

## Conséquences
- Tests de 013 et 017 qui fixaient 24 px, l'absence de flou (U-05) ou la casse d'origine : recalés avec renvoi à pdr-0087 et à cette PDR.
- Mesure des 60 i/s au profil et lisibilité au fond de la salle : J7, en répétition (NFR-04, pdr-0087 D1).

## Réexaminer si
- Les 60 i/s ne tiennent pas avec le flou (F5 : repli) ou avec les boucles de niveau B (F9 : coupe).
- Le porteur veut un autre domaine de jauge, ou ne veut pas des capitales, ou veut l'appui long du design system.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-03 | Acceptée à l'étape Définir de 019. | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
