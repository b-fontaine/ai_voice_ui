---
id: pdr-0084-017-design-system-ui-details-assistant-decided
title: "PDR-0084 — 017 : détails d'application du design system tranchés par la boucle (géométrie conservée, mouvement, séries, statuts, panneaux, polices variables)"
area: decisions
status: validated
updated: 2026-11-02
sources: [specs/017-design-system-v2/spec.md, specs/017-design-system-v2/plan.md, specs/017-design-system-v2/status.md, product/sources/design-system-2026-11-02/README.md, product/sources/design-system-2026-11-02/tokens.json, product/sources/design-system-2026-11-02/components/bundle.css, knowledge:ds-typography, knowledge:ds-motion, knowledge:ds-a11y-wcag-contrast]
links: [pdr-0083-design-system-v2-ui-only, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0072-design-ergonomics-013, pdr-0064-008-act2-transform-details-assistant-decided, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0063-007-stage-ui-details-assistant-decided, pdr-0079-013-tokens-exception-to-adr-0005, pdr-0007-closed-catalog-stage-theme, pdr-0017-source-hierarchy-sheet-over-mockups, p-ar-design-system, p-fn-nfr, p-sources, p-rm-backlog, p-rm-open-questions, adr-0005-ds-tokens-style-dictionary]
tags: [pdr, decision, design-system, ui, 017]
decision_status: acceptée
decided_on: 2026-11-02
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0084 — 017 : détails d'application du design system tranchés par la boucle

> **En bref.** Le porteur a fixé la portée de 017 ([pdr-0083](pdr-0083-design-system-v2-ui-only.md) : UI seulement, texte ≥ 24 px). La fiche est muette sur la façon d'appliquer l'habillage aux décisions d'UI de 007, 008, 009 et 013 ; la boucle tranche, sous [pdr-0062](pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md), les onze points U1 à U11 ci-dessous. Le porteur peut contester chaque point.

Part de l'assistant : décisions de détail d'interface sur délégation permanente ; aucun choix de périmètre, de mise en scène, de budget ni de fournisseur. Le périmètre est celui de pdr-0083.

## Contexte
[pdr-0083](pdr-0083-design-system-v2-ui-only.md) (Conséquences) liste les décisions d'UI qui rencontrent le design system du 2026-11-02 et renvoie leur arbitrage à l'étape Définir de 017. Le design system fournit des tokens ([source](../sources/design-system-2026-11-02/tokens.json)), un `bundle.css` et des `preview.html` ; il ne dit rien de la disposition de l'app (rail de 96 px, cellules de 624×302 et 936×302, marge de 8 px, [pdr-0072](pdr-0072-design-ergonomics-013.md), [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md)) ni des séries tracées par plateforme ([pdr-0064](pdr-0064-008-act2-transform-details-assistant-decided.md) D8).

## Hypothèses
- ✅ Portée et taille minimale confirmées par le porteur (pdr-0083 D1 et D4).
- ✅ Polices : Space Grotesk et JetBrains Mono sont publiées en fichiers **variables** (axe `wght`) dans le dépôt Google Fonts (`ofl/spacegrotesk`, `ofl/jetbrainsmono`), licence OFL 1.1, relevé du 2026-11-02.
- ⚠️ Hypothèse non confirmée : une police variable rend les graisses sous Flutter Linux. Vérifiée par le premier test de 017 ; repli : instances statiques générées. Aucune question au porteur.

## Options
1. **Garder la disposition de 013, habiller dedans (retenue).**
2. Adopter aussi les espacements du design system (gouttière 12 px, marge 32 px) : déplace les rectangles prouvés par S-02 et D-01 et réduit la place pour des textes ≥ 24 px.

