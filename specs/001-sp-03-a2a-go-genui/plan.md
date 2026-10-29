# 001 — Plan technique (spike)

## Où
| Pile | Dossier | Contenu |
|---|---|---|
| Go | `spikes/sp03-a2a/agent/` | module Go jetable : agent A2A minimal (`a2a-go/v2`) qui répond à `message/stream` par des parts A2UI v0.9 et traite une action |
| Flutter | `spikes/sp03-a2a/client/` | projet Flutter jetable : `genui` 0.10.4 + `genui_a2a` 0.10.1, test qui connecte `A2uiAgentConnector` à l'agent et vérifie une surface rendue puis l'aller-retour d'une action |

## Références
- `knowledge/` : [ma-backend-sdk-go], [genui-a2a-connector], [proto-a2a-bindings], [proto-a2a-dart-sdk], [genui-user-actions], [genui-a2ui-messages].
- Fait de départ : `genui_a2a` parle `message/stream` (nommage A2A v0.3) sur SSE avec `X-A2A-Extensions` ; `a2a-go` v2 implémente la v1.0 (PascalCase) avec compat v0.3 via `a2acompat` ([ma-backend-sdk-go]). À vérifier dans le code.

## Risques
- Go ≥ 1.26.10 requis par certaines dépendances ; la machine a Go 1.27.3 ;
- réseau nécessaire pour résoudre les modules Go et les paquets pub (échec d'environnement : le noter, ne pas compter de tentative) ;
- le code du spike ne doit jamais être importé par `apps/`, `packages/` ou `backend/`.
