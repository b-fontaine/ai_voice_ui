---
id: pdr-0087-design-system-fidelity-no-24px-minimum
title: "PDR-0087 — Fidélité au design system pour l'UI (structure visuelle et animations comprises), sans minimum de 24 px ; fonctionnalité 019"
area: decisions
status: validated
updated: 2026-11-03
sources: [product/sources/design-system-2026-11-02/README.md, product/sources/design-system-2026-11-02/tokens.json, product/sources/design-system-2026-11-02/components/bundle.css, specs/017-design-system-v2/status.md, knowledge:ds-motion, knowledge:ds-a11y-wcag-contrast]
links: [pdr-0083-design-system-v2-ui-only, pdr-0084-017-design-system-ui-details-assistant-decided, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, p-fn-nfr, p-ar-design-system, p-ar-design-system-look, p-sources, p-rm-backlog, p-rm-roadmap, p-rm-open-questions]
tags: [pdr, decision, design-system, ui, 019, nfr-05]
decision_status: acceptée
decided_on: 2026-11-03
decided_by: "Benoît FONTAINE (porteur), conversation Claude Code, 2026-11-03"
scope: mixte
supersedes: [pdr-0083-design-system-v2-ui-only, pdr-0084-017-design-system-ui-details-assistant-decided]
superseded_by: null
---
# PDR-0087 — Fidélité au design system pour l'UI, sans minimum de 24 px ; fonctionnalité 019

> **En bref.** Le porteur retire la règle « aucun texte sous 24 px » et demande une UI fidèle au design system du 2026-11-02, animations comprises. **Remplacement partiel** : pdr-0083 D4 et les points U1, U2, U8 (amendement), U10, U13, U14, U15 (c) et (e) de pdr-0084 sont remplacés ; le reste de ces deux PDR (dont pdr-0083 D1 à D3, qui gardent la portée « UI seulement ») reste en vigueur, d'où leur `decision_status` inchangé. NFR-05 est **suspendue**. La fonctionnalité **019** met cela en œuvre.

## Contexte
017 a appliqué les tokens du design system mais gardé la structure visuelle de 013 ([pdr-0084](pdr-0084-017-design-system-ui-details-assistant-decided.md) U1), et la règle des 24 px ([pdr-0083](pdr-0083-design-system-v2-ui-only.md) D4, [Q-91](../roadmap/open-questions.md)) grossit tout. La capture de 017 s'écarte donc des `preview.html` de la source. L'assistant a proposé une fonctionnalité 019 « après 018 » : reprendre la structure visuelle de chaque composant, UX et données inchangées, et vérifier l'indicateur d'acte en rejeu.

## Décision
- **D1 Tailles.** Les tailles de texte suivent le design system ([tokens.json](../sources/design-system-2026-11-02/tokens.json)). Le minimum de 24 px (pdr-0083 D4, Q-91) est retiré. **NFR-05** (texte ≥ 24 px) est **suspendue**, non supprimée ; le contraste AA reste exigé. La règle pourra être rétablie si la lisibilité pose problème en répétition (point à observer : lisibilité au fond de la salle).
- **D2 Fidélité.** La structure visuelle de chaque composant suit les `preview.html` et `bundle.css` du design system (liste dans le [backlog](../roadmap/backlog.md), 019). Les points suivants de pdr-0084 sont remplacés : **U1** (disposition de 013 conservée : remplacée pour l'intérieur des composants ; la grille de page, le rail de 96 px et les rectangles de cellules restent, sauf nécessité tranchée par 019 sous pdr-0062), **U2** (apparition « sans flou » : `gc-rise` flou → net, +10 px), **U8** (amendement : le `glow-plasma` complet n'est plus écarté), **U10** (`gc-row`, `gc-wipe` et compteur `data-count` entrent dans le périmètre), **U13** (puces et seuils en `body` : la police suit le design system), **U14** (capitales des étiquettes HUD : suivent le design system), **U15 (c)** (remplissage des puces) et **(e)** (`gc-row`, `gc-wipe`, `gc-spin`/`gc-scan` « pas faits »).
- **D3 Animations.** Celles du design system (README § Mouvement, `bundle.css`) sont reprises : `gc-rise`, `gc-row`, `gc-wipe`, `data-count`, `gc-spin` + `gc-scan`, `gc-beacon` (statut Bloquant seul), `gc-wave`, `gc-orbring`, `gc-flash` ; durées 160 ms / 480 ms / 1,4 s, courbe `cubic-bezier(.2,.8,.2,1)` ; tout s'arrête si l'OS demande de réduire les animations.
- **D4 Portée inchangée.** UX et données restent celles de l'app ([pdr-0083](pdr-0083-design-system-v2-ui-only.md) D1) : appui long et reçu nominatif, « Valider » désactivé, règle « À risque », valeurs et deltas, nombre de verbatims, ordre des agents, données d'exemple.
- **D5 Fonctionnalité 019.** « Fidélité au design system » (voir [backlog](../roadmap/backlog.md)), après 018. Elle vérifie aussi l'indicateur d'acte en rejeu (« Acte 1/3 · Créer » dans la capture `act3-replay` de 017 : bogue ou effet attendu).

## Raisons
Parole du porteur : design « un peu plus attractif », « l'effet visuel manque trop de finitions ». Choix de goût et de mise en scène : au porteur.

## Options écartées
Garder 24 px et ne reprendre que la structure : écartée par le porteur.

## Conséquences
- [pdr-0083](pdr-0083-design-system-v2-ui-only.md) et [pdr-0084](pdr-0084-017-design-system-ui-details-assistant-decided.md) : ligne d'Historique, `decision_status` inchangé (remplacement partiel). Le tableau de ces PDR n'est pas réécrit : lire D4 et les U listés ci-dessus comme remplacés.
- NFR-05 suspendue ([p-fn-nfr](../functional/nfr.md)) ; Q-91 « retranchée → pdr-0087 ».
- Les tests de 017/013 qui fixent 24 px et les rectangles (U-0x, D-02, D-06…) sont recalés par 019, avec renvoi ici.

## Réexaminer si
- La lisibilité au fond de la salle pose problème en répétition : rétablir NFR-05 (nouvelle PDR).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-03 | Acceptée sur la parole du porteur, conversation Claude Code. À la proposition de l'assistant (« Je te propose de lui confier une fonctionnalité 019, après 018. Elle reprendrait la structure visuelle de chaque composant du design system, en respectant les 24 px minimum et sans toucher à l'UX ni aux données. Elle vérifierait aussi l'indicateur d'acte en rejeu. Je lance ? »), le porteur répond : « oui, par contre, enlève la règle des 24px minimum. On la remettra si ça pose problème mais je veux un design un peu plus attractif. là, l'effet visuel manque trop de finitions. », puis : « Ah oui, et n'oublie pas les animations. » | Benoît FONTAINE (porteur) |

Pas d'archive brute.
