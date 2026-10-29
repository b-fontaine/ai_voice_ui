# 005 — App Flutter : session voix, orbe, rendu A2UI du flux vivant, activité des agents

> **En bref.** Le speaker clique « Démarrer » : l'app ouvre la session GPT-Live par le relais SDP du backend (aucune clé dans l'app), l'orbe suit la voix de l'IA (`orb.level`), la phrase et la réponse s'affichent, et la surface produite par l'agent Qualité apparaît sur le canevas, l'agent s'allumant dans un panneau d'activité. Troisième et dernière fonctionnalité de J2 (003 backend, 004 orchestrateur + agent + surface, 005 app).

- **Jalon** : J2 « Walking skeleton » (`product/roadmap/roadmap.md`), backlog EP-01 (socle app), EP-02 (voix).
- **Exigences visées** : FR-01 (canevas vide, orbe animé), FR-02 (transcription en direct, partiel : sans troncature), FR-03 (agent allumé avec sa tâche, panneau minimal), FR-04 (une surface en 3 temps, rendu du flux vivant), NFR-04 (orbe à 60 i/s sans rebuild global), NFR-09 (aucune clé dans l'app), NFR-10 (versions figées), instrumentation de NFR-01/NFR-02 par l'horloge de l'app (pdr-0038) ; RG-01, RG-02, RG-04 (côté affichage).
- **Décisions applicables** : adr-0001, pdr-0012, pdr-0018 (A2UI v0.9, genui 0.10.4), pdr-0026, pdr-0028 (Linux), pdr-0038, pdr-0044 (get_it + injectable introduits ici), pdr-0045 (WSS maison), pdr-0046 (Flutter 3.47.8), pdr-0051 (orbe = RMS sideband à 5 Hz, interpolé), pdr-0052.
- **Hors périmètre** : catalogue fermé `genesis` et thème de scène (J3 : le catalogue de base de genui reste en J2, `A2UI_CATALOG_ID` = catalogue « basic »), rail complet et panneau protocole (J3), étagère, remise à vide, états d'orbe « Écoute », « Interrompue », « Micro coupé » (J7 : le backend ne fournit que le niveau de la voix de l'IA), troncature de la réplique coupée (FR-19, J7), barge-in, « stop » et AEC mesurée sur enceinte (J7, SP-06), actions utilisateur vers un agent (J5), rejeu enregistré (J6), reconnexion automatique du WSS (le backend rejoue le backlog à la connexion : une reconnexion manuelle suffit en J2).

## Comportement attendu
- **Démarrage** : écran avec orbe au repos (pulsation lente) et un bouton « Démarrer » ; canevas vide (FR-01, RG-01). La configuration (URL du backend) vient de l'environnement ; l'app ne lit **aucune** clé.
- **Session** : « Démarrer » ouvre le WSS `GET /app`, crée l'offre WebRTC (micro unique, `getUserMedia`, data channel `oai-events` avant l'offre, collecte ICE complète), l'envoie à `POST /voice/sessions`, applique l'answer et mémorise `X-Session-Id`. « Arrêter » appelle `DELETE /voice/sessions/{id}`, puis libère pistes, data channel et connexion dans l'ordre ([rt-graceful-close]) ; la session est ensuite **redémarrable** (`stop` ≠ `dispose`).
- **Orbe** : `orb.level` (5 Hz) alimente un `ValueListenable` ; un `Ticker` interpole à la cadence de l'écran ; aucun état Bloc ne porte le niveau (NFR-04). États J2 : repos (pulsation lente), parole (niveau au-dessus d'un seuil), réflexion (au moins un agent `working`).
- **Transcription** : deux lignes (speaker, IA) dans la barre du haut, mises à jour par les `transcript` (FR-02).
- **Canevas** : chaque `a2ui` de l'app-channel est décodé (A2UI v0.9) et appliqué par le `CanvasBloc` existant ; trois temps visibles (FR-04). Un message illisible est ignoré et consigné, jamais fatal.
- **Panneau d'activité** : liste des agents vus avec leur état (`working`, `completed`, `failed`) et leur `label` (FR-03).
- **Erreurs** : backend injoignable, 429, 502, WSS perdu → message d'état honnête dans la barre du haut, orbe au repos, canevas conservé, app vivante ; « Démarrer » reste utilisable.
- **Journal horodaté de l'app** : chaque `SessionEvent` reçu est horodaté à l'horloge de l'app (pdr-0038) et écrit en JSONL local si `GENESIS_APP_LOG` est fourni (base de NFR-01/02 et du rejeu).

## Scénarios (Gherkin)
Automatisés dans `apps/genesis_canvas/test/acceptance/` (bdd_widget_test). Frontières simulées : serveur de test **réseau local** (`dart:io` HTTP + WebSocket, enveloppes issues du journal réel de 004) et `VoiceTransport` (WebRTC) factice. Le scénario S-01 de la fiche (`product/functional/features/voice-screen-generation.feature`) est couvert dans sa version J2 par V1.
- V1 — une phrase → une surface : session active, le serveur de test émet `transcript`, `delegation`, `agent.activity working`, trois `a2ui`, `agent.activity completed` ; l'app affiche la phrase, la surface « 99,57 % » en trois temps et l'agent Qualité terminé.
- V2 — l'orbe suit la voix : `orb.level` à 0,8 puis 0 ; le niveau lissé monte puis redescend, et l'orbe retourne au repos.
- V3 — démarrer, arrêter, redémarrer : l'offre part vers le relais, l'answer est appliquée ; « Arrêter » envoie `DELETE`, libère le transport ; un second « Démarrer » ouvre une nouvelle session.
- V4 — backend injoignable (et 429) : message honnête, orbe au repos, aucun plantage, nouvel essai possible.
- V5 — WSS perdu en pleine session : message « connexion perdue », surfaces conservées.
- V6 — aucune clé : la configuration ne lit que l'URL du backend (test unitaire de `GenesisConfig`, et revue de code NFR-09).

## Critères d'acceptation
- [ ] V1 à V5 automatisés et verts ; V6 en test unitaire
- [ ] Tests unitaires de chaque unité (entités de session, décodeur d'enveloppes, client WSS, relais SDP, `VoiceSessionBloc`, transcription, activité des agents, orbe)
- [ ] `tools/loop/gate.sh --full` vert (Flutter et Go inchangés côté Go)
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Aucun `getIt` dans un widget ni un Bloc (contrôle par `grep` dans la revue) ; versions de `flutter_webrtc`, `get_it`, `injectable`, `web_socket_channel`, `http` figées dans `pubspec.lock`
- [ ] Vérification : capture `app-smoke.sh` (canevas vide + orbe + bouton), puis, si un micro et une sortie audio existent sur la machine de la boucle et que le budget le permet, **un essai réel unique** avec `docker compose up` (délai `delegation` → premier `a2ui` lu dans le journal de l'app) ; sinon indisponibilité notée et essai laissé à la répétition avec le porteur (SP-06)

## Questions ouvertes
Aucune bloquante. À signaler au porteur sans bloquer : Q-69 et Q-70 (déjà ouvertes) concernent le comportement de l'app quand une surface partielle disparaît (`deleteSurface` de compensation, géré par le `CanvasBloc`) et la survie du canevas entre sessions voix ; en J2 l'app **conserve** le canevas à l'arrêt de la session.
⚠️ Hypothèse non confirmée : démarrage par un bouton (geste explicite, nécessaire aux autorisations micro sur certaines plateformes) plutôt qu'automatique ; le raccourci clavier éventuel relève de pdr-0033 (facultatif).
