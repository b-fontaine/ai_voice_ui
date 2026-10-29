---
id: pdr-0048-session-log-only-no-otel-signoz
title: "PDR-0048 — Observabilité en scène : journal de session seul, sans OTel ni SigNoz"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/architecture/quality.md, product/roadmap/roadmap.md, knowledge:ma-otel-genai-spans]
links: [p-rm-open-questions, p-ar-quality, p-ar-backend, p-rm-roadmap, p-rm-backend-production-plan, pdr-0029-local-docker-compose-hosting, pdr-0038-latency-measured-on-app-clock, pdr-0042-calendar-and-cut-order-validated, pdr-0030-llm-budget-20-eur, ma-otel-genai-spans, ma-backend-stack-recommendation, adr-0003-backend-go]
tags: [pdr, decision, observabilite, journal, otel, coupe]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0048 — Journal de session seul, sans OTel ni SigNoz

> **En bref.** Tranche Q-55. En scène et en développement, l'observabilité se limite au **journal de session** horodaté (horloge de l'app, [pdr-0038](pdr-0038-latency-measured-on-app-clock.md)). Ni OpenTelemetry ni SigNoz pour la démo. C'est la coupe **C2** de l'ordre de coupe, déjà pré-autorisée par [pdr-0042](pdr-0042-calendar-and-cut-order-validated.md), appliquée ici d'emblée.

Part de l'assistant : recommandation acceptée par le porteur.

## Contexte
- Q-55 ([p-rm-open-questions](../roadmap/open-questions.md)) : [p-ar-quality](../architecture/quality.md) prévoyait des spans OTel `gen_ai.*` côté backend ([ma-otel-genai-spans]) et jugeait le journal de session suffisant pour mesurer en scène ; le socle générique suppose SigNoz ([ma-backend-stack-recommendation]).
- Profil de démo : tout en local, `docker-compose` sans Keycloak, Kong, Postgres ni Temporal ([pdr-0029](pdr-0029-local-docker-compose-hosting.md)). Le journal en fichiers et l'horloge de l'app suffisent à mesurer les NFR ([pdr-0038](pdr-0038-latency-measured-on-app-clock.md)) et à suivre le budget de 20 € ([pdr-0030](pdr-0030-llm-budget-20-eur.md)).
- C2 : « OTel + SigNoz : journal seul », gain estimé 0,5 j ([p-rm-roadmap](../roadmap/roadmap.md)).

## Hypothèses
- ✅ Le journal de session horodaté suffit à calculer les p90 de NFR-01 à NFR-03 et le suivi du budget (quality.md, pdr-0038).

## Options
1. **Journal de session seul** (retenue)
2. OTel + SigNoz

## Décision
- Le backend et l'app écrivent un **journal de session** (fichiers) ; les mesures de latence et le bilan de budget en sont tirés.
- **Pas de stack OTel** (collecteur, exporteur, SigNoz) dans la démo ; le port `out.Observability` du backend n'a pas d'adaptateur OTel au MVP.

## Raisons
- Gain d'environ 0,5 j dans un calendrier sans marge avant le gel ([pdr-0042](pdr-0042-calendar-and-cut-order-validated.md)).
- Une stack d'observabilité n'est pas visible du public et alourdit le `docker-compose`.

## Options écartées
- OTel + SigNoz : utile en production ([p-rm-backend-production-plan](../roadmap/backend-production-plan.md), étape 12) mais hors besoin d'une démo locale.

## Conséquences
- [p-ar-quality](../architecture/quality.md) : section Observabilité réduite au journal de session et à `BlocObserver`.
- [p-ar-backend](../architecture/backend.md) : pas d'adaptateur OTel au MVP.
- [p-rm-roadmap](../roadmap/roadmap.md) : C2 acquise d'emblée ; Q-55 levée pour J2. [p-rm-open-questions](../roadmap/open-questions.md) : Q-55 tranchée → pdr-0048.

## Réexaminer si
- Le journal ne suffit pas à localiser une latence (RD-5) ;
- le backend est un jour exposé hors de la machine ou repris en production.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée ; Q-55 tranchée (coupe C2). Parole du porteur (conversation avec l'assistant, 2026-10-29), en réponse au tableau des questions présenté juste avant : « Pour les questions, utilise tes recommandations » | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
