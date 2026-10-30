---
id: p-ar-agents-protocols
title: Agents, protocoles et séquences des actes
area: architecture
status: draft
updated: 2026-10-30
sources: [specs/007-j3-act1-frontend/plan.md, specs/007-j3-act1-frontend/status.md, specs/006-j3-act1-backend/plan.md, specs/006-j3-act1-backend/status.md, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p5, product/sources/design-example.pdf, knowledge:proto-protocol-map, knowledge:rt-gpt-live-delegation, knowledge:rt-barge-in, knowledge:genui-a2ui-messages, knowledge:genui-a2a-connector, specs/003-j2-voice-relay-backend/plan.md, specs/004-j2-orchestrator-quality-agent/plan.md]
links: [p-ar-app-channel-contract, p-ar-frontend-screen, pdr-0053-client-side-a2ui-validation-from-007, pdr-0056-failed-agent-partial-surfaces-removed, pdr-0058-backend-canvas-registry-survives-voice-sessions, p-ar-security, p-ar-quality, proto-a2a-agent-card, pdr-0045-app-backend-channel-wss-recommended, pdr-0051-orb-level-from-sideband-rms-recommended, pdr-0052-one-gpt-live-session-per-act-recommended, rt-gpt-live-output-level, rt-graceful-close, proto-a2a-bindings, proto-a2a-dart-sdk, ma-backend-sdk-go, p-ar-overview, p-ar-backend, p-ar-frontend, p-ar-replay, p-fn-requirements, p-fn-mockups, p-fn-catalog, p-fn-personas-journey, p-rm-open-questions, p-rm-spikes, pdr-0004-mvp-three-acts, pdr-0012-voice-provider-openai, proto-protocol-map, proto-a2a-overview, proto-a2a-task-lifecycle, proto-a2a-streaming-push, rt-gpt-live-webrtc-session, rt-gpt-live-sideband, rt-gpt-live-delegation, rt-gpt-live-lifecycle, rt-barge-in, rt-transcription, genui-a2ui-messages, genui-a2ui-overview, genui-a2ui-transports, genui-user-actions, genui-a2a-connector, ma-real-tool-results, ma-filler-acknowledgements, ma-backend-stack-recommendation, ma-target-architecture, rt-ephemeral-keys, pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0026-desktop-only-target, pdr-0035-no-third-party-agent, pdr-0036-real-a2a-agents-produce-a2ui]
tags: [protocoles, a2a, a2ui, webrtc, sideband, sequence, barge-in, actes]
---
# Agents, protocoles et séquences des actes

**En bref.** La voix circule en WebRTC entre l'app et GPT-Live ; le backend écoute la même session en sideband et reçoit la délégation ; il délègue aux agents en A2A ; l'UI revient à l'app en messages A2UI sur un canal séparé (proposé : WSS maison ; alternative `genui_a2a`, ouvert → Q-39), et les clics repartent par le même canal. Ce document donne les séquences des 3 actes ([pdr-0004](../decisions/pdr-0004-mvp-three-acts.md)), de l'interruption et de « Stop ».

> Statut : **draft**. Le contrat app-channel / API v1 est **implémenté** (fonctionnalités 003, 004, 006 et 007, [p-ar-app-channel-contract](app-channel-contract.md)). Les séquences sont la proposition de l'assistant, construites sur les faits de la base `knowledge/`. Version A2UI : v0.9 ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)). Producteur de l'A2UI : chaque agent A2A, l'orchestrateur valide et relaie ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md), Q-37). Choix encore ouvert : canal app ↔ backend (Q-39).

## Qui parle à qui, avec quoi

| De → vers | Protocole | Contenu | Source |
|---|---|---|---|
| App ↔ GPT-Live | **WebRTC** (média + DataChannel `oai-events`) | voix du speaker, voix de l'IA | [rt-gpt-live-webrtc-session] |
| App → backend | **HTTPS** `POST /voice/sessions` ; `POST /canvas/reset` (007) | offre SDP → answer SDP ; remise à vide du canevas (`{}` en JSON, 204) | [rt-ephemeral-keys] |
| Backend ↔ GPT-Live | **REST** + **sideband WSS** `/live/sessions/{id}/attach` | transcripts, `delegation.created`, `commentary/thinking.append`, `close` | [rt-gpt-live-sideband] |
| Orchestrateur ↔ agents | **A2A v1.0** (JSON-RPC + SSE) | tâches, statut, Artifacts ; cartes avec `skills[].tags` et `examples` (006) ; clé de metadata `genesis/activeSurfaces` (surfaces actives de l'agent) | [proto-a2a-task-lifecycle], [proto-a2a-streaming-push], [proto-a2a-agent-card] |
| Backend → app | **WSS app-channel** maison ([pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md)) | messages **A2UI** v0.9 ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)), activité des agents, transcript, état orbe | [ma-backend-stack-recommendation] |
| App → backend | **WSS app-channel** | actions utilisateur typées (`UiInteractionPart`) | [genui-user-actions] |

