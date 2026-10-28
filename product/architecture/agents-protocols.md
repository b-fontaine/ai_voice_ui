---
id: p-ar-agents-protocols
title: Agents, protocoles et séquences des actes
area: architecture
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p5, product/sources/design-example.pdf, knowledge:proto-protocol-map, knowledge:rt-gpt-live-delegation, knowledge:rt-barge-in, knowledge:genui-a2ui-messages, knowledge:genui-a2a-connector]
links: [proto-a2a-bindings, proto-a2a-dart-sdk, ma-backend-sdk-go, p-ar-overview, p-ar-backend, p-ar-frontend, p-ar-replay, p-fn-requirements, p-fn-mockups, p-fn-catalog, p-fn-personas-journey, p-rm-open-questions, p-rm-spikes, pdr-0004-mvp-three-acts, pdr-0012-voice-provider-openai, proto-protocol-map, proto-a2a-overview, proto-a2a-task-lifecycle, proto-a2a-streaming-push, rt-gpt-live-webrtc-session, rt-gpt-live-sideband, rt-gpt-live-delegation, rt-gpt-live-lifecycle, rt-barge-in, rt-transcription, genui-a2ui-messages, genui-a2ui-overview, genui-a2ui-transports, genui-user-actions, genui-a2a-connector, ma-real-tool-results, ma-filler-acknowledgements, ma-backend-stack-recommendation, ma-target-architecture, rt-ephemeral-keys, pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout]
tags: [protocoles, a2a, a2ui, webrtc, sideband, sequence, barge-in, actes]
---
# Agents, protocoles et séquences des actes

**En bref.** La voix circule en WebRTC entre l'app et GPT-Live ; le backend écoute la même session en sideband et reçoit la délégation ; il délègue aux agents en A2A ; l'UI revient à l'app en messages A2UI sur un canal séparé (proposé : WSS maison ; alternative `genui_a2a`, ouvert → Q-39), et les clics repartent par le même canal. Ce document donne les séquences des 3 actes ([pdr-0004](../decisions/pdr-0004-mvp-three-acts.md)), de l'interruption et de « Stop ».

> Statut : **draft**. Les séquences sont la proposition de l'assistant, construites sur les faits de la base `knowledge/`. Elles supposent des choix encore ouverts : version A2UI (Q-03), producteur de l'A2UI (Q-37), canal app ↔ backend (Q-39).

## Qui parle à qui, avec quoi

| De → vers | Protocole | Contenu | Source |
|---|---|---|---|
| App ↔ GPT-Live | **WebRTC** (média + DataChannel `oai-events`) | voix du speaker, voix de l'IA | [rt-gpt-live-webrtc-session] |
| App → backend | **HTTPS** `POST /voice/sessions` | offre SDP → answer SDP | [rt-ephemeral-keys] |
| Backend ↔ GPT-Live | **REST** + **sideband WSS** `/live/sessions/{id}/attach` | transcripts, `delegation.created`, `commentary/thinking.append`, `close` | [rt-gpt-live-sideband] |
| Orchestrateur ↔ agents | **A2A v1.0** (JSON-RPC + SSE) | tâches, statut, Artifacts | [proto-a2a-task-lifecycle], [proto-a2a-streaming-push] |
| Backend → app | **WSS app-channel** | messages **A2UI** (v0.9 si genui 0.10, Q-03), activité des agents, transcript, état orbe | [ma-backend-stack-recommendation] |
| App → backend | **WSS app-channel** | actions utilisateur typées (`UiInteractionPart`) | [genui-user-actions] |

Règles : l'A2UI ne passe **jamais** par le canal de la session voix ([genui-a2ui-transports]) ; le JSON A2UI n'est jamais lu à voix haute ([ma-target-architecture]). Alternative au canal maison : `genui_a2a` (A2A + SSE) si l'orchestrateur s'expose lui-même en A2A ([genui-a2a-connector]). ⚠️ Risque d'incompatibilité sur le fil : `genui_a2a` appelle `message/stream` (nommage A2A v0.3) alors qu'a2a-go v2 implémente la v1.0 (`SendStreamingMessage`, PascalCase), compat v0.3 via `a2acompat` ([proto-a2a-bindings], [proto-a2a-dart-sdk], [ma-backend-sdk-go]) ; à vérifier en SP-03 ; voir Points ouverts (Q-39).

## Acte 1 — Créer (FR-01 à FR-06)

