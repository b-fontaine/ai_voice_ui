# 001 — État

- **Étape** : Consigner (spike : Définir → Expérimenter → Consigner → Clôture)
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
| 2026-10-29 | Expérimenter | S3+S4 : client Flutter jetable `spikes/sp03-a2a/client/` (`genui` 0.10.4, `genui_a2a` 0.10.1, `a2ui_core` 0.1.1). Test de bout en bout contre l'agent Go réel, rejoué par le pilote : `+1: All tests passed!` ; agent `action reçue : validate` ; aucun processus restant. Prouvé : `A2uiAgentConnector` → `A2uiTransportAdapter(onSend: connectAndSend)` → `Conversation` + `SurfaceController` rend la `Surface` (« Sessions sans crash », « 99,57 % ») ; le tap sur le bouton repart par `connectAndSend` (`UiInteractionPart` contenant `validate`), l'agent répond `updateDataModel /status` = « validé » affiché. **Aucune glue supplémentaire** (ni `genui` ni `genui_a2a`) ; ne pas passer par `sendEvent`. Simulé : seulement le tap (`WidgetTester`). Pièges de harnais `testWidgets` (HttpOverrides à `null`, connecteur dans `runAsync`, boucle `runAsync`/`pump`, `pump(20 s)` pour le `Timer` de 15 s) consignés dans `notes-s3.md`. Résultat du spike : ✅. | `specs/001-sp-03-a2a-go-genui/notes-s3.md` ; test `spikes/sp03-a2a/client/test/a2a_roundtrip_test.dart` |

## Revue d'architecte
Sans objet pour un spike (SKILL § 2 bis).

## Questions pour le porteur
<!-- Q-xx créées : ce qui est bloqué, ce qui continue. -->
