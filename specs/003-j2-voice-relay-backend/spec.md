# 003 — Backend squelette : relais SDP, sideband, app-channel

> **En bref.** Un backend Go local ouvre une session GPT-Live à partir d'une offre SDP sans qu'aucune clé n'atteigne le client, suit la session par le sideband, calcule le niveau de la voix de l'IA et le pousse, avec les transcripts, sur un canal WSS vers l'app. `docker compose up` le démarre. Première des trois fonctionnalités de J2 (003 backend, 004 orchestrateur + agent A2A + surface, 005 app voix + orbe).

- **Jalon** : J2 « Walking skeleton » (`product/roadmap/roadmap.md`), backlog EP-01 et EP-02.
- **Exigences visées** : NFR-09 (aucune clé côté client), NFR-10 (versions figées), NFR-11 (coût plafonné), FR-02 (transcription, partie backend), instrumentation NFR-01 (journal horodaté) ; RG-26.
- **Décisions applicables** : adr-0003-backend-go, pdr-0012, pdr-0029, pdr-0041, pdr-0045 (WSS maison), pdr-0047 (Go 1.27.3), pdr-0048 (journal seul), pdr-0050 (délégation `client`, configurable), pdr-0051 (RMS à 5 Hz), pdr-0052 (une session par acte), pdr-0038 (latence sur l'horloge de l'app).
- **Hors périmètre** : orchestrateur et agents A2A (004) ; app Flutter, WebRTC côté client, orbe (005) ; réponse à `delegation.created` (004) ; barge-in et Q-67 (J7) ; authentification (aucune, pdr-0041).

## Scénarios (Gherkin)
Aucun scénario de la fiche ne porte sur ce seul maillon (pdr-0049 : pas de Gherkin hors fiche). Les contrats sont couverts par des tests d'acceptation Go (build tag `acceptance`), avec un fournisseur Live simulé :
- A1 — `POST /voice/sessions` : offre SDP → answer SDP ; ni la réponse, ni le journal, ni les messages du canal ne contiennent la clé (NFR-09).
- A2 — `GET /app` (WSS) : l'app reçoit `orb.level` à ~5 Hz (valeurs 0..1) et les transcripts de la session.
- A3 — `listen.host` refuse toute adresse autre que loopback sans option explicite ; modèle, voix et type de délégation viennent de la configuration.

## Critères d'acceptation
- [ ] A1 à A3 automatisés et verts
- [ ] Tests unitaires de chaque unité (config, session, RMS, supervisor, hub, journal)
- [ ] `tools/loop/gate.sh --full` vert (Go compris)
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Essai réel unique (budget vérifié) avec le client pion du spike : session ouverte via le backend, `orb.level` et transcripts reçus sur le WSS ; `docker compose config` valide
- [ ] Journal JSONL horodaté (horloge monotone + unix_ms) pour chaque message émis sur le canal

## Questions ouvertes
Aucune bloquante. Format exact des messages de l'app-channel : conception de l'assistant (versionné `v: 1`), à consolider avec 004/005.
