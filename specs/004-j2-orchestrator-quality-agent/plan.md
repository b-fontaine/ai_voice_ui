# 004 — Plan technique

## Où
| Pile | Module | Couche | Contenu |
|---|---|---|---|
| Go | `backend/orchestrator` | domaine / ports | `domain` : messages `a2ui` (message A2UI v0.9 brut) et `agent.activity{agent,task,state,detail}` ; `port.RemoteAgent` ; `LiveEvent` gagne `EventDelegationCreated` (`DelegationID`) ; `port.Sideband` gagne `AppendCommentary` et `AppendThinking` |
| Go | idem | application | `internal/app/a2ui` : validateur v0.9 ; `internal/app/orchestrate` : reconstruction de la demande, plan, appels parallèles, validation, diffusion, commentaire vocal |
| Go | idem | adaptateurs | `adapter/openailive` : `delegation.created`, `session.commentary.append` / `thinking.append` ; `adapter/a2aclient` : client `a2a-go/v2` (carte d'agent, `SendStreamingMessage`) |
| Go | `backend/agents/quality` (nouveau `go.mod`) | agent A2A | serveur `a2a-go/v2` natif v1.0 ; carte d'agent ; exécuteur déterministe sur le jeu figé embarqué ; port `Composer` (LLM plus tard) |
| Infra | racine | — | service `agent-quality` dans `docker-compose.yaml` (réseau interne, aucun port publié), `backend/agents/quality/Dockerfile`, CI étendue, instructions vocales qui demandent la délégation |

## Contrats
- **Délégation `client`** ([rt-gpt-live-delegation]) : `session.delegation.created` (`delegation.id`, sans les mots de l'utilisateur) → la demande est reconstruite depuis `session.input_transcript.delta` reçus depuis la délégation précédente ; retour par `session.commentary.append` (dit, paraphrasable, ≤ 500 tokens, `event_id` unique, acquitté par `…appended`) ; le commentaire générique part sans attendre l'agent (RG-04) et annule l'accusé automatique ; jamais de faux résultat ([ma-real-tool-results]).
- **A2A** ([proto-a2a-agent-card], [proto-a2a-go-v03-compat]) : l'orchestrateur est client natif v1.0 de l'agent ; l'agent publie sa carte (`/.well-known/agent-card.json`, skill `quality-kpi`) ; flux : tâche `submitted`, `status-update` dont les `parts` `data` portent chacune UN message A2UI v0.9, puis un `Artifact` texte (résumé factuel) et `completed`. Uniquement `map[string]any` et `[]any` dans les parts (piège gob).
- **App-channel** (extension du contrat v1 de 003) : types `a2ui` (`data` = message A2UI v0.9 tel que validé, envoyé sans recomposition) et `agent.activity` (`state`: `working`, `completed`, `failed`) ; mêmes enveloppe, `session`, backlog (rejoués à la connexion : `a2ui` et `agent.activity`, pour qu'une app qui se connecte tard retrouve l'état) et journal.
- **Validateur A2UI v0.9** ([genui-a2ui-security], [genui-a2ui-messages]) : une et une seule opération par message (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`), `version == "v0.9"`, `surfaceId` non vide ; `createSurface.catalogId` égal au `A2UI_CATALOG_ID` configuré ; composants à `id` uniques avec un `root` ; références d'enfants résolues ; au plus 6 surfaces ouvertes (pdr-0019) ; taille bornée.
- **Signatures imposées par les tests d'acceptation (T01-T03, B4)** :
  - `port.EventDelegationCreated` (type d'événement) et `port.LiveEvent.DelegationID string` ; `port.Sideband` gagne `AppendCommentary(ctx context.Context, delegationID, text string) error` et `AppendThinking(ctx context.Context, delegationID, text string) error` ; `port.RemoteAgent` (carte + `SendStreamingMessage`, interne : non imposé par les tests, qui passent par `AGENTS`).
  - `domain` : `TypeA2UI = "a2ui"` avec `A2UI{Message map[string]any}` (sérialisé tel quel dans `data`) ; `TypeAgentActivity = "agent.activity"` avec `AgentActivity{Agent, Task, State, Detail string}` (JSON `agent`, `task`, `state`, `detail`) ; états `ActivityWorking = "working"`, `ActivityCompleted = "completed"`, `ActivityFailed = "failed"`.
  - `port` (T10, `backend/orchestrator/internal/port/agent.go`) : `RemoteAgent{Card(ctx) (AgentCard, error); Send(ctx, AgentRequest) (<-chan AgentUpdate, error)}` ; `AgentCard{Name, Description string; Skills []string}` ; `AgentRequest{Text, ContextID string}` ; `AgentUpdate{Kind AgentUpdateKind; A2UI map[string]any; Text string; Err error}` avec `Kind` ∈ {`UpdateA2UI`, `UpdateText`, `UpdateCompleted`, `UpdateFailed`} ; canal fermé après `UpdateCompleted` ou `UpdateFailed`.
  - Configuration lue par `bootstrap.ConfigFromEnv` : `AGENTS` (URL de cartes, séparées par des virgules), `A2UI_CATALOG_ID`, `AGENT_TIMEOUT` (durée) ; `bootstrap.New` ne contacte pas les agents (la carte est lue à la délégation, sinon une carte injoignable ferait échouer le démarrage).
  - Agent `agent` : `agent.Config{PublicURL, CatalogID, DatasetPath string}` et `agent.NewServer(cfg agent.Config) (http.Handler, error)` dans `backend/agents/quality/internal/agent` ; le handler sert la carte (`/.well-known/agent-card.json`) et le JSON-RPC natif v1.0 sur `POST /`.
  - Comportement : le nom de l'agent de `agent.activity` est le `name` de la carte ; commentaire générique d'abord (sans chiffre), puis un commentaire fondé sur le résumé texte de l'artefact (« 99,57 % ») ou, en cas d'échec (tâche `failed`, carte injoignable, A2UI invalide), un commentaire sans « % » qui contient « échec », « pas pu », « impossible », « indisponible » ou « erreur ».
- **Configuration** : `AGENTS` (liste d'URL de carte, séparées par des virgules), `A2UI_CATALOG_ID`, `AGENT_TIMEOUT` ; l'agent : `AGENT_LISTEN_ADDR`, `DATASET_PATH` facultatif (jeu embarqué par défaut).
- **Jeu de données** ([p-fn-dataset], pdr-0040) : sessions sans crash global 7 j = 99,57 % (seuil ≥ 99,50 %, « à risque ») ; copie JSON figée et versionnée sous `backend/agents/quality/dataset/`, identique en valeur à `product/functional/dataset.md`.

## Références
- `product/architecture/backend.md`, `agents-protocols.md` (contrat v1 implémenté par 003), `stage-runtime.md`.
- Notes : [rt-gpt-live-delegation], [rt-gpt-live-sideband], [proto-a2a-go-v03-compat], [proto-a2a-agent-card], [proto-a2a-task-lifecycle], [genui-a2ui-messages], [genui-a2ui-security], [ma-real-tool-results], [ma-filler-acknowledgements], [ma-backend-sdk-go].
- Code jetable de référence : `spikes/sp03-a2a/agent` (agent Go A2A qui produit de l'A2UI), `spikes/sp02-gpt-live/relay` (délégation `client`).

## Risques
- Le modèle ne délègue que si les instructions l'exigent → instructions vocales provisoires mises à jour ; vérifié par l'essai réel.
- Trames `session.delegation.created` / `commentary.append` non vues par les tests → l'essai réel unique les confronte à la vraie API (SP-02 les a observées : délai 1,0 s, acquittement 0,7 s).
- API `a2a-go/v2` (v2.7.0) et gob des parts → tests avec un vrai serveur A2A en processus de test.
- Deux modules Go : `tools/loop/verify.sh` trouve tous les `go.mod` sous `backend/` ; la CI et les Dockerfile doivent suivre.
