# 014 — Plan technique

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `packages/features/voice_session` | model / api | `VoiceTransport.setMicEnabled` (port), `RtcPeer.setLocalAudioEnabled` (frontière plateforme), `FlutterWebRtcTransport` ; `VoiceSession.setMicMuted(bool)`, `silenceRemote()`, drapeau `micMuted` dans le statut/flux d'état ; `OrbPhaseBloc` : phase `MicMuted` et événement de silence demandé |
| Flutter | `apps/genesis_canvas/lib/widgets/stage_bar` (+ `top_bar`) | widgets | boutons `silence-button`, `mic-button` (≥ 48 px, `Semantics`, thème de scène) ; budget de la barre du haut (104 px utiles) à revoir |
| Flutter | `apps/genesis_canvas/lib/pages/genesis_canvas` | page (composition) | câblage des boutons et des raccourcis `M` / `Échap` (`Shortcuts` + `Actions`, sans effet hors session) ; coordination silence ↔ phase de l'orbe |
| Flutter | `apps/genesis_canvas/test/acceptance` | tests | S-09, S-07 (côté app), M-01, M-02 |
| Go | `backend/orchestrator/internal/app/voice` | app | `CorrectionDetector` (même mécanique que `StopDetector`, reste de l'énoncé conservé), branchement dans `supervise` ; config `VOICE_CORRECTION_WORDS` |
| Go | `backend/orchestrator/internal/app/orchestrate` | app | `Interrupt` avec `keepFrom` : retire les délégations d'offset `< at_ms`, garde celles `≥ at_ms` ; correction sans `ConsumeUntil` ; `hasStop` non posé |
| Go | `backend/orchestrator/acceptance` | tests (tag `acceptance`) | C-01 à C-04 |
| Compose | `docker-compose.yaml`, `backend/orchestrator/cmd` | config | `VOICE_CORRECTION_WORDS` (défaut : `non,plutôt,en fait`) — fichier partagé : session principale seulement |

## Contrats
- **App-channel** : aucun nouveau message. La correction publie le `voice.interrupted {at_ms}` existant (même sémantique : la voix se tait, orbe « Interrompue »). Faire taire et micro coupé sont **locaux** (aucun message, aucune route) ; `session.input_audio.mute` du sideband n'est pas utilisé (la piste locale désactivée envoie déjà du silence, pdr-0076 D1).
- **Go** : `port.SessionDelegations.Interrupt(atMs)` devient `Interrupt(atMs int64, keepFrom bool)` (ou un second point d'entrée `Supersede(atMs)`, au choix de l'implémentation, à trancher à la revue du plan). Le chemin « Stop » reste inchangé (octet pour octet : K-01 à K-07 doivent rester verts).
- **Détecteurs** : `StopDetector` d'abord ; un énoncé qui contient un mot d'arrêt ne déclenche **pas** la correction (B3). La correction ne se déclenche que si une exécution vocale est en vol ou en file (`session.Busy()`, lu sous `session.mu`, jamais sous `Canvas.mu`).
- **Dart** : états et events `sealed` (Bloc, pas de Cubit). Le silence demandé est un event de `OrbPhaseBloc` ; le micro coupé un champ d'état de la session ; aucune lecture de `getIt` dans un widget ou un Bloc.
- **Configuration** : liste des mots de correction par variable d'environnement (au plus 16 mots, 32 runes, aucun vide ; liste vide = détection coupée) ; jamais codée en dur.

## Références
- `product/architecture/voice-interruption.md` (chaîne « Stop », époque, compensation, fenêtre de demande), `frontend-screen.md` § 011, `stage-runtime.md`, `screen.md` (états de l'orbe, raccourcis).
- Notes `knowledge/` : [rt-barge-in], [rt-gpt-live-delegation], [rt-gpt-live-sideband] (`session.input_audio.mute` existe côté serveur, non retenu), [rt-flutter-webrtc-audio-routing], [rt-echo-cancellation].

## Risques
- **Perte de la correction à l'`Interrupt`** (la file est vidée) → `keepFrom` et C-04 ; test d'ordre sous `-race`.
- **Régression de Q-74 / RD-10** (« Concentre-toi sur Android » puis « et compare avec la 3.3 » en deux délégations) : « et » n'est pas un mot de correction et la correction ne se déclenche que sur le premier mot significatif ; test de non-régression (la seconde moitié n'annule pas la première).
- **Faux positif** : « non » dans une phrase ordinaire (« non seulement… ») → la correction exige qu'une exécution soit en vol ou en file ; en dehors, rien ne se passe. Nécessairement un risque résiduel en vol, accepté (liste configurable, vidable).
- **`track.enabled=false` du micro sous `flutter_webrtc` Linux non prouvé** (même famille que Q-79) → test avec faux `RtcPeer` seulement ; à écouter en répétition (ajouté à Q-79).
- **Barre du haut** : deux boutons de plus dans 104 px utiles → capture `app-smoke` 1920×1080 dans les critères.
- **Hypothèse fournisseur** (délégation pour la correction en vol) → Q-87 ; le code ne dépend d'aucune hypothèse non testée pour rester correct (sans délégation, la correction annule et se tait seulement).
