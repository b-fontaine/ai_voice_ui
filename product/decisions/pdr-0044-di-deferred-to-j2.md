---
id: pdr-0044-di-deferred-to-j2
title: "PDR-0044 — get_it + injectable introduits en J2, pas dans la fonctionnalité 000"
area: decisions
status: validated
updated: 2026-10-29
sources: [specs/000-loop-harness/status.md]
links: [p-rm-open-questions, p-ar-frontend, p-rm-roadmap, pdr-0011-adopt-knowledge-adrs, adr-0001-initial-constraints]
tags: [pdr, decision, di, get-it, injectable]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0044 — DI get_it + injectable reportée à J2

> **En bref.** Tranche Q-66. La fonctionnalité 000 (outillage de boucle) reste sans get_it ni injectable : elle n'a aucun service à environnement, tout est injecté par constructeur et la page sert de racine de composition. get_it + injectable arrivent en **J2**, avec le premier vrai service (canal vers le backend), conformément à AGENTS.md § 2 et adr-0001.

Part de l'assistant : recommandation et mise en forme.

## Contexte
Revue d'architecte de la fonctionnalité 000 (2026-10-29, `specs/000-loop-harness/status.md`) : AGENTS.md § 2 et [adr-0001-initial-constraints] (hérité via [pdr-0011](pdr-0011-adopt-knowledge-adrs.md)) imposent get_it + injectable ; 000 n'a encore rien à injecter par environnement. Question Q-66 ([p-rm-open-questions](../roadmap/open-questions.md)).

## Options
1. **Reporter à J2, premier service réel** (retenue)
2. Introduire get_it + injectable dès 000

## Décision
- 000 est livrée sans get_it/injectable ; aucune règle n'est assouplie pour la suite : pas de `getIt` dans un widget ni un Bloc, injection par constructeur.
- La première fonctionnalité de J2 qui introduit un service (canal app ↔ backend) crée `app/di` avec get_it + injectable et ses environnements ; la revue d'architecte de J2 le vérifie.

## Raisons
Recommandation de l'assistant acceptée par le porteur. Parole du porteur, 2026-10-29 : « ok pour Q-66, reporte jusqu'en J2 ».

## Options écartées
- Option 2 : de la DI sans service à injecter, coût sans bénéfice dans un outillage de test.

## Conséquences
- [p-rm-roadmap](../roadmap/roadmap.md) : J2 inclut la mise en place de `app/di` (get_it + injectable).
- [p-ar-frontend](../architecture/frontend.md) : inchangé sur le fond.

## Réexaminer si
- J2 se termine sans service injecté (alors : la DI arrive avec le premier service, au plus tard J3).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée ; Q-66 tranchée (« ok pour Q-66, reporte jusqu'en J2 ») | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
