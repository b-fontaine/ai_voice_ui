---
id: rt-gpt-live-session-config
title: GPT-Live — configuration de session et voix
tags: [openai, gpt-live, voices, config, french]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/live-conversations.md]
links: [rt-gpt-live-overview, rt-gpt-live-delegation]
---
# GPT-Live : configuration de session

Les champs de `session` sont fixés à la création. La plupart sont **immuables** : pour les changer, il faut ouvrir une nouvelle session.

| Champ | Détail |
|---|---|
| `model` | `gpt-live-1`. Immuable. |
| `instructions` | ≤ 16 384 tokens. On peut compléter ensuite avec `session.instructions.append`. |
| `input` | Historique texte : ≤ 128 messages et 8 192 tokens. Rôles `developer`, `user`, `assistant`. |
| `audio.output.voice` | `marin` par défaut. Immuable. |
| `audio.format` | WebSocket uniquement. À omettre en WebRTC. |
| `delegation.type` | `client` (par défaut si omis ou null) ou `responses`. Immuable. |
| `store` | `false` par défaut. `true` permet le fork. Incompatible avec ZDR. |

**Voix FR (au 2026-10-26) :** `brise`, `sillage`.

Autres langues :
- EN : quartz, ripple, vesper, willow, stone, gleam, meridian, beacon, delta, cinder
- PT : bossa, tempo
- DE : nuri, juni, flitz
- HI : nira
- JA : harema, shida
- KO : noeul

**Reprise de conversation :** deux voies documentées.
- **Fork** d'une session stockée (`store: true`, enregistrement finalisé, conservé 30 jours, indisponible en ZDR) : `POST /v1/live/sessions/{source_session_id}/fork` (WebRTC, nouvelle offre SDP) ou `wss://…/fork` (WebSocket). Nouveau `session.id`.
- Sinon, nouvelle session avec l'historique texte dans `input`.

## ⚠️ Pièges
- Changer de voix en cours de session est impossible. Prévoir le choix de voix **avant** la connexion, dans la config de l'agent vocal.
- `session.update` hors `delegation.responses` est rejeté. Changer de mode de délégation renvoie `immutable_field_update`.
