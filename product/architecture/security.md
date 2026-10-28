---
id: p-ar-security
title: Sécurité de la démo
area: architecture
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p7, knowledge:rt-ephemeral-keys, knowledge:adr-0002-orchestrator-backend, knowledge:genui-a2ui-security, knowledge:proto-a2a-security, knowledge:ma-prompt-injection-tools, knowledge:proj-sk-backend]
links: [p-ar-overview, p-ar-backend, p-ar-frontend, p-ar-replay, p-ar-stage-runtime, p-fn-nfr, p-fn-scope, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0007-closed-catalog-stage-theme, pdr-0011-adopt-knowledge-adrs, rt-ephemeral-keys, rt-gpt-live-webrtc-session, adr-0002-orchestrator-backend, adr-0003-backend-go, genui-a2ui-security, genui-user-actions, proto-a2a-security, ma-prompt-injection-tools, ma-guardrails, ma-backend-stack-recommendation, proj-sk-backend, proj-avw-risks, rt-gpt-live-overview, ux-genui-catalog-as-ds]
tags: [securite, cles, jeton-ephemere, a2ui, a2a, prompt-injection, cout]
---
# Sécurité de la démo

**En bref.** Même pour une démo ([pdr-0001](../decisions/pdr-0001-conference-demo-deliverable.md)), aucune clé OpenAI ni secret d'agent ne vit dans l'app (NFR-09). Le backend relaie la création de session voix, valide tout A2UI contre le catalogue fermé et plafonne le coût (NFR-11). Le risque principal reste **financier et réputationnel** (quota brûlé, contenu inattendu à l'écran), pas la fuite de données : tout est fictif.

> Statut : **draft**. Règles tirées d'AGENTS.md §2 et de la base `knowledge/` ; leur adaptation au contexte « scène » est une proposition.

## Menaces et parades

| Menace | Parade | Exigence / source |
|---|---|---|
| Fuite de la clé OpenAI | clé **uniquement** côté backend ; session créée par relais SDP ; pas de client secret pour GPT-Live | NFR-09 ; [rt-ephemeral-keys], [rt-gpt-live-webrtc-session] ; [proj-avw-risks] n°4 |
| Route de relais abusée (quota brûlé) | route authentifiée, débit limité, durée de session plafonnée, budget projet OpenAI | NFR-11 ; [ma-backend-stack-recommendation] risque 1 |
| JWT non vérifiés, CORS ouvert (hérités du kit) | JWKS (jamais `ParseUnverified`), allowlist d'origines | AGENTS.md §2 ; [proj-sk-backend] |
| UI injectée par l'agent | catalogue **fermé** `genesis`, validation **deux fois** (orchestrateur puis client), pas de `BasicCatalogItems` complet | [genui-a2ui-security] ; [pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md) |
| Style imposé par l'agent | couleurs et tailles du thème de scène uniquement ; `theme` de `createSurface` ignoré | fiche §7 ; [ux-genui-catalog-as-ds] |
| URL arbitraires (`openUrl`, `Image`) | fonctions absentes du catalogue, ou allowlist https | [genui-a2ui-security] |
| Action exécutée par le client | les clics sont des **événements typés** renvoyés à l'orchestrateur, jamais exécutés localement | [genui-user-actions] |
| Injection indirecte via les données (extraits d'avis) | retours d'agents encadrés comme données ; la voix ne reçoit qu'un résumé produit par l'orchestrateur | [ma-prompt-injection-tools] |
| Agent A2A non fiable (agent tiers, E6) | Agent Card vérifiée, identité de service (client credentials ou mTLS), sorties traitées comme données | [proto-a2a-security] |
| Secret dans le contexte du modèle | rien de secret dans `commentary/thinking.append` ni dans le data model A2UI | [rt-ephemeral-keys], [genui-a2ui-security] |
| Secret dans le journal | le journal ne contient que ce qui atteint l'écran ; revue avant commit d'une session de référence | [p-ar-replay](replay.md) |

## Contrat de la route de relais

Origine : knowledge [rt-ephemeral-keys] (ex-section « Recommandation pour notre app », opinion), transféré le 2026-10-28 ; le patron générique reste dans la note.

- Un endpoint backend `POST /voice/sessions {provider, agentProfile}`, protégé par l'auth utilisateur, journalisé et limité en débit par utilisateur (mode d'authentification ouvert : Q-48 ci-dessous).
- Il renvoie soit l'answer SDP (GPT-Live), soit un jeton (Gemini direct).
- Instructions système et outils restent **côté serveur** : `session` OpenAI, ou `liveConnectConstraints` Gemini.
- Un jeton = une API : le jeton vocal ne sert jamais à appeler un LLM texte.
- Les secrets MCP et A2A ne quittent jamais l'orchestrateur.

## Authentification : tension à arbitrer

La fiche exclut « authentification utilisateur, multi-utilisateur » du périmètre (§3). AGENTS.md impose pourtant des JWT vérifiés par JWKS côté backend. Il ne s'agit pas d'authentifier le public mais de **protéger la route de relais** qui consomme le budget OpenAI.

| Option | Principe | Limite |
|---|---|---|
| A. Backend local lié à `localhost` | aucune surface exposée sur le réseau de la salle | backend sur la machine de démo ([p-ar-stage-runtime](stage-runtime.md)) |
| B. Jeton court de l'opérateur | connexion de l'opérateur avant le talk (Authorization Code + PKCE), jeton court | nécessite un IdP joignable |
| C. Secret statique dans l'app | — | **interdit** : clé longue durée côté client (AGENTS.md §2) |

Aucune option n'est retenue ici ([Q-48](../roadmap/open-questions.md)).

## Coût (NFR-11)

- GPT-Live : 0,05 $/min, facturé à la seconde ; 15 s facturées à l'initialisation WebRTC puis créditées ; LLM texte facturé à part ([rt-gpt-live-overview]).
- Proposition : plafond de durée par session, nombre de sessions par heure, budget mensuel côté projet OpenAI, compteur affiché dans les logs de répétition. Le chiffrage d'une répétition complète reste à mesurer.

## Gestion des secrets sur la machine de démo

- Clé OpenAI dans l'environnement du backend ou le trousseau système, jamais dans le dépôt ni dans `pubspec`/assets.
- Une clé de projet dédiée à la démo, révocable après le talk (proposition).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Mode d'authentification** de la route de relais (A ou B ci-dessus) → Q-48.
- **Plafonds de coût** : valeurs par session et par répétition → Q-13.
- **Confirmation** du clic « Bloquer la release » : action fictive, donc sans confirmation hors GenUI ? (la règle générique l'exige pour les actions sensibles, [genui-a2ui-security]) → Q-49.
- **Agent d'un autre éditeur** (E6) : modèle de confiance et authentification → Q-10.
