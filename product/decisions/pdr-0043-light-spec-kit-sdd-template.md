---
id: pdr-0043-light-spec-kit-sdd-template
title: "PDR-0043 — Gabarit SDD : Spec Kit léger, un dossier specs/NNN-<slug>/ par fonctionnalité"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p1, tools/loop/README.md]
links: [pdr-0017-source-hierarchy-sheet-over-mockups, p-rm-roadmap, p-rm-backlog, p-rm-open-questions]
tags: [pdr, decision, sdd, specs, boucle]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0043 — Gabarit SDD : Spec Kit léger

> **En bref.** Chaque fonctionnalité a un dossier `specs/NNN-<slug>/` (spec, plan, tasks, status) qui **renvoie** à `product/` sans le recopier. `product/` reste la seule référence produit. Tranche Q-09.

Part de l'assistant : options et explication des impacts ; consignation du choix du porteur.

## Contexte
Q-09 (E5) : fiche § 1, structure SDD générique, gabarit du porteur non fixé. Le porteur avait demandé une explication des impacts avant de répondre.

## Hypothèses
- ✅ Choix du porteur : option 2 (conversation du 2026-10-29).

## Options
1. Gabarit générique seul
2. **Spec Kit léger** (retenue) : `specs/NNN-<slug>/` avec spec, plan, tasks, status
3. Autres gabarits

## Décision
- Dossier `specs/NNN-<slug>/` par fonctionnalité (spec, plan, tasks, status), qui cite les ids de `product/` (FR, NFR, RG, PDR) sans recopier leur contenu.
- `product/` reste la seule référence produit ; en cas d'écart, `product/` l'emporte.
- L'avancement global est suivi dans `specs/progress.md`.

## Raisons
- Parole du porteur (conversation, 2026-10-29) : « Pour la gabarit SDD, je penche pour l'option 2. »
- Pas de duplication de la documentation produit ; gabarit adapté à la boucle autonome ([tools/loop/README.md](../../tools/loop/README.md)).

## Options écartées
- Options 1 et 3 : non retenues par le porteur.

## Conséquences
- [p-rm-roadmap](../roadmap/roadmap.md) : développement par la boucle, fonctionnalités dans `specs/`.
- Q-09 tranchée.

## Réexaminer si
- Les dossiers `specs/` divergent de `product/` ou le coût de maintenance dépasse le gain.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « Pour la gabarit SDD, je penche pour l'option 2. » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
