---
id: p-ar-security
title: Sécurité de la démo
area: architecture
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p7, knowledge:rt-ephemeral-keys, knowledge:adr-0002-orchestrator-backend, knowledge:genui-a2ui-security, knowledge:proto-a2a-security, knowledge:ma-prompt-injection-tools, knowledge:proj-sk-backend]
links: [p-ar-agents-protocols, pdr-0041-backend-in-this-repo-local-no-auth, p-ar-overview, p-ar-backend, p-ar-frontend, p-ar-replay, p-ar-stage-runtime, p-fn-nfr, p-fn-scope, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0007-closed-catalog-stage-theme, pdr-0011-adopt-knowledge-adrs, rt-ephemeral-keys, rt-gpt-live-webrtc-session, adr-0002-orchestrator-backend, adr-0003-backend-go, genui-a2ui-security, genui-user-actions, proto-a2a-security, ma-prompt-injection-tools, ma-guardrails, ma-backend-stack-recommendation, proj-sk-backend, proj-avw-risks, rt-gpt-live-overview, ux-genui-catalog-as-ds, pdr-0029-local-docker-compose-hosting, pdr-0030-llm-budget-20-eur, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0035-no-third-party-agent]
tags: [securite, cles, jeton-ephemere, a2ui, a2a, prompt-injection, cout]
---
# Sécurité de la démo

**En bref.** Même pour une démo ([pdr-0001](../decisions/pdr-0001-conference-demo-deliverable.md)), aucune clé OpenAI ni secret d'agent ne vit dans l'app (NFR-09). Le backend relaie la création de session voix, valide tout A2UI contre le catalogue fermé et plafonne le coût (NFR-11). Tout tourne en local : services liés à `127.0.0.1`, sans authentification utilisateur, clé OpenAI en variable d'environnement du backend ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)). Le risque principal reste **financier et réputationnel** (quota brûlé, contenu inattendu à l'écran), pas la fuite de données : tout est fictif.

> Statut : **draft**. Règles tirées d'AGENTS.md §2 et de la base `knowledge/` ; leur adaptation au contexte « scène » est une proposition.

## Menaces et parades

| Menace | Parade | Exigence / source |
|---|---|---|
| Fuite de la clé OpenAI | clé **uniquement** côté backend ; session créée par relais SDP ; pas de client secret pour GPT-Live | NFR-09 ; [rt-ephemeral-keys], [rt-gpt-live-webrtc-session] ; [proj-avw-risks] n°4 |
| Route de relais abusée (quota brûlé) | route non exposée (`127.0.0.1`, décidé : [pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md)), contrôle de `Host`, débit limité (implémentés, 003), durée de session plafonnée, budget de 20 € ([pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)) | NFR-11 ; [ma-backend-stack-recommendation] risque 1 ; [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md) |
| JWT non vérifiés, CORS ouvert (hérités du kit) | recommandation de l'assistant (Q-48, à confirmer) : sans objet en démo, ni IdP ni exposition réseau ; la règle JWKS / allowlist d'AGENTS.md § 2 vaudrait pour le socle de production | AGENTS.md §2 ; [proj-sk-backend] ; [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md) |
| UI injectée par l'agent | catalogue **fermé** `genesis`, validation **deux fois** (orchestrateur puis client), pas de `BasicCatalogItems` complet | [genui-a2ui-security] ; [pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md) |
| Style imposé par l'agent | couleurs et tailles du thème de scène uniquement ; `theme` de `createSurface` ignoré | fiche §7 ; [ux-genui-catalog-as-ds] |
| URL arbitraires (`openUrl`, `Image`) | fonctions absentes du catalogue, ou allowlist https | [genui-a2ui-security] |
| Action exécutée par le client | les clics sont des **événements typés** renvoyés à l'orchestrateur, jamais exécutés localement | [genui-user-actions] |
| Injection indirecte via les données (extraits d'avis) | retours d'agents encadrés comme données ; la voix ne reçoit qu'un résumé produit par l'orchestrateur | [ma-prompt-injection-tools] |
| Agent A2A non fiable (agent tiers, E6) | sans objet : pas d'agent tiers ([pdr-0035](../decisions/pdr-0035-no-third-party-agent.md)) ; les agents du produit tournent en local, leurs sorties restent traitées comme données | [proto-a2a-security] |
| Secret dans le contexte du modèle | rien de secret dans `commentary/thinking.append` ni dans le data model A2UI | [rt-ephemeral-keys], [genui-a2ui-security] |
| Secret dans le journal | le journal ne contient que le flux A2UI ; pas de session de référence committée ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) | [p-ar-replay](replay.md) |

## Contrat de la route de relais