Règles : l'A2UI ne passe **jamais** par le canal de la session voix ([genui-a2ui-transports]) ; le JSON A2UI n'est jamais lu à voix haute ([ma-target-architecture]). Le canal est un **WSS maison** ; `genui_a2a` (A2A + SSE) n'entre pas dans la stack de l'app ([pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md), acceptée, Q-39) ; le panneau protocole (FR-05) lit les messages bruts de l'app-channel. Pour mémoire, compatibilité vérifiée en SP-03 (2026-10-29) : `genui_a2a` appelle `message/stream` (A2A v0.3) ; `a2a-go` v2 doit monter le handler `a2acompat/a2av0` (le handler natif v1.0 répond `-32009`) ([proto-a2a-go-v03-compat], [genui-a2a-connector]).

## Acte 1 — Créer (FR-01 à FR-06)

```mermaid
sequenceDiagram
  actor S as Speaker
  participant App as App Flutter
  participant L as GPT-Live
  participant O as Orchestrateur
  participant Ag as Agents A2A
  S->>L: « Prépare la release 3.4 » (WebRTC)
  L-->>O: input_transcript.delta (sideband) → transcript à l'app (FR-02)
  L-->>O: session.delegation.created
  O-->>App: delegation {id, offset_ms}
  O-->>App: plan {delegation, selected[], idle[]} (cartes lues une fois, tags des skills ; avant toute activité)
  O->>L: commentary.append générique « je lance l'analyse… » (NFR-01, RG-04)
  par en parallèle, un agent par agent retenu (E1)
    O->>Ag: SendStreamingMessage (Qualité, Voix du client, Livraison) + metadata genesis/activeSurfaces
  end
  Ag-->>O: submitted → agent.activity working (rail, FR-03)
  Ag-->>O: message A2UI : createSurface + squelette (NFR-02 < 1,5 s)
  O-->>App: a2ui validé puis relayé tel quel (FR-04, FR-05, FR-06)
  Ag-->>O: updateComponents, updateDataModel, résumé, completed
  O-->>App: a2ui relayés puis agent.activity completed
  O->>L: commentary.append (vrai résumé de l'agent)
  Note over App: 4 surfaces complètes < 8 s (NFR-03)
```

**Implémenté (006)** : « Prépare la release 3.4 » retient les trois agents et produit 4 surfaces en trois temps ; une demande précise (« les avis ») ne retient que l'agent concerné (`idle` sans `agent.activity`) ; hors catalogue : aucun agent, phrase `out_of_catalog` (RG-08). Deux niveaux de refus distincts : le **choix de l'orchestrateur** (agent non retenu, aucun message) et le **refus défensif de l'agent retenu** (autre version que la 3.4, comparaison, plateforme précise : acte 2 = J4) → `agent.activity rejected`. Cartes avec `skills[].tags` et `examples` ([proto-a2a-agent-card]) ; surfaces actives dans la metadata `genesis/activeSurfaces`. Essai réel du 2026-10-30 (`gpt-live-1`) : vérifié, mesures et réserves dans [p-ar-quality](quality.md). Le squelette et les données viennent **de l'agent** ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) : l'orchestrateur valide et relaie sans recomposer, et n'émet lui-même que des `deleteSurface` de compensation. **Conséquence** : NFR-02 (1er squelette < 1,5 s) dépend de la latence du premier message de l'agent (avec un LLM de composition : Q-17).

## Acte 2 — Transformer (FR-07)

```mermaid
sequenceDiagram
  actor S as Speaker
  participant L as GPT-Live
  participant O as Orchestrateur
  participant Ag as Agents A2A
  participant App as App Flutter
  S->>L: « Concentre-toi sur Android et compare avec la 3.3 »
  L-->>O: transcript + delegation.created
  O->>O: révision n+1 du plan (FR-14)
  O->>Ag: tâches filtrées platform=android, versions 3.3/3.4
  Ag-->>O: Artifacts
  O-->>App: updateDataModel / updateComponents sur les surfaceId existants
  Note over App: les surfaces mutent sur place (FR-07, RG-06)
  O->>L: commentary.append (résumé réel)
```

