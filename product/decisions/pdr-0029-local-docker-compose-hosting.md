---
id: pdr-0029-local-docker-compose-hosting
title: "PDR-0029 — Tout tourne en local : docker-compose pour le backend Go et les agents, app Flutter en debug hors conteneur, clé OpenAI côté backend"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p7, knowledge:rt-ephemeral-keys, knowledge:adr-0003-backend-go]
links: [pdr-0041-backend-in-this-repo-local-no-auth, pdr-0001-conference-demo-deliverable, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai, pdr-0028-linux-demo-machine, pdr-0031-github-actions-ci-linux, pdr-0036-real-a2a-agents-produce-a2ui, p-ar-backend, p-ar-security, p-ar-overview, p-ar-stage-runtime, p-rm-backend-production-plan, p-rm-beyond, p-rm-roadmap, p-rm-open-questions, adr-0002-orchestrator-backend, adr-0003-backend-go, adr-0006-ds-no-widgetbook-cloud, adr-0008-ds-widgetbook-4-beta, rt-ephemeral-keys, proj-sk-backend]
tags: [pdr, decision, hebergement, docker, local, securite]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29 ; parties contraintes (app hors conteneur, processus séparés, clé côté backend) : Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0001-conference-demo-deliverable, pdr-0028-linux-demo-machine, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0012-voice-provider-openai, rt-ephemeral-keys]
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0029 — Hébergement local de la démo

> **En bref.** Tout tourne **en local** sur la machine de démo. Un `docker-compose.yaml`, rédigé par l'assistant, lance le backend Go et les agents A2A. L'app Flutter desktop tourne **en debug** sur la machine, hors conteneur. La clé OpenAI reste côté backend, dans une variable d'environnement non commitée. Tranche Q-15 (porteur). Le dépôt du code (Q-27) et la protection de la route de relais (Q-48) étaient ouverts ; ils sont confirmés par [pdr-0041](pdr-0041-backend-in-this-repo-local-no-auth.md).

Part de l'assistant : consignation de l'arbitrage du porteur (local, docker, debug) ; décisions contraintes sur les points qui en découlent (voir « Parties contraintes ») ; recommandations, non décidées, sur Q-27 et Q-48.

## Contexte
- Q-15 : backend en cloud ou en local ? Q-27 : dépôt du code (`septeo_saaster_kit`, ce dépôt, dépôt dédié) ? Q-48 : comment protéger la route de relais SDP ?
- [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) visait un socle de production Septeo (Keycloak, Kong, Temporal).
- AGENTS.md § 2 (règle « non négociable ») place le backend dans le module `backend/agent_orchestrator` de `septeo_saaster_kit` et impose des JWT vérifiés par JWKS ; [adr-0003-backend-go] aussi. Le porteur ne s'est prononcé ni sur le dépôt ni sur l'authentification.

## Hypothèses
- ✅ Démo de conférence, sans authentification utilisateur ni multi-utilisateur ([pdr-0001](pdr-0001-conference-demo-deliverable.md), fiche § 3).
- ✅ Aucune clé OpenAI dans l'app (NFR-09) ; GPT-Live : relais SDP par le backend [rt-ephemeral-keys].
- ✅ Front Flutter, Design System + Widgetbook, backend Go : décisions héritées ([pdr-0011](pdr-0011-adopt-knowledge-adrs.md), [adr-0003-backend-go], [adr-0006-ds-no-widgetbook-cloud], [adr-0008-ds-widgetbook-4-beta]).

## Options
1. **Local sur la machine de démo, via docker-compose** (retenue par le porteur)
2. Cloud
3. Local en secours d'un cloud

## Décision
| Élément | Décision | Nature |
|---|---|---|
| Hébergement | tout en local sur la machine de démo ([pdr-0028](pdr-0028-linux-demo-machine.md)) | porteur |
| Compose | un `docker-compose.yaml` rédigé par l'assistant lance le backend Go (orchestrateur) et les agents A2A | porteur |
| Agents | un processus par agent A2A | contrainte (Q-16 « agents réels », [pdr-0036](pdr-0036-real-a2a-agents-produce-a2ui.md)) |
| Découpage du compose | un service (conteneur) par agent | choix de conception de l'assistant, pas une décision du porteur |
| App Flutter | lancée en **debug** sur la machine, hors conteneur | porteur (« en debug ») + contrainte (hors conteneur) |
| Stack | front Flutter, Design System + Widgetbook, backend Go, selon `knowledge/` | porteur (déjà hérité) |
| Clé OpenAI | côté backend uniquement, variable d'environnement, fichier `.env` non commité | contrainte |

