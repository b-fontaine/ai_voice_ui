---
id: pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details
title: "PDR-0062 — Règle permanente : la fiche l'emporte ; l'assistant tranche les détails d'interface muets"
area: decisions
status: validated
updated: 2026-10-30
sources: [AGENTS.md#4, product/_conventions.md]
links: [p-rm-open-questions, p-conventions, pdr-0017-source-hierarchy-sheet-over-mockups]
tags: [pdr, decision, gouvernance, regle-permanente]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0062 — Règle permanente : la fiche l'emporte ; l'assistant tranche les détails d'interface muets

> **En bref.** Règle permanente : écart fiche/maquette, la fiche s'applique ; fiche muette sur un détail d'interface, l'assistant ou la boucle tranche et le signale ; les vrais choix de produit restent au porteur.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Les questions d'écran E9 à E17 ont mobilisé le porteur pour des détails. [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md) fixait déjà la hiérarchie des sources.

## Hypothèses
- ✅ Délégation explicite du porteur le 2026-10-30.

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** : (1) pour tout écart entre la fiche et la maquette, la fiche s'applique (rappel de pdr-0017). (2) Quand la fiche est muette et qu'il s'agit d'un **détail d'interface**, l'assistant ou la boucle tranche lui-même (PDR `acceptée`, `decided_by` « Assistant (délégation du porteur, pdr-0062) ») et le signale dans son compte rendu et dans `specs/progress.md`. (3) Les vrais choix de produit (périmètre, mise en scène des actes, budget, fournisseurs) restent au porteur.

## Raisons
- Gagne du temps avant la démo sans perdre le contrôle du porteur, qui peut contester.
- Parole du porteur : Question « Adopter la règle permanente : écart fiche/maquette → la fiche s'applique ; fiche muette et détail d'interface → la boucle tranche et te le signale ? » → option « Oui (Recommandé) ».

## Options écartées
- Tout faire valider par le porteur : écarté.

## Conséquences
- Une ligne dans `.claude/skills/product-decide/SKILL.md` (§ 0 bis), `.claude/skills/dev-loop/SKILL.md` (§ 2, étape Définir) et AGENTS.md § 4.
- [_conventions.md](../_conventions.md) § 5 : renvoi.

## Réexaminer si
- le porteur conteste une décision prise sous cette règle.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Adopter la règle permanente : écart fiche/maquette → la fiche s'applique ; fiche muette et détail d'interface → la boucle tranche et te le signale ? » → option « Oui (Recommandé) ». Tranche (règle générale). | Benoît FONTAINE (porteur) |

Pas d'archive brute.
