# 001 — État

- **Étape** : Expérimenter (spike : Définir → Expérimenter → Consigner → Clôture)
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/001-sp-03-a2a-go-genui
- **Backlog** : EP-03 (spike SP-03)
- **Mis à jour** : 2026-10-29 15:20

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | Définir | spec, plan et tâches du spike rédigés (skills kb-lookup et product-lookup : [ma-backend-sdk-go], [genui-a2a-connector], [proto-a2a-bindings], Q-39, Q-46) | `specs/001-sp-03-a2a-go-genui/` |
| 2026-10-29 | Expérimenter | S1 (lecture du code) : **verdict compatible via `a2acompat/a2av0`** — `genui_a2a` 0.10.1 parle A2A v0.3 (`message/stream`, `message/send`), carte `/.well-known/agent-card.json`, POST JSON-RPC sur l'URL de base, en-tête `X-A2A-Extensions`, parts A2UI = `{kind:data}` lues dans `status.message` d'un `status-update` ; le handler natif v1.0 d'a2a-go (`a2asrv`) est incompatible (`-32009` sans `A2A-Version`). S2 : agent Go `spikes/sp03-a2a/agent/` (a2a-go v2.7.0, Go 1.27.3) ; `go build`/`go vet` OK ; vérifié par le pilote : carte 200 et `message/stream` → 5 événements SSE (task submitted, createSurface, updateComponents, updateDataModel `/crashFree` = « 99,57 % », completed). Pièges : carte sans `url`/`preferredTransport` si l'interface n'est pas en `ProtocolVersion` 0.3 ; gob du magasin de tâches (`map[string]any`/`[]any` seulement) ; `sendEvent` (`message/send`) n'atteint jamais `connector.stream` → les clics passent par `connectAndSend`. Reste S3 (client Flutter) et S4 (aller-retour d'une action). | `specs/001-sp-03-a2a-go-genui/notes-s1.md` ; sorties `curl` ci-dessus |

## Revue d'architecte
Sans objet pour un spike (SKILL § 2 bis).

## Questions pour le porteur
<!-- Q-xx créées : ce qui est bloqué, ce qui continue. -->
