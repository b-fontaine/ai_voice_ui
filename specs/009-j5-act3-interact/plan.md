# 009 — Plan technique

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Contrat | `contracts/a2ui/genesis/v1/` | contrat exécutable | `catalog.json` (`ActionBar` : schéma, `components` passe à 5), `examples/act2-actions.jsonl`, `examples/act3-block.jsonl`, `act3-validate.jsonl` (un `updateDataModel` du sous-chemin), `README.md` |
| Go agents | `backend/agents/internal/dataset` | domaine | `dataset.json` (`decisions` : libellés « Bloquée » / « Validée »), `decision.go` : `Dataset.Decision(action)` |
| Go agents | `backend/agents/internal/kit` | noyau | `Request.Action` ; `executor.go` lit la clé de metadata `genesis/action` ; `ParseIntent` n'est pas appelé pour une action ; clé exportée `ActionKey` |
| Go agents | `backend/agents/internal/delivery` | composeur | `profile.json` (tags `action:block_release`, `action:validate_release`), `composer.go` (branche action : un `updateDataModel` du sous-chemin ; branche acte 2 : ajoute les messages de la surface `actions` si elle manque) |
| Go orchestrateur | `internal/port` | port | `AgentRequest.Action` ; `VoiceReply.Announce(ctx, text)` ; `Sideband.Announce` |
| Go orchestrateur | `internal/adapter/a2aclient` | adaptateur | metadata `genesis/action` du message A2A |
| Go orchestrateur | `internal/app/orchestrate` | application | `ActionPlanner` (choix par tags `action:*`), `Pipeline.RunAction` (réutilise plan/tâche/validation/compensation, sans fenêtre de transcription), `Manager.Act` (session cible, file, `busy`/`no_session`) ; commentaire de fin par `Announce` |
| Go orchestrateur | `internal/adapter/httpapi` | adaptateur | `POST /canvas/actions` (gardes de `/canvas/reset`) |
| Go orchestrateur | `internal/adapter/openailive` | adaptateur | `Announce` : stratégies ordonnées, attente d'un transcript sortant borné |
| Go orchestrateur | `internal/bootstrap` | composition | configuration (`A2UI_COMPONENTS` à 5, `VOICE_ANNOUNCE_TIMEOUT`, stratégies), `phrases.fr.json` (échec d'action) |
| Compose | `docker-compose.yaml` | session principale seule | variables d'environnement ; liste `A2UI_COMPONENTS` |
| Flutter | `packages/entities/catalog` | domaine | `GenesisContract` (5 composants, champs de `ActionBar`), validateur client |
| Flutter | `packages/features/canvas` | ui / model | `catalog/action_bar.dart` (`CatalogItem`), `genesisCatalog` (5 items), `model/` : `CanvasActionBloc` (events `ActionRequested`, états `Idle/Sending/Failed`, transformer `droppable`), interception du clic (voir « Contrats ») |
| Flutter | `packages/shared/backend_channel` | api | `canvas_action_client.dart` (port) + `http_canvas_action_client.dart` (réessai borné sur `busy`, comme la remise à vide) |
| Flutter | `packages/shared/design_system` | ui | jetons du bouton d'action par `tone` (`neutral`, `danger`), cibles ≥ 48 px |
| Flutter | `packages/features/catalog_shelf` | ui | « 5 / 6 utilisés » (calculé sur `components`) |
| Flutter | `apps/genesis_canvas` | composition | `app/di` : client d'action ; `GenesisCanvasPage` : câblage ; asset `assets/replays/act3-replay.jsonl` (artefact dérivé des fixtures) |
| Flutter | `testing/backend_fakes` | test | faux backend : acte 2 avec `actions`, route `/canvas/actions`, séquence de l'acte 3 depuis les fixtures |
| Tests | `backend/orchestrator/acceptance/`, `apps/genesis_canvas/test/acceptance/` | acceptation | `act3_interact_test.go` (tag `acceptance`), `acte3_interagir.feature` (+ steps) |

## Contrats
- **Route (D1)** : `POST /canvas/actions`, corps `{"action":"block_release","surface":"actions"}` (≤ 1 Kio, JSON objet, deux clés chaînes ; toute clé en plus → 400). Gardes dans l'ordre : `Host` (421), `Origin` présent (403), `Content-Type: application/json` (415), taille (413), JSON (400). Puis : action absente de l'ensemble des tags `action:*` des cartes connues ou surface qui ne la porte pas (422) ; aucune session ouverte (409 `{error:"no_session"}`) ; `Canvas.running > 0` ou action déjà en file (409 `{error:"busy"}`). Succès : **202** sans corps, le travail continue en arrière-plan (la file par session existante, profondeur 2). Jamais de détail d'erreur du fournisseur ni d'agent.
- **Session cible** : la session ouverte la plus récemment créée (le canevas est partagé ; une seule session voix à la fois en pratique). Publication du `plan`, de l'activité et de l'A2UI dans cette session. `delegation` n'est pas publié (pas de délégation GPT-Live) ; le `plan` porte `delegation` = identifiant d'opération interne `act-<n>` (chaîne), jamais confondu avec un `delegation.id` du fournisseur.
- **Plan d'action (D4)** : `selected` = les agents dont les tags contiennent `action:<nom>` (en pratique Livraison), `idle` = les autres ; sélection vide → 422 avant tout message. Le message A2A porte `metadata["genesis/action"] = {"name": <nom>, "surface": <id>}` + `genesis/activeSurfaces` ; le texte est vide. Aucun champ du client (contexte de l'événement, données de surface) n'est relayé.
- **Agent Livraison (D3)** : action `block_release` → un `updateDataModel` `{surfaceId:"checklist", path:"/checklist/decisionStatus", value:"Bloquée"}` ; `validate_release` → `"Validée"` (libellés de `dataset.json`). Résumé factuel, dit à la voix après `completed` : « La release 3.4 est bloquée. » / « La release 3.4 est validée. » (formulé depuis le libellé du jeu de données ; le résumé ne cite ni chiffre ni recommandation, que l'agent sans état ne connaît pas).
- **Acte 2 (D2)** : Livraison, vue plateforme (Android ou iOS), si `actions` ∉ `ActiveSurfaces` : ajoute à la mutation de la checklist `createSurface(actions)` → `updateComponents` (`ActionBar` plat, `data:{path:"/actions"}`) → `updateDataModel("/actions", {title:"Décision", actions:[{id:"block_release",label:"Bloquer la release",tone:"danger"},{id:"validate_release",label:"Valider la release",tone:"neutral"}]})`. Vue globale (acte 1) : pas de barre. `kit.SurfaceMessages` fournit déjà la création conditionnelle.
- **A2UI** : la liste blanche `A2UI_COMPONENTS` du compose passe à 5 ; propriétés admises `id`, `component`, `data` ; l'orchestrateur n'accepte `updateDataModel` que sur une surface active du même agent (déjà vérifié) — les sous-chemins sont déjà des JSON Pointers valides (Go et Dart).
- **Voix (D5)** : `Sideband.Announce(ctx, text)` : (1) `session.commentary.append` rattaché à la dernière `delegation.id` de la session (mémorisée par `app/voice`), attente de l'acquittement ; (2) si erreur d'acquittement : `session.instructions.append` avec une consigne de dire le texte tel quel ; après chaque envoi accepté, attente bornée (`VOICE_ANNOUNCE_TIMEOUT`, 4 s) d'un `EventOutputTranscriptDelta` ; aucun : stratégie suivante ; aucune : `slog` + `nil` (pas d'erreur fatale). Une seule annonce par action, jamais après `Close`.
- **App, clic (D6)** : `ActionBar` appelle `itemContext.dispatchEvent(UserActionEvent(name: id, sourceComponentId, context: {}))` ; `Surface` le propose à un `ActionDelegate` fourni par `CanvasBoard` qui envoie `ActionRequested(name, surfaceId)` au `CanvasActionBloc` (retour `true` : géré, rien n'est renvoyé à un LLM, aucun `Conversation`). **Risque** : si l'API `actionDelegate` n'existe pas telle quelle en 0.10.4, repli = écoute de `SurfaceController.onSubmit` dans `features/canvas` (voir T15). `CanvasActionBloc` : `droppable()` ; états `Idle`, `Sending(name)`, `Failed(reason)` ; `ActionBar` lit l'état pour désactiver les boutons (état passé par le conteneur, pas de `getIt` dans le widget).
- **Rejeu** : `A2uiGate.replayEvents` rejoue `raw` ; l'asset `act3-replay.jsonl` = actes 1 et 2 + `act2-actions` + `act3-block`, artefact dérivé relu par un test.

## Repli connu (à déclencher par T15 seulement si son test échoue)
Si le `BoundObject` de `/checklist` ne se reconstruit pas sur l'écriture de `/checklist/decisionStatus` : la checklist lit `decisionStatus` par une seconde liaison (`BoundString` sur le sous-chemin), le contrat l'exprime (`binding.decisionStatus`) ; sinon l'agent réécrit le chemin entier à partir d'une vue conservée dans la donnée de la Barre d'actions (champ opaque `view`). Le choix est consigné dans `status.md` ; il ne change ni le scénario S-03 ni la route.

## Références
- `product/architecture/agents-protocols.md` § Acte 3 ; `app-channel-contract.md` (§ Remise à vide : modèle de la route) ; `security.md` (§ Confirmation, § Action exécutée par le client) ; `frontend-screen.md` (§ Flux unique, § Remise à vide, § Acte 2) ; `backend.md` (orchestrateur, registre) ; `functional/dataset-acts.md` § Acte 3.
- Notes `knowledge/` : [genui-user-actions], [genui-a2ui-security], [genui-data-model], [genui-custom-catalog-item], [ma-real-tool-results], [rt-gpt-live-delegation], [rt-gpt-live-sideband], [rt-gpt-live-lifecycle], [proto-a2a-task-lifecycle], [test-bdd-widget-test].

## Risques
- La voix ne dit rien hors délégation (Q-75) → stratégies ordonnées testées avec un faux sideband, repli honnête, essai réel unique pour trancher ; ne jamais fabriquer de transcript.
- Mise à jour par sous-chemin sans effet sur le rendu → test d'abord (T05), repli ci-dessus.
- `actionDelegate` absent ou différent en genui 0.10.4 → T15 lit le code du paquet verrouillé avant d'écrire ; repli `onSubmit`.
- Clic pendant une délégation en cours ou deux clics rapprochés → 409 `busy` côté backend, `droppable` + boutons inactifs côté app, tests C3.
- Création de `actions` casse les assertions de 008 → restreintes aux quatre surfaces, dans le même commit que la création (test d'abord, jamais d'assertion supprimée).
- Le registre refuse `createSurface` au-delà de 6 surfaces : 5 au plus ici ; test C2.
- Clic reçu après la fermeture de la session ou pendant la remise à vide → `no_session` / `busy` ; rien ne reste en file à la fermeture (`Close` annule l'action en cours, comme une délégation).
