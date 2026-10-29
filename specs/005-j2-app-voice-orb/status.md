# 005 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/005-j2-app-voice-orb
- **Backlog** : EP-01, EP-02
- **Mis à jour** : 2026-10-29 23:48

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | TDD | T17 faite : convertisseur enveloppe → `SessionEvent` (4 raisons d'ignorance fermées), `LiveSessionEventSource` (broadcast sans erreur, `closed` sans doublon, `ChannelLost`), `VoiceSessionBloc` mince (`restartable`/`droppable`), `TranscriptBloc` (concaténation, alternance de rôle, vidage à la nouvelle session) ; rouge cité (symboles absents), 51 tests verts | `.omc/state/loop/gates/20261029-234446-unit-flutter.log` (VERT, 28 contrôles) |
| 2026-10-29 | TDD | T16 faite : `VoiceSession` (machine à états `Idle/Connecting/Active/Stopping/Failed`, compteur de génération, un transport neuf par démarrage, `DELETE` avant libération, `VoiceFailure` fermé, `VoiceTransport` port) ; rouge cité (symboles absents), 25 tests verts aux Completer ; acceptation V1-V5 : plus d'erreur sur `VoiceTransport`, reste `voiceTransportFactory` et `VoiceOrb.level` | `.omc/state/loop/gates/20261029-233848-unit-flutter.log` (VERT, 28 contrôles) |
| 2026-10-29 | TDD | T15 faite : `EnvelopeLog` (JSONL sans `v` + `unix_ms` de l'horloge de l'app injectée en fonction, inactif sans chemin, erreur d'E/S = `onError` une fois puis désactivé) ; rouge cité (`EnvelopeLog` absent), 9 tests verts | `.omc/state/loop/gates/20261029-233156-unit-flutter.log` (VERT, 27 contrôles) |
| 2026-10-29 | TDD | T14 faite : `VoiceRelay` + `HttpVoiceRelay` (POST SDP, DELETE borné 7 s, `RelayFailure` à nature fermée, `Retry-After` borné, réponse limitée à 128 Kio) ; faux backend étendu (415, sans `X-Session-Id`, answer trop grande, `postDelay`, `Retry-After` brut) ; rouge cité (`HttpVoiceRelay`/`RelayFailureKind` absents), 20 tests verts ; à surveiller en revue : erreurs de lecture hors Socket/Client/Handshake non traduites | `.omc/state/loop/gates/20261029-232503-unit-flutter.log` (VERT) |
| 2026-10-29 | TDD | T13 faite : faux backend et fixture déplacés dans `testing/backend_fakes` (fixture par URI de paquet), `AppChannel` + `WebSocketAppChannel` (`?session=`, sans `Origin`, fin sans erreur à la fermeture serveur, `AppChannelFailure` à nature fermée) ; rouge cité (symboles absents), 17 tests verts ; acceptation V1-V5 toujours rouge pour les 4 mêmes symboles de production absents | `.omc/state/loop/gates/20261029-231923-unit-flutter.log` (VERT, 27 contrôles) |
| 2026-10-29 | TDD | T12 faite : `AppChannelEnvelope` (DTO + parse, erreurs fermées sans contenu brut, constantes `AppChannelTypes`) ; rouge cité (symboles absents), 27 tests verts | `.omc/state/loop/gates/20261029-231309-unit-flutter.log` (VERT, 24 contrôles) |
| 2026-10-29 | TDD | T11 faite : `A2uiDecoder` (extrait du rejeu, tests du rejeu inchangés) et `AppClock`/`SystemClock` ; rouge cité (`Type 'AppClock' not found`), vert | `.omc/state/loop/gates/20261029-231025-unit-flutter.log` (VERT, 23 contrôles) |
| 2026-10-29 | TDD | T10 faite : `SessionEvent` sealed (8 variantes), port `SessionEventSource`, test de dépendances de `backend_channel` ; rouge cité (symboles absents), 11 tests verts ; `test` 1.31.1 ajouté en dev (1.33.0 incompatible avec `flutter_test`) | `.omc/state/loop/gates/20261029-230743-unit-flutter.log` (VERT, 23 contrôles) |
| 2026-10-29 | Gherkin | T02 faite : `session_voice.feature` (12 scénarios V1-V5bis), faux backend HTTP+WebSocket réel, faux `VoiceTransport`, `pumpUntil`, 49 pas. Rouge attendu cité : `flutter test test/acceptance/session_voice_test.dart` → 4 erreurs de compilation, toutes symboles de production absents (`VoiceTransport` ×2, paramètre `voiceTransportFactory`, getter `VoiceOrb.level`) ; `loop_harness` reste vert (3 tests) | `.omc/state/loop/gates/20261029-230040-unit-flutter.log` (VERT, 22 contrôles) |
| 2026-10-29 | Gherkin | T01 faite : 4 paquets, versions exactes, DI injectable ; 1re tentative bloquée (`injectable_generator` 3.1.3 incompatible avec `build_runner` 2.16.2 / `analyzer` 14.6.0), levée par `build_runner` 2.16.1 (vérifié en copie isolée du workspace, choix contraint) ; smoke test rouge puis vert | `.omc/state/loop/gates/20261029-224730-unit-flutter.log` (VERT, 22 contrôles) |
| 2026-10-29 | Revue du plan | verdict À AMENDER (2 bloquants), A1-A8 intégrés dans spec/plan/tâches | — |
| 2026-10-29 | Définir | spec, plan, tâches rédigés (lookup product + kb faits) ; aucune Q-xx bloquante | — |

## Revue d'architecte
**Revue du plan (mode PLAN, 2026-10-29) : À AMENDER, 2 bloquants — amendements A1-A8 intégrés dans `plan.md`, `tasks.md`, `spec.md`.**
- [x] A1 bloquant — `shared` ne dépend pas d'`entities` : DTO et ports propres à `backend_channel`, `AppClock`/`A2uiDecoder` dans `shared/core`, conversion en `SessionEvent` dans `voice_session/api`
- [x] A2 bloquant — `VoiceSession` machine à états unique, Blocs minces `droppable`, fabrique de transport
- [x] A3 important — source vivante à durée de vie de la page, broadcast sans erreur, `ChannelLost`
- [x] A4 important — WSS ouvert après le 200 avec `?session=`
- [x] A5 important — `VoiceFailure` fermé, `closed` backend, WSS perdu, délai du `DELETE`
- [x] A6 important — pas de scope get_it en J2, ordre de fermeture, `onExitRequested`, modules DI dans `app/di`
- [x] A7 important — `OrbSmoother` pur, contrôleur UI, retombée, preuve NFR-04
- [x] A8 important — transcription, sockets réels dans `testWidgets`, graphe `live` seul, versions figées (T01)

## Questions pour le porteur
<!-- Q-xx créées : ce qui est bloqué, ce qui continue. -->
