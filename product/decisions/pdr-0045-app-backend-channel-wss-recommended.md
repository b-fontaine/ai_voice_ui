---
id: pdr-0045-app-backend-channel-wss-recommended
title: "PDR-0045 — Canal app ↔ backend : WSS app-channel maison, genui_a2a hors de la stack de l'app"
area: decisions
status: validated
updated: 2026-10-29
sources: [specs/001-sp-03-a2a-go-genui/notes-s1.md, specs/001-sp-03-a2a-go-genui/notes-s3.md, product/architecture/backend.md, product/architecture/agents-protocols.md]
links: [p-rm-open-questions, p-ar-agents-protocols, p-ar-backend, p-ar-frontend, p-ar-stack, p-rm-spikes, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0010-pinned-experimental-versions, proto-a2a-go-v03-compat, genui-a2a-connector, genui-test-a2a-roundtrip, ma-backend-sdk-go]
tags: [pdr, decision, canal, a2a, a2ui, websocket]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0045 — Canal app ↔ backend : WSS app-channel maison

> **En bref.** Acceptée par le porteur le 2026-10-29 (recommandation de l'assistant) ; tranche Q-39. Le spike SP-03 établit que `genui_a2a` 0.10.1 **fonctionne** avec un agent `a2a-go` v2 (via `a2acompat/a2av0`) : le risque d'incompatibilité n'existe plus. Le canal app ↔ backend est un **WSS app-channel maison** ; `genui_a2a` n'entre pas dans la stack de l'app.

Part de l'assistant : recommandation acceptée par le porteur (pas une décision contrainte : plusieurs options valables).

## Contexte
- Q-39 : quel canal entre l'app et le backend, et `genui_a2a` entre-t-il dans la stack ? ([p-rm-open-questions](../roadmap/open-questions.md)).
- Fait établi par SP-03 (code lu, essai de bout en bout, 2026-10-29) : `genui_a2a` 0.10.1 parle A2A v0.3 ; un agent Go doit monter le handler `a2acompat/a2av0` (le handler natif v1.0 répond `-32009`) ; surface rendue et action aller-retour sans glue supplémentaire ([proto-a2a-go-v03-compat], [genui-a2a-connector], [genui-test-a2a-roundtrip]).
- L'app-channel est décrit comme un WSS qui porte A2UI, **activité des agents, transcript, état de l'orbe**, et reçoit les actions typées ([p-ar-backend](../architecture/backend.md), [p-ar-agents-protocols](../architecture/agents-protocols.md)). Le panneau protocole (FR-05) exige l'accès aux messages bruts ; le `session-recorder` copie ce qui part sur l'app-channel (FR-09).
- `genui_a2a` ne lit que les parts A2UI des `status-update` (messages déjà parsés) et le texte libre : activité des agents, transcript et état de l'orbe n'y ont pas de place native ([genui-a2a-connector]).

## Hypothèses
- ✅ `genui_a2a` + `a2a-go` v2 sont compatibles (SP-03).
- Point de l'option 2 laissé non vérifié : le panneau protocole (FR-05) aurait pu se contenter de messages A2UI re-sérialisés depuis les objets parsés de `genui_a2a` (la fiche demande les messages bruts) ; sans objet depuis le choix du WSS maison.

## Options
1. **WSS app-channel maison** (recommandée) : un seul canal pour A2UI, événements d'orchestration, transcript, état de l'orbe, actions ; le journal du serveur en est la copie.
2. **`genui_a2a`** : l'orchestrateur s'expose en A2A, l'app utilise `A2uiAgentConnector` pour l'A2UI et les actions ; il faut un second canal pour tout ce qui n'est pas de l'A2UI (transcript, orbe, activité des agents).

## Décision
L'app-channel est un WSS maison ; `genui_a2a` n'entre pas dans la stack de l'app pour la démo. Les agents spécialisés, eux, parlent A2A à l'orchestrateur côté backend ([pdr-0036](pdr-0036-real-a2a-agents-produce-a2ui.md)), avec `a2a-go` v2 ; si un agent doit être consommé par un client Dart, `a2acompat/a2av0` le permet.

## Raisons
- Un seul canal à tester, à enregistrer (FR-09) et à afficher dans le panneau protocole (FR-05), sans second chemin pour les événements non A2UI.
- Moins de dépendances expérimentales figées (pdr-0010) : `genui_a2a` n'est pas nécessaire au MVP.
- Les actions restent des événements typés ([genui-user-actions]).

## Options écartées
- Option 2 : fonctionne techniquement (SP-03), mais impose un second canal pour les événements hors A2UI et n'offre pas l'accès aux messages bruts sans travail supplémentaire (non vérifié).

## Conséquences
- [p-ar-agents-protocols](../architecture/agents-protocols.md), [p-ar-backend](../architecture/backend.md), [p-ar-frontend](../architecture/frontend.md), [p-ar-stack](../architecture/stack.md) : canal = WSS app-channel maison ; `genui_a2a` hors stack de l'app (le gel de [pdr-0010](pdr-0010-pinned-experimental-versions.md) s'y appliquerait s'il était ajouté).
- [p-rm-spikes](../roadmap/spikes.md) : SP-03 ✅ ; le crédit de 1 j (RD-2) en cas de ❌ n'est pas consommé.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-39 tranchée → pdr-0045 (2026-10-29) ; [p-rm-roadmap](../roadmap/roadmap.md) : Q-39 levée pour J2.

## Réexaminer si
- Le panneau protocole (FR-05) peut se contenter de messages parsés et le porteur veut limiter le code maison ;
- un client tiers doit consommer l'orchestrateur en A2A.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Proposée, après SP-03 | Assistant |
| 2026-10-29 | Acceptée ; Q-39 tranchée. Parole du porteur (conversation avec l'assistant, 2026-10-29), en réponse au tableau des questions présenté juste avant (Q-39 : WSS app-channel maison, `genui_a2a` hors stack) : « Pour les questions, utilise tes recommandations » | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute (constats dans `specs/001-sp-03-a2a-go-genui/notes-s1.md` et `notes-s3.md`).
