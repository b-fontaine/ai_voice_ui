---
id: p-ar-app-channel-contract
title: Contrat v1 de l'app-channel (implémenté par 003, 004 et 006)
area: architecture
status: draft
updated: 2026-10-30
sources: [specs/006-j3-act1-backend/plan.md, specs/006-j3-act1-backend/status.md, contracts/a2ui/genesis/v1/README.md, specs/005-j2-app-voice-orb/status.md, specs/003-j2-voice-relay-backend/plan.md, specs/004-j2-orchestrator-quality-agent/plan.md, specs/004-j2-orchestrator-quality-agent/status.md, knowledge:genui-a2ui-messages, knowledge:genui-a2ui-security, knowledge:rt-gpt-live-lifecycle, knowledge:rt-gpt-live-sideband]
links: [p-ar-frontend, genui-data-model, p-fn-catalog, p-fn-dataset, p-fn-business-rules, p-rm-roadmap, pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog, pdr-0023-example-guided-composition,  pdr-0038-latency-measured-on-app-clock, p-ar-agents-protocols, p-ar-backend, p-ar-security, p-ar-replay, p-rm-open-questions, pdr-0019-six-limit-applies-to-surfaces, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0045-app-backend-channel-wss-recommended, pdr-0051-orb-level-from-sideband-rms-recommended, pdr-0052-one-gpt-live-session-per-act-recommended, rt-gpt-live-output-level, rt-gpt-live-lifecycle, rt-gpt-live-sideband, rt-graceful-close, genui-a2ui-messages, genui-a2ui-security, proto-a2a-task-lifecycle, ma-real-tool-results]
tags: [protocoles, app-channel, a2ui, wss, contrat, agent-activity, validation]
---
# Contrat v1 de l'app-channel (fonctionnalités 003, 004, 006 et côté client 005)

**En bref.** Ce que le backend expose réellement à l'app : routes HTTP et WSS `GET /app`, enveloppe `{v:1, type, session, t_ms, data}` et 8 types de messages. 003 (2026-10-29) a livré la voix (`orb.level`, `transcript`, `session.state`, `usage`) ; 004 (2026-10-29, vérifié en réel) ajoute l'A2UI relayé, l'activité des agents et la délégation ; 006 (J3-A, 2026-10-30, vérifiée en réel) ajoute le message `plan` (choix des agents, [pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)), l'état `rejected` et le catalogue fermé `genesis`. Ancrage : [pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md), [pdr-0051](../decisions/pdr-0051-orb-level-from-sideband-rms-recommended.md), [pdr-0052](../decisions/pdr-0052-one-gpt-live-session-per-act-recommended.md), [pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md). Contexte et séquences : [p-ar-agents-protocols](agents-protocols.md).

## Routes

| Route | Rôle | Réponses |
|---|---|---|
| `POST /voice/sessions` | corps `application/sdp` (offre) → answer SDP + en-tête `X-Session-Id` | 200 ; 400 corps vide ou illisible ; 413 trop gros ; 415 pas `application/sdp` ; 429 + `Retry-After` ; 502 `{error}` opaque |
| `DELETE /voice/sessions/{id}` | fermeture propre ([rt-graceful-close]) | 204 ; 404 inconnue ; 504 fermeture non confirmée à temps ; 502 sinon |
| `GET /healthz` | sonde du conteneur | 200 `ok` |
| `GET /app` (WSS) | toutes les sessions, y compris futures ; `?session=<id>` = filtre facultatif | 400 identifiant invalide ; 404 identifiant inconnu ; 1008 abonné trop lent |

Toutes les routes : 421 `{error}` si l'en-tête `Host` n'est pas autorisé (anti DNS rebinding). Identifiant de session : `[A-Za-z0-9_-]{1,128}`. Erreurs en JSON `{error}`, jamais de détail du fournisseur ni de clé.

## Enveloppe et types de messages