## Décision
- **U1 Géométrie.** Les jetons `space-1…8` et `radius-sm/md/lg/pill` s'ajoutent comme constantes ; ils règlent le dedans des cellules (padding 24 px des panneaux, rayons 16/10/6, pastilles). La gouttière et la marge d'écran de 8 px, le rail de 96 px et les cellules de 013 sont conservés.
- **U2 Mouvement.** `appear` 480 ms, `value` 160 ms, translation 10 px, courbe `Cubic(.2, .8, .2, 1)` ; `status` 400 ms, plancher 60 ms et division par la vitesse de rejeu inchangés. Pas de flou : il coûterait un `saveLayer` par surface (NFR-04). Cela remplace les valeurs de [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md) D3 (200 ms, 150 ms, 8 px) ; le reste de D3 (un contrôleur par surface, durée nulle sous `disableAnimations`) est inchangé.
- **U3 Séries du graphique.** Identification par plateforme conservée, avec des couleurs du design system hors statuts et hors `plasma` : iOS `ink`, Android `signal`, autre `baseline` ; « 3.3 » en pointillés de la couleur de sa plateforme ; seuil `nogo` en tirets. Précise [pdr-0064](pdr-0064-008-act2-transform-details-assistant-decided.md) D8.
- **U4 Barre d'actions.** Apparence du design system (fond `surface-300`, bordure `line-strong` ou `nogo`, texte `ink` ou `nogo`, focus `signal`) ; interaction inchangée ([pdr-0065](pdr-0065-009-act3-interact-details-assistant-decided.md) D7).
- **U5 Régie, surbrillance, rejeu.** Contour pointillé `signal`, segment d'acte actif sur `plasma-ghost`, curseur de rejeu sur `surface-300` ; apparence seule ([pdr-0063](pdr-0063-007-stage-ui-details-assistant-decided.md)).
- **U6 Statuts.** Fond `*-ghost`, texte `go`/`warn`/`nogo`, toujours le mot ; `go` ajoute ✓ dans un widget séparé, exclu de `Semantics`.
- **U7 Battement.** Une seule animation en boucle propre au design system : le statut Bloquant (`gc-beacon`) ; les boucles existantes (liaison de délégation, orbe, cadre de génération) restent ; tout s'arrête sous `disableAnimations`.
- **U8 Orbe.** Couleurs `plasma` / `plasma-ghost`, halo `glow-plasma` quand l'IA parle ; logique, états et niveau audio inchangés.
- **U9 Panneaux et fond.** Dégradé `surface-200` → `surface-100`, bordure `line`, coins HUD `line-strong`, rayon 16, ombre `panel`, au-dessus d'un fond `void` à grille de points de 24 px peinte une fois.
- **U10 Animations facultatives.** `gc-row` et `gc-wipe` seulement s'il reste du temps après les tâches obligatoires ; le compteur `data-count` est exclu (valeurs intermédiaires qui ne sont pas des données).
- **U11 Polices.** Fichiers variables embarqués dans `packages/shared/design_system/assets/fonts/`, poids par `FontVariation('wght', n)`, chiffres tabulaires pour les données, repli `Noto Sans` puis `DejaVu Sans`, licences OFL enregistrées dans `LicenseRegistry`, aucune dépendance `google_fonts`.

## Raisons
- La disposition de 013 est prouvée par des tests de rectangles (S-02, D-01 à D-07) et laisse la place à un texte ≥ 24 px ; l'habillage n'a pas à la défaire (pdr-0083 D1).
- Le flou de `gc-rise` contredit le périmètre de reconstruction et de peinture de 013 (NFR-04) pour un gain visuel faible.
- « Courante / précédente » du design system suppose une plateforme ; l'app en trace deux, dont la lisibilité prime (pdr-0064 D8). `plasma` est « jamais une donnée » ([source](../sources/design-system-2026-11-02/README.md)).
- Principe du design system : la couleur ne porte jamais seule un statut ni un rouge qui pulse partout (« si tout clignote, rien ne compte »).
- Les polices sont embarquées pour un build reproductible sur machine vierge, sans réseau (NFR-10, [ds-typography]).

## Options écartées
- Gouttière 12 px et marge 32 px : voir Options, point 2.
- Couleurs de séries « courante / précédente » du design system : une seule plateforme à la fois.
- Flou « flou → net » et compteur `data-count` : voir U2 et U10.
- `google_fonts` avec récupération au démarrage : réseau à l'exécution, build non reproductible.

## Conséquences
- [p-ar-design-system](../architecture/design-system.md) : tokens, thème, mouvement et panneaux mis à jour à la clôture de 017 ; [p-fn-nfr](../functional/nfr.md) : NFR-05 inchangée ; [p-rm-backlog](../roadmap/backlog.md) : 017.
- [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md) D3 (durées et translation) et [pdr-0064](pdr-0064-008-act2-transform-details-assistant-decided.md) D8 (couleurs de séries) sont précisées par U2 et U3 : une ligne d'Historique y renvoie ici, sans les marquer remplacées (leurs autres points restent valables).
- Les tokens suivent le mécanisme de [pdr-0079](pdr-0079-013-tokens-exception-to-adr-0005.md) (constantes `SceneTokens`, contrôle par hash et parité).

## Réexaminer si
- Le rendu des polices variables est faux sous Linux (graisses identiques) : instances statiques.
- Le porteur juge en répétition qu'une couleur de série, la durée d'apparition de 480 ms ou la grille de points nuit à la lecture ou à la fluidité (NFR-04 mesurée en `--profile`).
- Le porteur veut aussi reprendre la gouttière de 12 px ou la marge de 32 px.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-02 | Acceptée à l'étape Définir de 017, sous pdr-0062 (délégation du porteur) ; signalée dans `specs/progress.md` | Assistant (boucle) |

Pas d'archive brute.
