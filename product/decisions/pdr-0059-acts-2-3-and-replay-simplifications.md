---
id: pdr-0059-acts-2-3-and-replay-simplifications
title: "PDR-0059 — Actes 2-3 et rejeu : pas de suppression, pas de filtres écran, pas de confirmation, pas de pas-à-pas"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p7]
links: [p-rm-open-questions, p-fn-screen, p-fn-requirements, p-fn-business-rules, p-ar-replay, p-ar-security, p-ar-agents-protocols, pdr-0024-act2-android-only, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0005-frozen-fictional-dataset, pdr-0017-source-hierarchy-sheet-over-mockups, genui-a2ui-security]
tags: [pdr, decision, acte-2, acte-3, rejeu]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0059 — Actes 2-3 et rejeu : pas de suppression, pas de filtres écran, pas de confirmation, pas de pas-à-pas

> **En bref.** Tranche Q-21, Q-32, Q-49 et Q-52 : l'acte 2 ne retire aucune surface ; pas de filtres Android / iOS / Comparer à l'écran (tout par la voix) ; pas de confirmation hors GenUI avant « Bloquer la release » ; pas de pas-à-pas ←/→ au rejeu.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Écarts E8 (Q-21), E14 (Q-32) fiche/maquette 3, et deux questions de comportement (Q-49, Q-52) : voir [p-rm-open-questions](../roadmap/open-questions.md).

## Hypothèses
- ✅ Fiche § 4 : « les surfaces existantes restent à leur place » ; l'action « Bloquer la release » est fictive ([pdr-0005](pdr-0005-frozen-fictional-dataset.md)).

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** :
- **Q-21** : l'acte 2 ne retire aucune surface (mutations seules, RG-06).
- **Q-32** : pas de filtres Android / iOS / Comparer à l'écran ; tout passe par la voix.
- **Q-49** : pas de confirmation hors GenUI avant « Bloquer la release » (action fictive, l'IA confirme à la voix).
- **Q-52** : pas de pas-à-pas ←/→ dans le rejeu ; lecture, pause et vitesse suffisent.

## Raisons
- Fiche suivie (pdr-0017) ; simplicité de la démo ; mise en scène vocale.
- Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ».

## Options écartées
- Suppression en acte 2, filtres chrome ou catalogue, confirmation modale, pas-à-pas par message ou par surface : écartés.

## Conséquences
- [p-fn-screen](../functional/screen.md) : raccourcis ←/→ sans pas-à-pas ; [p-ar-agents-protocols](../architecture/agents-protocols.md) : acte 2 sans `deleteSurface` ; [p-ar-security](../architecture/security.md) : pas de confirmation ; [p-ar-replay](../architecture/replay.md).
- Coupe C8 de la roadmap : Q-32 tranchée.

## Réexaminer si
- la répétition montre qu'un filtre ou une confirmation manque pour la compréhension.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ». Tranche Q-21, Q-32, Q-49, Q-52. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