`{v:1, type, session, t_ms, data}` ; `session` = id de la session voix ; `t_ms` en ms (temps du fournisseur pour les transcripts). **004** ajoute deux champs facultatifs au premier niveau, omis si vides : `agent` (nom de la carte de l'agent émetteur) et `task` (id de tâche A2A). Les messages `a2ui` les portent toujours ; `agent.activity` les répète depuis `data`. `agent` vaut `"orchestrateur"` pour une **compensation** `deleteSurface`. Le journal a les mêmes champs.

| `type` | `data` | Cadence / note |
|---|---|---|
| `orb.level` | `{level}` 0..1 | 5 Hz, RMS PCM16 24 kHz par blocs de 200 ms ([rt-gpt-live-output-level]) |
| `transcript` | `{role: user\|ai, text, start_ms, end_ms}` | pas de `final` : GPT-Live n'émet pas de fin de tour ([rt-gpt-live-lifecycle]) ; FR-19 |
| `session.state` | `{state, reason?}` | `connecting` (avant l'answer), `active` (sideband attaché), `closed` |
| `usage` | `{seconds, context_ratio}` | issu de `usage.updated` ([rt-gpt-live-sideband]) |
| `delegation` (004) | `{id, offset_ms}` | publié à la création d'une délégation par le modèle, avant tout `agent.activity` ; rend NFR-02 mesurable (`offset_ms` = temps du fournisseur) |
| `plan` (006) | `{delegation, selected[], idle[]}` | noms d'agent (tableaux, jamais `null`) ; publié **avant toute activité** de la délégation ; journalisé, **rejoué aux abonnés tardifs** (rétention du hub) ; un `deleteSurface` ne l'efface pas ; un agent de `idle` ne reçoit aucun `agent.activity` ; `selected` vide = demande hors catalogue (RG-08) |
| `agent.activity` (004) | `{agent, task, state, label?, detail?}` | `state` ∈ `working`, `completed`, `failed`, `rejected` (006) ; `canceled` est réservé (annulation « Stop », J7), **non émis** ; `label` = nom du premier skill de la carte (FR-03) |
| `a2ui` (004) | le **message A2UI v0.9 lui-même**, relayé tel quel et sans enrobage ([genui-a2ui-messages]) | une opération par message : `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface` ; `theme` de `createSurface` relayé, ignoré par l'app |

- **`detail`** d'un `failed` : ensemble fermé « injoignable », « délai dépassé », « A2UI invalide », « échec de l'agent », « session fermée » ; jamais d'erreur brute ni d'URL. Un `rejected` (006) porte le détail fermé « hors périmètre ».
- **Tout agent de `plan.selected` reçoit un `agent.activity` terminal** (`completed`, `failed` ou `rejected`), y compris un délai dépassé avant le suivi de sa tâche : le rail (FR-03, 007) n'a pas d'agent « bloqué en cours ».
- **`working`** est publié à la réception de l'état A2A `submitted` ; `task` reste stable jusqu'à l'état terminal ([proto-a2a-task-lifecycle]). Carte injoignable : `agent` = dernier nom connu, sinon l'hôte de l'URL.
- **Raisons de `closed`** : du fournisseur, `close_requested`, `expired`, `remote_hangup`, `content` ; du backend, `connection_lost`, `max_session` (`VOICE_MAX_SESSION`, Q-68), `attach_failed`.

## Ordre, backlog, rétention, journal

- **Ordre garanti** : par agent, les messages `a2ui` sont publiés dans l'ordre du flux A2A ; l'ordre `delegation` → `agent.activity working` → `a2ui` est vérifié (acceptation B1). Registre de surfaces et publication sont sous un même verrou de session.
- **Backlog** : à la connexion, rejeu des derniers messages (hors `orb.level`), 50 au plus, dans l'ordre global de publication, sans doublon avec le direct ; une session est oubliée une fois `closed` publié.
- **Rétention du hub (004)** : en plus, **512 messages `a2ui` et `agent.activity` par session** (option injectée) que les transcripts n'évincent pas, rejoués avec le backlog. Éviction : d'abord les `agent.activity`, puis les mises à jour, **jamais le `createSurface` d'une surface vivante** (dernier recours théorique seulement, inatteignable avec 6 surfaces). Un `deleteSurface` fait oublier tous les messages de la surface et n'est pas retenu.
- **Journal** : `<JOURNAL_DIR>/<session>.jsonl`, une ligne = enveloppe sans `v` + `unix_ms`, mêmes noms de champs ; base du journal horodaté ([p-ar-replay](replay.md)).
- **Portée** : registre de surfaces et rétention sont **par session voix** ; depuis 006, `ContextID` A2A = id de session (la mémoire par contexte et son renouvellement après compensation ont disparu des agents : le **registre de surfaces de l'orchestrateur est la seule source de vérité**, voir § Surfaces actives) ; avec [pdr-0052](../decisions/pdr-0052-one-gpt-live-session-per-act-recommended.md) (une session par acte), un changement de session perdrait l'état → Q-70 (FR-07).
- **Surfaces actives** (006) : à chaque requête, l'orchestrateur lit sous le verrou les surfaces actives de l'agent (`Registry.ActiveFor`) et les passe dans les `metadata` du message A2A, clé **`genesis/activeSurfaces`** (`[]any` de chaînes ; liste vide = clé présente). Le composeur de l'agent n'émet `createSurface` que pour une surface qu'il produit et qui manque à cette liste (bornes côté agent : ≤ 16 éléments, ≤ 64 runes). Effet : une surface déjà ouverte n'est jamais recréée ; elle ne se rouvre qu'après un `deleteSurface` (Q-70).

## Politique d'échec (004, 006)

Relais **message par message** dès validation (RG-02, NFR-02), sans attendre la fin de la tâche. Au premier message invalide, à `failed`/`rejected`/`canceled`, à `AGENT_TIMEOUT` ou à un flux terminé sans état final :

1. arrêt de la lecture et `CancelTask` ;
2. **compensation** : un `deleteSurface` émis par l'orchestrateur pour chaque surface créée par la tâche (ordre inverse), sans réécrire de message d'agent ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) ;
3. `agent.activity failed` avec son `detail` ;
4. commentaire vocal d'échec honnête, sans chiffre ; **jamais de silence** (phrase neutre, ou phrase propre au rejet de l'agent ; une tâche `completed` sans résumé reçoit aussi sa phrase), jamais après la fermeture de session. Le résumé de l'agent n'est dit que si la tâche est `completed` ET tous les messages valides ([ma-real-tool-results]).

⚠️ Hypothèse non confirmée : retirer la surface partielle (comportement **provisoire**, cohérent avec FR-16/RG-14) plutôt que la laisser en état neutre (RG-10) → Q-69. Conservé tel quel en 006 pour `failed`.

**Refus (006)** : un agent **retenu** qui refuse (`AgentRejected`) passe en `agent.activity rejected` (détail « hors périmètre »), pas en `failed` : **pas de commentaire d'échec ni de mention vocale** du refus, et en pratique rien à compenser (les agents refusent avant tout message A2UI) ; cas limite : un agent qui refuserait après avoir émis des surfaces verrait celles-ci retirées (`deleteSurface`, comme pour `failed`, Q-69). Un refus partiel n'est pas un échec du plan ; si **tous** les agents retenus refusent, la voix dit `failure_rejected` (avec alternative, RG-08). Aucun agent retenu (`plan.selected` vide) : aucun appel, la voix dit `out_of_catalog`. Échec partiel (au moins un `failed`, d'autres `completed`) : le résultat des agents qui ont réussi est dit, suivi de `partial_failure` qui nomme l'agent en échec (RG-04, [ma-real-tool-results]).

## File par session

Une file et une seule goroutine de traitement par session, profondeur 2 : une délégation reçue pendant une autre est mise en file et reçoit aussitôt son commentaire générique ; au-delà, commentaire honnête sans appel d'agent. Un `delegation.id` déjà vu (ou vide) est ignoré. Les agents d'un plan tournent en parallèle. Depuis 006, **l'orchestrateur choisit les agents** ([pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)) : il lit chaque carte une fois par délégation, puis un `Planner` (`TagPlanner` : tags des skills, mots entiers, remplaçable par un LLM, Q-17) retient un sous-ensemble ; détail dans [p-ar-backend](backend.md).

## Validateur A2UI v0.9 (côté orchestrateur)

Les agents produisent l'A2UI ; l'orchestrateur la **valide et la relaie** ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md), [genui-a2ui-security]). La map reçue n'est jamais modifiée.

