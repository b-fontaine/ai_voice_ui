# 011 — Plan technique

Deux piles : **Go** (`backend/orchestrator`, `backend/agents`) et **Flutter** (`packages/`, `apps/genesis_canvas`). Contrat app-channel : un seul type de message ajouté, `voice.interrupted`. Contrat `genesis/v1` inchangé.

## Où
| Pile | Module | Fichiers |
|---|---|---|
| Go | `orchestrate/window.go`, `manager.go` | marge (`REQUEST_WINDOW_MARGIN`) et attente des deltas tardifs (`REQUEST_WINDOW_SETTLE`) avant `Take` |
| Go | `orchestrate/canvas.go`, `pipeline.go` | `Canvas.Focus()` (dernière intention réussie par canevas : plateforme, vue), poussée dans `AgentRequest.Metadata["genesis/focus"]` |
| Go | `agents/internal/kit/scope.go`, `executor.go` | lit `genesis/focus` : une comparaison sans plateforme hérite de la plateforme ; sinon `compare_without_platform` |
| Go | `orchestrate/pipeline.go` | journal du motif de refus (`scope_reason`) |
| Go | `orchestrate/manager.go`, `canvas.go` | `Manager.CancelInFlight(session)` : annule sans fermer la session ; compensation `deleteSurface` des surfaces inachevées ; les complètes restent |
| Go | `app/voice/stopword.go` (nouveau), `service.go` | `StopDetector` (texte normalisé, fenêtre glissante, mots entiers, liste `VOICE_STOP_WORDS`) appelé sur `EventInputTranscriptDelta` ; publie `voice.interrupted {at_ms}` |
| Go | `config/voice-instructions.fr.md` | consignes : se taire si le speaker parle, attendre la fin de phrase, commentaire final court |
| Go | `orchestrate/action*.go` | idempotence : une action dont l'effet est en place répond 200/202 sans nouvelle annonce |
| Flutter | `entities/session`, `shared/backend_channel` | événement `VoiceInterrupted(atMs)` décodé de `voice.interrupted` |
| Flutter | `features/voice_session` | `VoiceInterrupted` → orbe « Interrompue » puis « Écoute » ; port `RemoteAudioMute` (piste distante `enabled = false`, réactivée à la sortie suivante) ; troncature de la dernière réplique `ai` |
| Flutter | `features/stage_controls` | `StageActReached(act)` monotone (`max`) ; `StageActAdvanced` manuel inchangé ; remise à vide → 1 |
| Flutter | `apps/genesis_canvas` | la page coordonne (apparition de la surface `actions`, `ActionRunning`) ; inactif en rejeu |
| Flutter | `features/canvas` | `ReleaseChecklist` : `decisionStatus` en pastille visible sans troncature ; `ActionBar` : états « en cours » et « fait » |

## Contrats
- **`voice.interrupted`** : `{at_ms}` (temps du fournisseur, ms) ; publié par session ; absent du backlog de rejeu au-delà de la rétention actuelle ; jamais journal A2UI (non A2UI).
- **`genesis/focus`** (métadonnée A2A) : objet `{platform?: "android"|"ios", view?: …}` ; liste fermée ; absent si aucun focus. Les agents restent sans état.
- **Détecteur** : normalisation (minuscules, accents conservés, ponctuation retirée), correspondance sur **mots entiers**, fenêtre de 6 mots sur les deltas d'un même tour ; au plus une détection par rafale (anti-rebond `VOICE_STOP_DEBOUNCE`).
- **`CancelInFlight`** : annule les délégations de la session sans `ErrSessionClosed` ; `agent.activity` terminal pour chaque agent du plan (`failed`/« annulé » n'existant pas : réutilise `canceled`, réservé au contrat, désormais émis) ; surfaces inachevées = celles du registre sans `updateComponents` complet, retirées par `deleteSurface`.
- **Configuration** (jamais codé en dur) : `VOICE_STOP_WORDS`, `VOICE_STOP_DEBOUNCE`, `REQUEST_WINDOW_MARGIN` (400 ms), `REQUEST_WINDOW_SETTLE` (300 ms).

## Références
`knowledge/` : [rt-barge-in], [rt-gpt-live-sideband], [rt-gpt-live-delegation], [proto-a2a-task-lifecycle], [genui-a2ui-messages], [arch-bloc-no-cubit], [test-mock-boundaries-only]. `product/` : FR-13 à FR-16, FR-19, FR-08, RG-11 à RG-17, `barge-in.feature`, [p-ar-app-channel-contract], [p-ar-stage-runtime].

## Risques
- GPT-Live ne tait pas sa voix sur demande : la coupure locale (piste distante) est le seul mécanisme sûr ; `flutter_webrtc` Linux non testé → vérification en répétition.
- Faux positif du mot-clé (« stop » dans une phrase) : mots entiers + anti-rebond ; réexamen prévu par pdr-0069.
- `canceled` change le contrat (`agent.activity`) : le rail doit le rendre (déjà prévu « Interrompu »).
- Annulation et plan en parallèle : `CancelInFlight` sous le verrou du canevas ; test de course.
