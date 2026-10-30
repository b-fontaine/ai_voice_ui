---
id: pdr-0063-007-stage-ui-details-assistant-decided
title: "PDR-0063 — Détails d'interface de l'écran de scène en J3-B (indicateur d'acte, pointillé, Rejeu, remise à vide, rail)"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/007-j3-act1-frontend/spec.md, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p9]
links: [p-rm-open-questions, p-fn-screen, p-fn-catalog, p-ar-frontend, p-ar-app-channel-contract, pdr-0033-optional-shortcuts-mouse-first, pdr-0054-stage-screen-orb-acts-checklist, pdr-0058-backend-canvas-registry-survives-voice-sessions, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details]
tags: [pdr, decision, ecran, remise-a-vide, rail, panneau-protocole]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0063 — Détails d'interface de l'écran de scène en J3-B

> **En bref.** La fiche est muette sur six détails d'interface de la fonctionnalité 007 ; la boucle les tranche sous la règle permanente pdr-0062 et les signale au porteur, qui peut les contester. Aucun ne touche le périmètre, la mise en scène des actes, le budget ni les fournisseurs.

Part de l'assistant : décision prise sur délégation (pdr-0062), contestable par le porteur.

## Contexte
007 (J3-B) construit l'écran à six zones ([p-fn-screen](../functional/screen.md)). Restent à fixer des détails que la fiche ne précise pas, et la manière dont la remise à vide (FR-11) atteint le registre du backend voulu par [pdr-0058](pdr-0058-backend-canvas-registry-survives-voice-sessions.md).

## Hypothèses
- ✅ La fiche est muette sur ces détails (§ 6) ; ni périmètre, ni mise en scène, ni budget, ni fournisseur.

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
- **D1 — Indicateur d'acte** : « Acte n/3 · Créer | Transformer | Interagir » ([pdr-0054](pdr-0054-stage-screen-orb-acts-checklist.md)) ; vaut 1 par défaut, se règle d'un clic (régie, souris d'abord, [pdr-0033](pdr-0033-optional-shortcuts-mouse-first.md)), revient à 1 à la remise à vide. L'avance automatique des actes n'est pas décidée ici.
- **D2 — Relation message ↔ composant (FR-05)** : message en cours en évidence dans le panneau ; sa surface reçoit un contour pointillé.
- **D3 — Zone Rejeu** : emplacement libellé « REJEU », commandes inactives jusqu'à J6.
- **D4 — Remise à vide (FR-11, RG-23)** : bouton « Remettre à vide » ; vide canevas, panneau, étagère, rail, acte 1 ; demande au backend (`POST /canvas/reset`, au mieux) de retirer les surfaces actives et de vider le registre de la session (pdr-0058). Pas de raccourci `R` en J3. La survie du canevas d'une session voix à l'autre reste à J4.
- **D5 — Rail** : l'orchestrateur et les trois rôles toujours affichés après le premier `plan` ; absent du plan = « en veille » ; plan vide = « aucun agent retenu » (RG-08, RG-29).
- **D6 — Rendu** : composants du catalogue `genesis` au seul thème de scène (RG-09), statuts par codes fermés, courbe en `CustomPainter` sans nouvelle dépendance.

## Raisons
- Détails d'interface que la fiche ne tranche pas ; rester minimal, souris d'abord, aucune mise en scène nouvelle.
- La route de remise à vide applique pdr-0058 (source de vérité = registre backend) sans changer sa portée.

## Options écartées
- Avancer l'acte automatiquement à partir des surfaces : relève de la mise en scène (porteur).
- Tracer une ligne entre le panneau et la surface : coût élevé pour une démo, le contour pointillé porte la même information.
- Remise à vide purement locale : une nouvelle demande ne recréerait aucune surface (le registre backend les croirait actives).

## Conséquences
- [p-fn-screen](../functional/screen.md) et [p-ar-frontend](../architecture/frontend.md) : à compléter à la clôture de 007 ; [p-ar-app-channel-contract](../architecture/app-channel-contract.md) : route `POST /canvas/reset`.
- `specs/progress.md` : signalé au porteur.

## Réexaminer si
- le porteur conteste l'un des détails, ou si la répétition montre que l'indicateur d'acte ou le contour pointillé ne se lit pas.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée sous la règle permanente pdr-0062 (fiche muette, détail d'interface). | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
