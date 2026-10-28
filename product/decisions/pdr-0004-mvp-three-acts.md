---
id: pdr-0004-mvp-three-acts
title: "PDR-0004 — MVP : 3 actes (créer, transformer, interagir), rejeu optionnel, hors-périmètre explicite"
area: decisions
status: validated
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p5]
links: [p-fn-personas-journey, p-fn-scope, p-fn-requirements, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in, p-ar-agents-protocols, p-rm-roadmap, p-rm-backlog, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0003-use-case-release-copilot, pdr-0006-replay-fallback-must]
tags: [pdr, decision, scope, mvp, acts]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0004 — MVP en 3 actes

> **En bref.** Le MVP couvre exactement 3 actes joués en direct (créer, transformer, interagir), plus un 4e acte optionnel de rejeu au ralenti. Tout le reste est hors périmètre. Un acte supplémentaire (agent d'un autre éditeur) reste une question ouverte.

Part de l'assistant : mise en forme de la fiche. Aucune recommandation.

## Contexte
- Fiche § 2 (p. 2), « Parcours de la démo en 3 actes » ; fiche § 3 (p. 2-3) : « Le MVP couvre les 3 actes avec des données fictives crédibles et déterministes ; tout le reste est hors périmètre. »

## Hypothèses
- ✅ Les actes sont décrits avec leurs phrases clés et vérifiés par 9 scénarios BDD (fiche § 4).
- ⚠️ Hypothèse non confirmée : la durée de 8 à 10 minutes suffit pour 3 actes + rejeu (fiche § 1) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-06).
- ⚠️ Question ouverte E6 : ajouter un acte avec un agent d'un autre éditeur (fiche § 3) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-10).

## Options
1. **3 actes + rejeu optionnel** (retenue).
2. 3 actes + un acte « agent d'un autre éditeur » : **non tranchée**, laissée ouverte par la fiche § 3.

## Décision
| Acte | Phrase ou geste | Résultat attendu | Exigences |
|---|---|---|---|
| 1. Créer | « Prépare la release 3.4 » | Agents allumés, 4 surfaces construites progressivement, panneau JSON déplié une fois | FR-01…FR-06, NFR-02, NFR-03 |
| 2. Transformer | « Concentre-toi sur Android et compare avec la 3.3 » | Les surfaces mutent sur place | FR-07 |
| 3. Interagir | Clic sur « Bloquer la release » | L'agent confirme à la voix, la checklist passe à « Bloquée » | FR-08 |
| 4. Rejouer (optionnel, Q-19) | Curseur de rejeu | L'acte 1 repasse au ralenti, synchronisé avec le JSON | FR-09 |

Source : fiche § 2 et § 4. L'interruption (FR-13…FR-20) est transverse aux actes.

**Hors périmètre** (fiche § 3) : vraies sources de données, authentification, multi-utilisateur, persistance au-delà de la session, mobile et web, autre langue que le français, widgets hors catalogue.

## Raisons
- Fiche § 2 : chaque acte démontre une propriété distincte de GenUI (génération, mutation sur place, événement utilisateur renvoyé à l'agent).
- Un périmètre étroit limite le risque scénique ([pdr-0001-conference-demo-deliverable](pdr-0001-conference-demo-deliverable.md)).

## Options écartées
- Les éléments listés « Hors périmètre » (fiche § 3), voir aussi [pdr-0002-desktop-platform](pdr-0002-desktop-platform.md), [pdr-0005-frozen-fictional-dataset](pdr-0005-frozen-fictional-dataset.md), [pdr-0007-closed-catalog-stage-theme](pdr-0007-closed-catalog-stage-theme.md), [pdr-0009-french-only](pdr-0009-french-only.md).
- L'acte « agent d'un autre éditeur » n'est **pas écarté** : il reste ouvert (E6, Q-10).

## Conséquences
- **Fonctionnel** : le rejeu est optionnel *en tant qu'acte*, mais l'enregistrement et le rejeu sont **Must** comme mode secours (FR-09, FR-10) → [pdr-0006-replay-fallback-must](pdr-0006-replay-fallback-must.md).
- **Tests** : les 9 scénarios de la fiche deviennent [p-fn-feature-voice-screen-generation](../functional/features/voice-screen-generation.feature) et [p-fn-feature-barge-in](../functional/features/barge-in.feature).
- **Architecture** : séquences des 3 actes dans [p-ar-agents-protocols](../architecture/agents-protocols.md). L'acte 1 dépend du nombre d'agents (E1, 3 ou 4).
- **Roadmap** : un epic par acte, puis le rejeu et l'interruption → [p-rm-backlog](../roadmap/backlog.md).

## Réexaminer si
- Le porteur tranche E6 (Q-10) en faveur d'un acte supplémentaire.
- Les répétitions dépassent la durée allouée à la démo.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 2, § 3) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR | Assistant (mise en forme) |

Pas d'archive brute.
