---
id: pdr-0057-getit-composition-root-exception
title: "PDR-0057 — Règle DI : exception de la page racine de composition"
area: decisions
status: validated
updated: 2026-10-30
sources: [AGENTS.md#2, specs/005-j2-flutter-voice-app/status.md]
links: [p-rm-open-questions, p-ar-frontend, di-no-service-locator, adr-0001-initial-constraints]
tags: [pdr, decision, di, regle-projet]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0057 — Règle DI : exception de la page racine de composition

> **En bref.** Tranche Q-72. AGENTS.md § 2 précisé : `getIt` est interdit dans un widget ou un Bloc, sauf la page racine de composition.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Q-72 : la page `genesis_canvas` résout ses dépendances depuis un `GetIt` reçu par constructeur ([p-ar-frontend](../architecture/frontend.md), [di-no-service-locator]) ; AGENTS.md ne prévoyait pas l'exception.

## Hypothèses
- ✅ Aucun autre widget ni Bloc n'appelle `getIt`.

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** : AGENTS.md § 2 (DI) devient « interdit dans un widget ou un Bloc, sauf la page racine de composition ». Modification faite dans AGENTS.md le 2026-10-30.

## Raisons
- Décrit l'état du code et la doc d'architecture sans refactorisation.
- Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ».

## Options écartées
- (b) déplacer la résolution dans `app/` : possible, non retenue.

## Conséquences
- [AGENTS.md](../../AGENTS.md) § 2 modifié ; [p-ar-frontend](../architecture/frontend.md) : « Q-72 ouverte » retiré.

## Réexaminer si
- une seconde page ou un widget a besoin de `getIt`.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ». Tranche Q-72. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