```mermaid
sequenceDiagram
  actor S as Speaker
  participant App as App Flutter
  participant L as GPT-Live
  participant O as Orchestrateur
  participant Ag as Agents A2A
  S->>L: « Prépare la release 3.4 » (WebRTC)
  L-->>O: input_transcript.delta (sideband)
  O-->>App: transcript (app-channel) → barre supérieure (FR-02)
  L-->>O: session.delegation.created
  O->>O: plan : N tâches (E1)
  O-->>App: activité agents → rail (FR-03)
  O-->>App: createSurface + composants squelette (FR-04, NFR-02 < 1,5 s)
  O->>L: commentary.append « je lance l'analyse… » (NFR-01, RG-04)
  par en parallèle
    O->>Ag: SendStreamingMessage (Qualité)
    O->>Ag: SendStreamingMessage (Voix du client)
    O->>Ag: SendStreamingMessage (Livraison)
  end
  Ag-->>O: Artifacts (données figées)
  O->>O: A2UI validé contre le catalogue
  O-->>App: updateComponents puis updateDataModel (FR-04, FR-05, FR-06)
  O->>L: commentary.append (vrai résumé)
  Note over App: 4 surfaces complètes < 8 s (NFR-03)
```

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
  Note over O,App: ⚠️ retrait ou ajout de surface : écart E8, ouvert (Q-21)
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
  S->>L: le speaker parle
  L->>L: le modèle full-duplex se tait
  App->>App: détection locale (niveau piste distante + transcript) → orbe « interrompue » puis « écoute »
  App->>App: réplique IA tronquée à end_ms joué (FR-19)
  L-->>O: input_transcript.delta (nouvelle consigne)
  O->>O: révision n+1, résultats périmés jetés (FR-14)
  Note over App: aucune surface détruite (FR-15)
```

⚠️ GPT-Live n'expose **aucun événement d'interruption** ([rt-barge-in], [rt-gpt-live-lifecycle]) : l'état « Interrompue » de l'orbe doit être **inféré** côté app. Méthode à valider par spike (voir Points ouverts). Le raccourci « silence » (FR-20) est le secours.

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
  O-->>App: deleteSurface des surfaces inachevées
  Note over App: surfaces complètes conservées
  O->>L: commentary.append (annulation confirmée)
```

Interrompre la parole **n'annule pas** le travail backend : l'orchestrateur annule explicitement, confirme, puis seulement annonce ([rt-gpt-live-delegation]). Le mode de détection de « stop » reste ouvert (Q-42) ; le raccourci « silence » ne coupe que la voix.

## Écarts entre sources (laissés ouverts)

Effets techniques des écarts de [p-fn-mockups](../functional/mockups.md) (E1 à E22), sans arbitrage :
- **E3 · Q-03** version A2UI : maquettes en v0.8 (`beginRendering`, `surfaceUpdate`, `dataModelUpdate`) ; genui 0.10.x parle v0.9 (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`) ([genui-a2ui-messages], [genui-a2ui-overview]). Les noms de messages de cette page sont ceux de v0.9, sous réserve de Q-03.
- **E1 · Q-01 tranché** ([pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)) : l'orchestrateur sélectionne un sous-ensemble d'agents par demande et le rail montre actifs / en veille ; nombre d'Agent Cards libre, noms métier. **E9 · Q-22** actes vs étapes : marqueurs du journal. **E11 · Q-29 tranché** ([pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)) : N surfaces `s-*`, mises en page par l'app, pas de racine `Grid`. **E2 · Q-02 tranché** ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) : 6 composants ; l'acte 2 procède par mutation des surfaces existantes (`updateComponents` / `updateDataModel`), sans Comparatif de versions ni Timeline. **E22 · Q-64** plateformes : desktop seul ([pdr-0002](../decisions/pdr-0002-desktop-platform.md)) contre « web, mobile et desktop » des ADR hérités ; effets sur le DS, l'a11y et le chargement web dans [p-ar-frontend](frontend.md).
- **E7 / E8 · Q-20, Q-21** transformation : si Q-21 autorise la suppression, l'acte 2 émettrait `deleteSurface` / `createSurface` en plus des mutations ; sinon, mutations seules (fiche § 4, RG-06).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Canal app ↔ backend** : WSS maison ou `genui_a2a` (A2A + SSE, risque v0.3 / v1.0 ci-dessus) ; le panneau protocole (FR-05) exige l'accès aux messages bruts → Q-39.
- **Inférence de l'interruption** pour FR-19 sans événement GPT-Live → Q-40. **Bruits courts** (FR-18, RG-16) : aucun réglage de détection de tour documenté pour GPT-Live ; à mesurer → Q-41.
- **Détection de « Stop »** : mot-clé sur transcript côté orchestrateur, ou décision du modèle → Q-42. **Agents A2A réels** (processus séparés) ou simulés in-process pour la scène ; agent d'un autre éditeur (E6) → Q-16, Q-01, Q-10.