## Acte 3 — Interagir (FR-08)

```mermaid
sequenceDiagram
  actor S as Speaker
  participant App as App Flutter
  participant O as Orchestrateur
  participant Liv as Agent Livraison
  participant L as GPT-Live
  S->>App: clic « Bloquer la release »
  App->>O: action typée {name, surfaceId, context} (app-channel)
  O-->>App: rail : Livraison actif
  O->>Liv: SendMessage(bloquer release 3.4)
  Liv-->>O: résultat réel (statut = bloquée)
  O-->>App: updateDataModel checklist → « Bloquée »
  O->>L: commentary.append (confirmation fondée sur le vrai résultat)
  L-->>S: confirmation vocale
```

La confirmation vocale ne part qu'**après** le résultat réel ([ma-real-tool-results]).

## Interruption (barge-in, FR-13, FR-14, FR-15, FR-19)

```mermaid
sequenceDiagram
  actor S as Speaker
  participant App as App Flutter
  participant L as GPT-Live
  participant O as Orchestrateur
  L-->>S: parole de l'IA
  S->>L: le speaker parle (le modèle full-duplex se tait)
  App->>App: détection locale (niveau piste distante + transcript) → orbe « interrompue » puis « écoute »
  App->>App: réplique IA tronquée à end_ms joué (FR-19)
  L-->>O: input_transcript.delta (nouvelle consigne)
  O->>O: révision n+1, résultats périmés jetés (FR-14)
  Note over App: aucune surface détruite (FR-15)
```

⚠️ GPT-Live n'expose **aucun événement d'interruption** ([rt-barge-in], [rt-gpt-live-lifecycle]) : l'état « Interrompue » de l'orbe doit être **inféré** côté app. Méthode à valider par spike (voir Points ouverts). Mesuré en SP-02 (2026-10-29) : la voix de l'IA continue ~0,6 à 1,0 s après le premier son de l'interruption (horloge du relais, essai automatisé et essai réel ; corrigé le 2026-10-29, Q-67) ; essai réel dans un navigateur (AEC activée, enceintes du PC) : décalage perceptible signalé par le porteur, puis 60 s de parole continue sans auto-interruption ([rt-barge-in], [rt-gpt-live-lifecycle]) ; flutter_webrtc sous Linux et sono de la salle non testés. ⚠️ Hypothèse non confirmée : cette mesure portait sur la copie sideband côté serveur (sortie du modèle), pas sur ce qui sort des haut-parleurs ; le porteur a perçu un décalage entre son interruption et l'arrêt de la voix (2026-10-29), tampon de lecture suspecté mais non vérifié → Q-67 (FR-13, FR-19). Le raccourci « silence » (FR-20) est le secours.

## « Stop » / « annule » (FR-16)

```mermaid
sequenceDiagram
  actor S as Speaker
  participant L as GPT-Live
  participant O as Orchestrateur
  participant Ag as Agents A2A
  participant App as App Flutter
  S->>L: « Stop »
  L-->>O: transcript « stop »
  O->>Ag: CancelTask sur les tâches en vol
  O-->>App: deleteSurface des surfaces inachevées (les complètes restent)
  O->>L: commentary.append (annulation confirmée)
```

Interrompre la parole **n'annule pas** le travail backend : l'orchestrateur annule explicitement, confirme, puis seulement annonce ([rt-gpt-live-delegation]). Le mode de détection de « stop » reste ouvert (Q-42) ; le raccourci « silence » ne coupe que la voix.

