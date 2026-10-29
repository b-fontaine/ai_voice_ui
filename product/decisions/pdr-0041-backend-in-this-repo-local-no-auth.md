---
id: pdr-0041-backend-in-this-repo-local-no-auth
title: "PDR-0041 — Le backend de démo vit dans ce dépôt (backend/), lié à 127.0.0.1, sans authentification utilisateur"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p3, knowledge:rt-ephemeral-keys, knowledge:adr-0003-backend-go]
links: [pdr-0001-conference-demo-deliverable, pdr-0029-local-docker-compose-hosting, pdr-0012-voice-provider-openai, p-ar-backend, p-ar-security, p-ar-overview, p-rm-backend-production-plan, p-rm-open-questions, adr-0003-backend-go, rt-ephemeral-keys]
tags: [pdr, decision, backend, depot, securite, local]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29 (choix « Oui, tout (Recommandé) »)"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0041 — Backend dans ce dépôt, local, sans authentification

> **En bref.** Le code du backend de démo (orchestrateur Go, agents A2A) vit dans **ce dépôt**, sous `backend/` (Q-27). Les services sont liés à `127.0.0.1`, sans authentification utilisateur ; la clé OpenAI reste côté backend dans un `.env` non versionné (Q-48). Confirme les recommandations de [pdr-0029](pdr-0029-local-docker-compose-hosting.md). AGENTS.md § 2 a été mis à jour en conséquence le 2026-10-29.

Part de l'assistant : recommandation (dans pdr-0029), consignation de la confirmation du porteur et propagation. Décision du porteur.

## Contexte
- Q-27 : dépôt du backend (`septeo_saaster_kit`, ce dépôt, dépôt dédié). Q-48 : protection de la route de relais SDP.
- AGENTS.md § 2 et [adr-0003-backend-go] visaient `septeo_saaster_kit` et des JWT vérifiés par JWKS : cadre d'un produit de production, écarté pour la démo ([pdr-0001](pdr-0001-conference-demo-deliverable.md), [pdr-0029](pdr-0029-local-docker-compose-hosting.md)).

## Hypothèses
- ✅ Démo locale, un seul poste, sans multi-utilisateur ([pdr-0001](pdr-0001-conference-demo-deliverable.md), [pdr-0029](pdr-0029-local-docker-compose-hosting.md)).
- ✅ Aucune clé dans l'app ([rt-ephemeral-keys], NFR-09).

## Options
1. **Ce dépôt, `127.0.0.1`, sans authentification** (retenue)
2. `septeo_saaster_kit` ; dépôt dédié
3. Jeton court de l'opérateur ; JWT Keycloak

## Décision
- Le backend vit dans ce dépôt, sous `backend/`.
- Services publiés sur `127.0.0.1` uniquement, sans authentification utilisateur.
- Clé OpenAI côté backend, dans un `.env` non versionné.
- Le plan de production ([p-rm-backend-production-plan](../roadmap/backend-production-plan.md)) et la règle JWKS d'AGENTS.md § 2 ne s'appliquent pas à la démo.

## Raisons
- Question posée au porteur : « Je lance le dispositif (commit sur main, worktree, première itération suivie ensemble) ? » ; option choisie : « Oui, tout (Recommandé) », dont le texte était : « Je mets à jour AGENTS.md § 2 (backend local dans ce dépôt, sans auth), j'enregistre le calendrier et l'ordre de coupe C1-C5 tels que proposés, je commite, je crée le worktree et je lance la boucle dès que xvfb est installé. »
- Démo autonome : compose et sources côte à côte ; aucune surface exposée sur le réseau de la salle.

## Options écartées
- `septeo_saaster_kit`, dépôt dédié, jeton opérateur, JWT Keycloak : non retenus par le porteur ; sans objet pour une démo locale.

## Conséquences
- [p-ar-backend](../architecture/backend.md), [p-ar-security](../architecture/security.md), [p-ar-overview](../architecture/overview.md) : dépôt et authentification décidés.
- [adr-0003-backend-go] : reste valable pour le langage et l'hexagonal ; sa portée « module du kit » et la règle JWKS ne visent pas la démo (note en AGENTS.md § 2).
- Q-27 et Q-48 tranchées.

## Réexaminer si
- Le code de la démo est ouvert au public ([beyond.md](../roadmap/beyond.md)) ou un service est exposé sur le réseau.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : choix « Oui, tout (Recommandé) » à la question « Je lance le dispositif… ? » (texte cité en Raisons), conversation | Benoît FONTAINE (porteur) |
| 2026-10-29 | AGENTS.md § 2 mis à jour (backend local dans ce dépôt, sans auth) ; propagation | Assistant |

Pas d'archive brute.