## Parties contraintes (constraint_basis)
Une seule réponse est correcte au vu de l'arbitrage du porteur et des décisions acceptées :
- **App hors conteneur** : une app Flutter desktop a besoin du serveur graphique, du micro et de la sortie audio de la machine ; le porteur la lance en debug. Base : parole du porteur, [pdr-0028](pdr-0028-linux-demo-machine.md).
- **Un processus par agent** : Q-16 opposait « vrais serveurs A2A séparés » et « agents internes » ; « agents réels » impose des serveurs distincts. Base : [pdr-0036](pdr-0036-real-a2a-agents-produce-a2ui.md). Le découpage en un conteneur par agent est en revanche un choix de conception de l'assistant (un service compose par serveur), révisable sans PDR.
- **Clé côté backend, `.env` non commité** : aucune clé dans l'app (NFR-09, AGENTS.md § 2 « Sécurité »), relais SDP par le backend. Base : [pdr-0012](pdr-0012-voice-provider-openai.md), [rt-ephemeral-keys].

## Recommandations de l'assistant, à confirmer par le porteur (non décidées)
- **Q-27, dépôt** : recommandation « ce dépôt » (démo autonome, compose à côté des sources). Ce n'est pas une décision contrainte : un compose peut aussi construire des sources d'un autre dépôt, et AGENTS.md § 2 et [adr-0003-backend-go] désignent `septeo_saaster_kit`. Si le porteur confirme : ligne d'historique dans adr-0003 (portée démo) et précision dans AGENTS.md § 2 (la règle vise le socle de production).
- **Q-48, route de relais** : recommandation « ports publiés sur `127.0.0.1`, sans authentification » (option A de [p-ar-security](../architecture/security.md)). Elle s'écarte de la règle JWT par JWKS d'AGENTS.md § 2 : à faire confirmer par le porteur.

## Raisons
- Parole du porteur (2026-10-29) : « C'est une démo, tout sera en local sur un docker (via un docker-compose.yaml que tu rédigeras) et selon les préconisations de ta base de connaissances (front Flutter, Design System avec Widgetbook et backend en Go si je me souviens bien). »
- Parole du porteur (2026-10-29) : « je pensais lancer le projet en debug sur mon poste. »

## Options écartées
- **Cloud** : écarté par le porteur ; le réseau ne sert plus qu'à GPT-Live et au LLM texte.

## Conséquences
- [p-ar-backend](../architecture/backend.md) : profil de déploiement démo décidé (compose, sans Keycloak, Kong, Postgres ni Temporal) ; dépôt et authentification en attente de Q-27 et Q-48.
- [p-ar-security](../architecture/security.md) : option A recommandée (Q-48 ouverte) ; clé en `.env` ignoré par Git.
- [p-ar-overview](../architecture/overview.md) : vue de déploiement local.
- [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) : non appliqué à la démo.
- Livrable de l'assistant : `docker-compose.yaml` (backlog EP-01).

## Réexaminer si
- La démo doit tourner sur une autre machine que celle du porteur, ou exposer un service sur le réseau.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « tout sera en local sur un docker (via un docker-compose.yaml que tu rédigeras) » ; « je pensais lancer le projet en debug sur mon poste » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Parties contraintes consignées (app hors conteneur, un processus par agent, clé côté backend) | Assistant (décision contrainte) |
| 2026-10-29 | Q-27 et Q-48 confirmées par le porteur : voir [pdr-0041](pdr-0041-backend-in-this-repo-local-no-auth.md) (sans réécriture de la présente décision) | Assistant |
| 2026-10-29 | Revue : Q-27 (dépôt) et Q-48 (pas d'auth, `127.0.0.1`) retirées des parties contraintes et rouvertes (écart avec AGENTS.md § 2, parole du porteur muette) ; « un conteneur par agent » requalifié en choix de conception de l'assistant | Assistant |

Pas d'archive brute.