## Contrat v1 implémenté (003, 004, 006, 007), validation côté client, remise à vide
- Contrat réellement livré et vérifié en réel les 2026-10-29 et 2026-10-30 : [p-ar-app-channel-contract](app-channel-contract.md) (routes dont `POST /canvas/reset`, enveloppe, types `a2ui` / `agent.activity` / `plan` / `delegation`, surfaces actives, catalogue `genesis`, rétention du hub, politique d'échec, validateur A2UI Go). Ancrage : [pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md), [pdr-0051](../decisions/pdr-0051-orb-level-from-sideband-rms-recommended.md), [pdr-0052](../decisions/pdr-0052-one-gpt-live-session-per-act-recommended.md) ; FR-02, FR-03, FR-04, FR-13, FR-19, NFR-01, NFR-02.
- **Validation côté client (007, [pdr-0053](../decisions/pdr-0053-client-side-a2ui-validation-from-007.md))** : après le décodeur et **avant** le moteur, le client valide **tout** message A2UI, en direct comme en rejeu, avec une instance à état par page (surfaces actives, plafond 6). Codes fermés **communs avec le validateur Go** (`bad_version`, `bad_operation`, `too_large`, `too_deep`, `bad_surface_id`, `bad_catalog`, `bad_component_count`, `duplicate_component_id`, `bad_component`, `component_not_allowed`, `bad_children`, `bad_pointer`, `bad_property`, `surface_exists`, `surface_limit`, `unknown_surface`, `component_cap`), partagés par les fixtures négatives `contracts/a2ui/genesis/v1/invalid/` (parité Go/Dart). Verdicts : `accepted`, `rejected(code)`, `ignored` (`deleteSurface` d'une surface absente : compté, non affiché au panneau). Refus visant une surface active : **compensation locale** (`deleteSurface` local, surface bloquée jusqu'à un nouveau `createSurface`, [pdr-0056](../decisions/pdr-0056-failed-agent-partial-surfaces-removed.md)), sauf `surface_exists`. Non portées côté client : `foreign_surface`, `message_cap`, `incomplete_surface`. Le moteur genui n'est pas une validation : il met en attente 1 min les messages d'une surface absente, accepte un `catalogId` inconnu et n'annule rien sur échec de schéma. Détail : [p-ar-frontend-screen](frontend-screen.md), [p-ar-security](security.md).
- **Remise à vide (FR-11, 007)** : (1) l'app remet à zéro le validateur puis tous ses Blocs (écran vide aussitôt) ; (2) `POST /canvas/reset` ; (3) le backend refuse (409) tant qu'une délégation est en file ou en cours, et l'app réessaie ; sinon il publie un `deleteSurface` par surface active (agent `orchestrateur`, triés) et répond 204 ; (4) ces `deleteSurface` reviennent à l'app, où le validateur les marque `ignored` (surface déjà absente) : le panneau reste vide. Registre par session voix jusqu'à J4 ([pdr-0058](../decisions/pdr-0058-backend-canvas-registry-survives-voice-sessions.md), Q-73).

## Écarts entre sources (laissés ouverts)

Effets techniques des écarts de [p-fn-mockups](../functional/mockups.md) (E1 à E22), sans arbitrage :
- **E3 · Q-03** version A2UI — **tranchée** par [pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md) (décision contrainte) : v0.9 (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`, `"version": "v0.9"`), genui 0.10.4 ([genui-a2ui-messages], [genui-a2ui-overview]). La mention v0.8 de l'illustration est sans portée ([pdr-0017](../decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md)).
- **E1 · Q-01 tranché** ([pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)) : l'orchestrateur sélectionne un sous-ensemble d'agents par demande et le rail montre actifs / en veille ; nombre d'Agent Cards libre, noms métier. **E9 · Q-22** actes vs étapes : marqueurs du journal. **E11 · Q-29 tranché** ([pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)) : N surfaces `s-*`, mises en page par l'app, pas de racine `Grid`. **E2 · Q-02 tranché** ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) : 6 composants ; l'acte 2 procède par mutation des surfaces existantes (`updateComponents` / `updateDataModel`), sans Comparatif de versions ni Timeline. **E22 · Q-64 tranché** ([pdr-0026](../decisions/pdr-0026-desktop-only-target.md)) : desktop seul ([pdr-0002](../decisions/pdr-0002-desktop-platform.md)) ; les ADR hérités orientés web ne changent pas la cible ; effets sur le DS et l'a11y dans [p-ar-frontend](frontend.md).
- **E7 / E8 · Q-20, Q-21** transformation : mutations seules, aucune suppression (Q-21 → pdr-0059, fiche § 4, RG-06) ; la Barre d'actions arrive avec la recommandation NO-GO Android à la fin de l'acte 2 (Q-20 → pdr-0061).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Inférence de l'interruption** pour FR-19 sans événement GPT-Live → Q-40. **Bruits courts** (FR-18, RG-16) : aucun réglage de détection de tour documenté pour GPT-Live ; à mesurer → Q-41. **Détection de « Stop »** : mot-clé sur transcript côté orchestrateur, ou décision du modèle → Q-42. **Agents A2A réels**, processus séparés : tranché ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md), Q-16) ; pas d'agent d'un autre éditeur ([pdr-0035](../decisions/pdr-0035-no-third-party-agent.md), Q-10).
