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

> **En bref.** Le porteur a fixé la portée de 017 ([pdr-0083](pdr-0083-design-system-v2-ui-only.md) : UI seulement, texte ≥ 24 px). La fiche est muette sur la façon d'appliquer l'habillage aux décisions d'UI de 007, 008, 009 et 013 ; la boucle tranche, sous [pdr-0062](pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md), les quinze points U1 à U15 ci-dessous. Le porteur peut contester chaque point.

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
- **U1 Géométrie.** Les jetons `space-1…8` et `radius-sm/md/lg/pill` s'ajoutent comme constantes ; ils règlent le dedans des cellules (rayons 16/10/6, pastilles). Les 8 px de 013 sont l'écart entre zones de la page et la marge d'écran : conservés, comme le rail de 96 px, les cellules et la marge interne actuelle de 16 px (le `space-6` de 24 px n'est pas appliqué aux cellules). Les cellules de la grille étant jointives, le panneau est en retrait de 4 px pour garder 8 px visibles entre deux panneaux ; bordures jointives si D-02 à D-05 l'exigent.
- **U2 Mouvement.** `appear` 480 ms, `value` 160 ms, translation 10 px, courbe `Cubic(.2, .8, .2, 1)` ; `status` 400 ms, plancher 60 ms et division par la vitesse de rejeu inchangés. Pas de flou : il coûterait un `saveLayer` par surface (NFR-04). Cela remplace les valeurs de [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md) D3 (200 ms, 150 ms, 8 px) ; le reste de D3 (un contrôleur par surface, durée nulle sous `disableAnimations`) est inchangé.
- **U3 Séries du graphique.** Identification par plateforme conservée, avec des couleurs du design system hors statuts et hors `plasma` : iOS `ink`, Android `signal`, autre `baseline` ; « 3.3 » en pointillés de la couleur de sa plateforme ; seuil `nogo` en tirets. Précise [pdr-0064](pdr-0064-008-act2-transform-details-assistant-decided.md) D8.
- **U4 Barre d'actions.** Apparence du design system (fond `surface-300`, bordure `ink-muted` ou `nogo`, texte `ink` ou `nogo`, focus `signal` ; la bordure `line-strong` du design system ne vaut que 2,30:1 sur `surface-100` et 2,44:1 sur `void`, sous les 3:1 d'un composant d'interface, donc elle n'est pas retenue pour un bouton) ; interaction inchangée ([pdr-0065](pdr-0065-009-act3-interact-details-assistant-decided.md) D7).
- **U5 Régie, surbrillance, rejeu.** Contour pointillé `signal`, segment d'acte actif sur `plasma-ghost`, curseur de rejeu sur `surface-300` ; apparence seule ([pdr-0063](pdr-0063-007-stage-ui-details-assistant-decided.md)).
- **U6 Statuts.** Fond `*-ghost`, texte `go`/`warn`/`nogo`, toujours le mot ; `go` ajoute ✓ dans un widget séparé, exclu de `Semantics`.
- **U7 Battement.** Parmi les statuts, seul Bloquant bat en continu (`gc-beacon`) ; les boucles existantes (liaison de délégation, orbe, cadre de génération) restent ; **toutes** passent par `SceneMotionScope.loop` et s'arrêtent sous `disableAnimations`, orbe et squelette compris (ils ne le faisaient pas).
- **U8 Orbe.** Couleurs en rôles du thème (corps `plasma`, éclair `ink`, voile `orbVeil`), halo en dégradé radial `plasmaGhost` quand l'IA parle, **plafonné au rayon du cadre de 64 px de la barre du haut** (pas de `MaskFilter.blur` repeint à 60 Hz) ; amendé à la revue de 017 : le `glow-plasma` complet du design system (`0x66A58BFF`, flou 40 px) n'est **pas** repris, il demanderait de vérifier le rognage de la barre du haut ; à juger par le porteur sur l'orbe qui parle, en répétition ; la logique audio, les états et le niveau ne changent pas.
- **U9 Panneaux et fond.** Dégradé `surface-200` → `surface-100`, bordure `line`, coins HUD `line-strong` (deux « L » de 10 px, haut gauche et bas droit, comme le CSS du design system), rayon 16, ombre `panel` (la ligne `inset` devient un filet de 1 px peint par le panneau), en **couche décorative statique sœur** du contenu animé (pas une enveloppe : l'ombre ne doit pas être rognée, pas de double cadre avec `CellFrame`, `NoDataCell` et `DsSkeleton`, qui perdent fond et rayon), au-dessus d'un fond `void` à grille de points de 24 px peinte une fois.
- **U10 Animations facultatives.** `gc-row` et `gc-wipe` seulement s'il reste du temps après les tâches obligatoires ; le compteur `data-count` est exclu (valeurs intermédiaires qui ne sont pas des données).
- **U11 Polices.** Fichiers variables embarqués dans `packages/shared/design_system/assets/fonts/` (empreintes SHA-256 consignées), poids par `FontVariation('wght', n)` et `fontWeight` identiques, chiffres tabulaires pour les données, repli `DejaVu Sans` embarqué, licences OFL enregistrées dans `LicenseRegistry`, aucune dépendance `google_fonts`.
- **U12 Scénario D-06 de 013.** Les durées de U2 rendent le scénario D-06 (apparition à 250 ms, 120 ms en ×2) rouge tel quel : il est recalé aux durées de U2 (≈ 500 ms ; ≈ 250 ms en ×2) par product-curate, avec renvoi ici. Conséquence de U2, pas un changement de comportement.

- **U13 Puces et seuils de la checklist en `body`.** Les puces de statut (checklist et `DsStatusChip`), les seuils et les valeurs des critères de la checklist sont en Space Grotesk (`body`), pas en JetBrains Mono (`data`) : la mono, plus large à 24 px, casse D-02 (« + N autres critères » à la place des critères entiers). Le scénario U-02 est précisé en conséquence (commentaire de `design-system-017.feature`).
- **U14 Capitales des étiquettes HUD reportées.** `label` est mono, interlettré, réservé aux 5 étiquettes HUD ; leurs capitales visuelles sont reportées (une vingtaine de tests cherchent la casse d'origine de « n / 6 utilisés » et « FLUX A2UI · live »). Pdr-0083 D4 (hiérarchie par graisse, casse, famille, couleur) reste tenue par la graisse, la famille, la couleur et l'interlettrage. `sceneCaps` est retiré du code tant que les capitales ne sont pas décidées.
- **U15 Décisions de réalisation.** (a) La période de 2 s de l'orbe est divisée par la vitesse de rejeu, comme la liaison de délégation (la boucle passe par `SceneMotionScope`) ; (b) `DsSkeleton` ne dessine que son bloc grisé qui pulse, à 16 px du bord, au rayon `SceneRadius.md` (le fond est le panneau) ; (c) remplissage horizontal des puces de statut 16 → 12 px (avec 16 px, D-02 casse) ; (d) la barre de rejeu perd 4 px de remplissage horizontal et l'espace entre « REJEU » et Lecture, pour que Lecture reste atteignable panneau du protocole déplié (R-01) ; (e) T21 (`gc-row`, `gc-wipe`) et le cadre de génération `gc-spin`/`gc-scan` ne sont pas faits ; (f) deux coins HUD de panneau, comme le CSS (voir Historique).

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
| 2026-11-02 | Revue du code de 017 : U13, U14 et U15 ajoutées (décisions de réalisation jusque-là consignées seulement dans `status.md` et `progress.md`), U8 amendée (halo `plasmaGhost` plafonné au cadre, pas de `glow-plasma` complet). | Assistant (délégation du porteur, pdr-0062) |
| 2026-11-02 | Précision U4 à l'implémentation de T11 : bordure neutre des boutons en `ink-muted` au lieu de `line-strong` (contraste mesuré 2,30 à 2,44:1 < 3:1, WCAG 1.4.11). | Assistant (délégation du porteur, pdr-0062) |
| 2026-11-02 | Précision U9 à l'implémentation de T14 : coins HUD au nombre de deux (haut gauche, bas droit), comme `.gc-panel::before` du design system ; la source l'emporte sur les « quatre coins » du plan. | Assistant (délégation du porteur, pdr-0062) |
| 2026-11-02 | Amendée par la revue du plan de 017 (verdict À AMENDER, P1 à P8) : U1 (cellules jointives, retrait de 4 px, marge de 16 px conservée), U7 (boucles sous `SceneMotionScope.loop`, orbe et squelette compris), U8 (rôles d'orbe, halo radial), U9 (couche sœur, filet de 1 px), U11 (empreintes, repli embarqué), U12 (D-06 recalé). | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