Origine : knowledge [rt-ephemeral-keys] (ex-section « Recommandation pour notre app », opinion), transféré le 2026-10-28 ; le patron générique reste dans la note. **Implémenté par la fonctionnalité 003 (2026-10-29)**, vérifié par les tests d'acceptation A1-A3 et par l'essai réel du jour ; contrat complet : [p-ar-agents-protocols](agents-protocols.md) § « Contrat v1 implémenté ».

| Point | Implémenté | Exigence / source |
|---|---|---|
| Route | `POST /voice/sessions`, corps `application/sdp` (offre) → answer SDP et `X-Session-Id` ; instructions et outils côté serveur ; 415 si autre type, 413 si trop gros ; erreurs `{error}` opaques (502) | NFR-09 ; [rt-ephemeral-keys], [rt-gpt-live-webrtc-session] |
| Hôte | contrôle de l'en-tête `Host` sur toutes les routes (`127.0.0.1`, `localhost`, `[::1]` avec port, plus `ALLOWED_HOSTS`) ; autre hôte : 421 sans détail (anti DNS rebinding) | [pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md) |
| Débit | seau à jetons (`SESSION_RATE_BURST`, `SESSION_RATE_WINDOW`) : 429 + `Retry-After` ; durée plafonnée (`VOICE_MAX_SESSION`, valeur provisoire : Q-68) ; journal d'accès sans corps | NFR-11 ; [pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md) |
| Clé | `OPENAI_API_KEY` jamais dans les logs, le journal JSONL, l'app-channel ni les messages d'erreur : test d'acceptation A1 (toutes sorties, logs slog compris) et essai réel (logs du conteneur, journal) ; `Config.String()` la masque | NFR-09 |
| Conteneur | `read_only`, `cap_drop: ALL`, `no-new-privileges` ; image distroless non-root (65532) aux bases figées par digest ; port publié sur `127.0.0.1:8080` seulement (le conteneur écoute sur `0.0.0.0`, `LISTEN_ALLOW_NON_LOOPBACK=1`) ; journal 0600 dans un volume nommé | [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md), [pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md) |
| Origine WSS | origine WebSocket vérifiée par défaut ; abonné lent coupé en 1008 | revue d'architecte R1-R12 |

- Pas d'authentification utilisateur (option A ci-dessous). Un jeton = une API : le jeton vocal ne sert jamais à appeler un LLM texte. Les secrets MCP et A2A ne quittent jamais l'orchestrateur.
- Non implémenté (hors démo) : renvoi d'un jeton pour Gemini direct ; route protégée par l'auth utilisateur du patron générique.

## Authentification : option A décidée (Q-48, pdr-0041)

La fiche exclut « authentification utilisateur, multi-utilisateur » du périmètre (§3). AGENTS.md impose pourtant des JWT vérifiés par JWKS côté backend. Il ne s'agit pas d'authentifier le public mais de **protéger la route de relais** qui consomme le budget OpenAI.

| Option | Principe | Limite |
|---|---|---|
| A. Backend local lié à `localhost` | aucune surface exposée sur le réseau de la salle | backend sur la machine de démo ([p-ar-stage-runtime](stage-runtime.md)) |
| B. Jeton court de l'opérateur | connexion de l'opérateur avant le talk (Authorization Code + PKCE), jeton court | nécessite un IdP joignable |
| C. Secret statique dans l'app | — | **interdit** : clé longue durée côté client (AGENTS.md §2) |

**Option A décidée par le porteur le 2026-10-29** ([pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md)) : tout est local ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)), aucune surface n'est exposée sur le réseau de la salle, et la fiche exclut l'authentification utilisateur. Elle écarte la règle JWT par JWKS d'AGENTS.md § 2 pour la démo (AGENTS.md mis à jour).

## Coût (NFR-11)

- GPT-Live : 0,05 $/min, facturé à la seconde ; 15 s facturées à l'initialisation WebRTC puis créditées ; LLM texte facturé à part ([rt-gpt-live-overview]).
- Budget total : **20 €** pour tous les modèles ([pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)). Proposition : plafond de durée par session, nombre de sessions par heure, budget côté projet OpenAI, compteur dans les logs de répétition.

## Gestion des secrets sur la machine de démo

- Clé OpenAI dans une variable d'environnement du backend, chargée par `docker compose` depuis un fichier `.env` ignoré par Git ; jamais dans le dépôt ni dans `pubspec`/assets ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)).
- Une clé de projet dédiée à la démo, révocable après le talk (proposition).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- Mode d'authentification : option A recommandée, à confirmer (Q-48). ~~Plafond de coût~~ : 20 € ([pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)).
- **Confirmation** du clic « Bloquer la release » : action fictive, donc sans confirmation hors GenUI ? (la règle générique l'exige pour les actions sensibles, [genui-a2ui-security]) → Q-49.
- ~~Agent d'un autre éditeur~~ (E6) : sans objet ([pdr-0035](../decisions/pdr-0035-no-third-party-agent.md)).
