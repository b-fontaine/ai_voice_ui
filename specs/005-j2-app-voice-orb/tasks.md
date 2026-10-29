# 005 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Toutes les tâches sont Flutter : une seule à la fois.

## Gherkin (acceptation Flutter, bdd_widget_test)
- [ ] T01 Flutter — figer les versions (`flutter_webrtc` 1.6.3, `get_it` 9.3.0, `injectable` 3.0.0, `injectable_generator` 3.1.3, `web_socket_channel`, `http`) et créer les 4 paquets vides au workspace ; `flutter pub get` et `gate.sh --unit flutter` verts · test d'abord : `gate.sh --unit flutter` échoue tant qu'un paquet manque
- [ ] T02 Flutter — `session_voice.feature` : V1 à V5 avec serveur de test local (HTTP + WebSocket) et `VoiceTransport` factice, étapes dans `test/acceptance/step/` · test d'abord : rouge attendu, symboles absents (`VoiceSessionBloc`, `AppChannelClient`, …)

## TDD
- [ ] T10 Flutter — `entities/session` : `SessionEvent`, ports `SessionEventSource`, `VoiceRelay`, `AppClock` · test d'abord : égalités et exhaustivité du `switch` sealed
- [ ] T11 Flutter — `shared/core` : `A2uiDecoder` extrait du rejeu, le rejeu l'utilise · test d'abord : `A2uiDecoderTest` (v0.9 valide, version erronée, corps invalide), tests du rejeu inchangés
- [ ] T12 Flutter — `backend_channel` : `EnvelopeDecoder` · test d'abord : table (un cas par type du contrat, type inconnu ignoré, enveloppe illisible, `agent`/`task`, `a2ui` brut)
- [ ] T13 Flutter — `backend_channel` : `AppChannelClient` (WSS, flux d'événements, fermeture, erreur de connexion) · test d'abord : serveur WebSocket local, connexion, 3 messages, coupure, annulation
- [ ] T14 Flutter — `backend_channel` : `HttpVoiceRelay` (200 avec `X-Session-Id`, 400/413/415/429/502/504, délai, `DELETE` 204/404) · test d'abord : serveur HTTP local
- [ ] T15 Flutter — `backend_channel` : `SessionEventLog` (JSONL, horloge de l'app, fichier absent = inactif) · test d'abord : horloge factice
- [ ] T16 Flutter — `voice_session` : `VoiceSession` (démarrer, arrêter, redémarrer, ordre de fermeture, erreurs de transport et de relais) · test d'abord : transport et relais factices, ordre des appels
- [ ] T17 Flutter — `voice_session` : `VoiceSessionBloc` et `TranscriptBloc` · test d'abord : séquences d'événements, transformers (redémarrage annule la souscription précédente)
- [ ] T18 Flutter — `voice_session` : `OrbLevelController` (lissage, retombée, arrêt du ticker) · test d'abord : `fakeAsync`/ticker de test
- [ ] T19 Flutter — `voice_session` : `FlutterWebRtcTransport` (adaptateur mince, frontière) · test d'abord : test de forme avec `flutter_webrtc` simulé par une façade injectable (contraintes micro, canal avant l'offre, attente ICE bornée, fermeture dans l'ordre)
- [ ] T20 Flutter — `agent_activity` : `AgentActivityBloc` · test d'abord : `working` → `completed`, `failed` avec `detail`, deux agents
- [ ] T21 Flutter — `app/di` : modules injectable, environnements `live`/`test`, `GenesisConfig` étendu (URL, journal, aucune clé) · test d'abord : résolution complète en `test`, `GenesisConfigTest` (V6)
- [ ] T22 Flutter — widgets `top_bar` (orbe peint, transcription, bouton, message d'état) et `agents_rail` · test d'abord : widget tests (repos, parole, réflexion, échec)
- [ ] T23 Flutter — page `genesis_canvas` : câblage source → Blocs, fermeture ordonnée au `dispose` · test d'abord : test de page avec source factice (surface appliquée, `dispose` appelle `stop`)

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer (mode CODE) + refactorisations (par lots)
- [ ] T92 Vérification : capture `app-smoke.sh`, essai réel unique si matériel et budget (`openai-budget.sh`), clôture, fusion, `publish.sh`, `fresh_session`
