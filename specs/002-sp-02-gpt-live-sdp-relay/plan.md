# 002 — Plan technique (spike)

## Où
| Pile | Dossier | Contenu |
|---|---|---|
| Go | `spikes/sp02-gpt-live/relay/` | relais SDP + attache sideband + journal JSONL |
| Go | `spikes/sp02-gpt-live/client/` | client `pion` sans clé : piste audio synthétisée, mesure de l'audio reçu, data channel `oai-events` |
| Hors dépôt | scratchpad | audios TTS (Ogg/Opus), journaux bruts |

## Références
- `knowledge/` : [rt-gpt-live-overview], [rt-gpt-live-webrtc-session], [rt-gpt-live-session-config], [rt-gpt-live-lifecycle], [rt-gpt-live-delegation], [rt-gpt-live-sideband], [rt-barge-in], [rt-ephemeral-keys], [ma-backend-sdk-go].
- Corps de création (note [rt-gpt-live-webrtc-session]) : `{"session":{"model":"gpt-live-1","instructions":…,"delegation":{…}},"transport":{"type":"webrtc","sdp":…}}` → 201 `{session:{id}, transport:{sdp}}`. Ne pas mettre `audio.format` ; ne pas envoyer `session.start` ; créer le data channel `oai-events` avant l'offre ; attendre la fin de la collecte ICE.
- Prix : 0,05 $/min (15 s facturées à l'initialisation en WebRTC) + modèle délégué en mode `responses` ([rt-gpt-live-overview]).

## Risques
- La clé du porteur peut ne pas avoir accès à `gpt-live-1` (erreur 4xx au premier essai : consigner le code et le message sans la clé).
- Le côté client en Go exige un encodage Opus : le TTS en `opus` (Ogg) évite tout encodeur (lecture directe des pages Ogg).
- `session.output_audio.delta` : à confirmer qu'il est bien émis sur le sideband avec une session créée en WebRTC.
- La clé ne doit apparaître ni dans les journaux, ni dans les erreurs, ni dans les sorties citées.