| Niveau | Règles |
|---|---|
| Message (sans état) | ≤ 64 Kio, profondeur JSON ≤ 16 ; `version == "v0.9"` ; une seule opération et aucune autre clé de premier niveau ; `surfaceId` `^[A-Za-z0-9_-]{1,64}$` |
| `createSurface` | `catalogId` = `A2UI_CATALOG_ID` ; `sendDataModel` booléen |
| `updateComponents` | 1 à 100 composants, `id` uniques dans le message ; `component` dans la liste blanche `A2UI_COMPONENTS` ; `child`/`children` en identifiants ou gabarit `{componentId,path}` ; **propriétés (006)** : si `A2UI_ALLOWED_PROPS` est renseignée, toute autre clé est refusée (`bad_property`, message fixe sans valeur) ; si `A2UI_BINDING_PROPS` est renseignée, chaque propriété listée doit valoir `{path: <JSON Pointer ≤ 128 runes>}` (jamais un littéral). Listes vides : aucun contrôle (J2 intact) |
| `updateDataModel` | `path` vide ou JSON Pointer |
| Session (registre) | `createSurface` refusé si la surface existe ou si **6 surfaces** sont ouvertes ([pdr-0019](../decisions/pdr-0019-six-limit-applies-to-surfaces.md)) ; toute autre opération exige une surface active **du même agent** (identifiant d'agent, pas son nom affiché) ; ≤ 200 composants par surface, ≤ 64 messages par tâche |
| Fin de tâche | chaque surface créée a un `root` et toutes ses références sont résolues, sinon échec (le rendu progressif est valide en v0.9) |

Codes d'erreur fermés, jamais exposés à l'app ni à la voix. `NewValidator` refuse une configuration où `A2UI_BINDING_PROPS` contient une propriété absente de `A2UI_ALLOWED_PROPS`. Les entrées de l'orchestrateur sont bornées : tags de carte (≤ 32, de 1 à 40 runes, sans caractère de contrôle), noms d'agent nettoyés (40 runes, contrôles et bidi retirés), doublons de `AGENTS` refusés. Validation côté client : Q-71 reste ouverte (007).

## Catalogue fermé `genesis` v1 (006, contrat exécutable)

Contrat dans `contracts/a2ui/genesis/v1/` (`catalog.json`, `examples/act1-*.jsonl`, README) ; fonctionnel : [p-fn-catalog](../functional/catalog.md). `A2UI_CATALOG_ID` : valeur par défaut **provisoire** du compose `https://genesis-canvas.example/a2ui/catalogs/genesis/v1` (Q-44 ouverte) ; en J2 : URI du catalogue « basic » v0.9.

| Point | Contrat |
|---|---|
| Liste blanche J3 (`A2UI_COMPONENTS`) | **4** composants qui ont un schéma : `KeyIndicator`, `TrendChart`, `ReviewSentiment`, `ReleaseChecklist` (ni `Column` ni `Text`) ; `ActionBar` et `CrashList` s'ajoutent avec leur fonctionnalité (les 6 de [pdr-0014](../decisions/pdr-0014-six-component-catalog.md) : `catalogComponents`) |
| Forme | composants **plats**, un `root` par surface (`kpi`, `trend`, `reviews`, `checklist`) ; propriétés admises `id`, `component`, `data` ; `data = {path: "/<surface>"}` |
| Trois temps (RG-02) | `createSurface` (`sendDataModel: false`) → `updateComponents` (donnée absente : squelette) → `updateDataModel` du chemin **entier** ; le backend ne garantit que l'**ordre**, pas la durée du squelette (visible côté client : 007) |
| Données | codes de statut fermés `ok\|risk\|blocking` + libellé séparé ; nombres JSON (`thresholdPct`, `yMaxPct`) ; champs `comparison` réservés à l'acte 2 (FR-07 = `updateDataModel` du chemin entier, [genui-data-model]) |
| Composition | déterministe derrière `Composer` : les messages émis sont **exactement** les fixtures (Q-17 ouverte ; conflit connu avec [pdr-0023](../decisions/pdr-0023-example-guided-composition.md), les fixtures servant d'exemples d'écrans) |

## Côté client (005, 2026-10-30)

Implémenté dans `shared/backend_channel` et `features/voice_session` ([p-ar-frontend](frontend.md)).

| Point | Comportement |
|---|---|
| Ouverture | le client ouvre le WSS **après** le 200 du relais, avec `?session=<X-Session-Id>` ; **sans en-tête `Origin`**, hôte tel que configuré (`GENESIS_BACKEND_URL`, origine seule) ; le backlog rejoue ce qui a été publié entre l'answer et la connexion (hors `orb.level`) |
| Messages illisibles | type inconnu ou enveloppe illisible : **ignoré et consigné** (phrases fermées, jamais le contenu), jamais fatal ; un message A2UI refusé par le décodeur est écarté de la même façon |
| Perte du canal | événement `ChannelLost` (le flux d'événements n'émet jamais d'erreur) ; `closed` du backend de la session courante : libération locale sans `DELETE` ; perte du WSS : `DELETE` au mieux puis libération (pas de session facturée sans visuels) |
| Journal local | `EnvelopeLog` (`GENESIS_APP_LOG`, inactif sans chemin) : format du journal backend (enveloppe sans `v`, mêmes noms de champs) + `unix_ms` lu sur l'**horloge de l'app** à la réception ([pdr-0038](../decisions/pdr-0038-latency-measured-on-app-clock.md)), jamais le `t_ms` du backend ; **base du rejeu (J6)** |

## Non couvert (à venir)

Actions utilisateur typées (J5), annulation « Stop » et état `canceled` (J7), révision de consigne (J4), côté client du catalogue `genesis` (007). Variables d'environnement : [p-ar-backend](backend.md) § Configuration injectée ; sécurité : [p-ar-security](security.md).
