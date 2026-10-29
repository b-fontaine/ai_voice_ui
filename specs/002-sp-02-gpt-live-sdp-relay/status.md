# 002 — État

- **Étape** : Expérimenter (spike : Définir → Expérimenter → Consigner → Clôture)
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/002-sp-02-gpt-live-sdp-relay
- **Backlog** : EP-02 (spike SP-02)
- **Mis à jour** : 2026-10-29 16:50

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | Définir | spec, plan et tâches du spike rédigés (kb-lookup : [rt-gpt-live-overview], [rt-gpt-live-webrtc-session], [rt-gpt-live-session-config], [rt-gpt-live-lifecycle], [rt-gpt-live-delegation], [rt-gpt-live-sideband], [rt-barge-in], [rt-ephemeral-keys] ; product-lookup : Q-43, Q-47, Q-53). Parole du porteur (2026-10-29, conversation) : « utilise le TTS » pour les phrases de test ; il est disponible pour l'essai réel (S6). | `specs/002-sp-02-gpt-live-sdp-relay/` |
| 2026-10-29 | Expérimenter | S1 (lecture du code `openai-go/v3` v3.90.0) : création de session par le SDK (`client.Live.New`, pas de POST brut) ; **trois modes de délégation** (`client` par défaut, `responses`, `decisions` — absent de nos notes, le libellé de Q-47 est incomplet) ; `session.started` porte `expires_at` (Q-53) ; événements nouveaux `info`, `response.event`, `decision.*`, `session.output_audio.fixture.*` ; la clé du porteur voit `gpt-live-1` et `gpt-live-transcribe` (`GET /v1/models`, gratuit) ; nos notes se contredisent sur le modèle `responses` (`gpt-6-luna`/`gpt-6-sol` vs `gpt-5.6-terra`). Préparation de S2 sans appel `gpt-live-1` : relais `spikes/sp02-gpt-live/relay/`, client `pion` `client/`, outil TTS `tts/` (vérifiés par le pilote : `go build`/`go vet`/`go test` OK, 0 occurrence de la clé dans le dépôt) ; 4 phrases TTS générées hors dépôt (`gpt-4o-mini-tts`, 0,01 € enregistré). | `specs/002-sp-02-gpt-live-sdp-relay/notes-s1.md` ; `specs/openai-spend.tsv` |

## Revue d'architecte
Sans objet pour un spike (dev-loop § 2 bis).

## Questions pour le porteur
- **Q-43** et **Q-47** : se tranchent avec les résultats de ce spike (proposition de décision à valider).
