# 007 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = parallélisable avec une tâche d'une **autre pile** sans fichier partagé. Pile « Go » et pile « Flutter » séparées ; les tâches Flutter se font **une à la fois** (même pile).

## Préparation
- [ ] T01 Flutter — paquets `entities/catalog`, `shared/design_system`, `features/protocol_feed`, `features/catalog_shelf`, `features/stage_controls` (squelettes dans le workspace, `analysis_options`, barrels, règle d'import testée) · test d'abord : tests de dépendances (`dependency_rules_test`) rouges tant que les paquets n'existent pas
- [ ] T02 Flutter — fixtures : le faux backend et `assets/replays/act1-replay.jsonl` lisent `contracts/a2ui/genesis/v1/examples/*.jsonl` (`${CATALOG_ID}` substitué textuellement, partout) ; `plan` et trois `agent.activity` ajoutés ; route `POST /canvas/reset` enregistrée · test d'abord : `fake_backend_test` (fixtures conformes au contrat, requête de remise à vide comptée)

## Gherkin (acceptation Flutter, `bdd_widget_test` ; Go avec le tag `acceptance`)
- [ ] T03 Flutter — S-01 (acte 1 : transcription, rail, squelette avant données, quatre surfaces complètes), A1 (rail et choix), A2 (panneau, pointillé, étagère « 4 / 6 »), A3 (validation côté client), A4 (remise à vide), A5 (état neutre) : rouges pour la bonne raison ; migration de V1 à V5bis et H-01 à H-03 vers les fixtures `genesis`, **mêmes assertions** · test d'abord : sortie rouge citée dans `status.md`
- [ ] T04 [P] Go — G7 : `POST /canvas/reset` avec deux surfaces actives → `deleteSurface` (agent `orchestrateur`) pour chacune, registre vide, une nouvelle délégation recrée les quatre surfaces ; 204 idempotent ; `Host` non autorisé → 421 · test d'abord : route absente (404) ; `go test -tags acceptance`

## TDD
- [ ] T10 Flutter — `GenesisCatalog` : `KeyIndicator` de bout en bout (liaison `data: {path}`, squelette, état neutre, statut → couleur du thème, texte ≥ 24 px) ; fixe le mécanisme de liaison pour les autres · test d'abord : `genesis_catalog_test` (fixture kpi dans le moteur : squelette puis valeur « 99,57 % »), `scene_theme_test` (contrastes AA)
- [ ] T11 Flutter — `TrendChart` (`CustomPainter` : séries 3.3 / 3.4, ligne de seuil, `days`, bornes `yMaxPct`), `ReviewSentiment` (répartition + 3 extraits), `ReleaseChecklist` (items, `recommendation`, `decisionStatus`) ; états squelette et neutre pour chacun · test d'abord : un test par item sur sa fixture + données incomplètes + code de statut inconnu
- [ ] T12 Flutter — `GenesisMessageValidator` et son branchement avant `CanvasBloc` ; `catalogs: [genesisCatalog]` dans l'app ; `GENESIS_CATALOG_ID` · test d'abord : `genesis_message_validator_test` (table : composant hors liste, propriété inconnue, littéral à la place de `{path}`, `catalogId` différent, 7ᵉ surface, message trop gros), `contract_fixtures_test` (les quatre fixtures passent validateur et moteur)
- [ ] T13 Flutter — entités `PlanReceived` / `rejected` et conversion des enveloppes ; `AgentActivityBloc` : roster (orchestrateur + 3 rôles), `plan`, « en veille », « aucun agent retenu », remise à zéro · test d'abord : `session_event_converter_test`, `agent_activity_bloc_test`
- [ ] T14 Flutter — `ProtocolFeedBloc` (entrées, mise en évidence, déplié/replié, bornes, effacement) et `CatalogShelfBloc` (utilisés / libérés / vidés, compteur) · test d'abord : un test par évènement, y compris `deleteSurface` et message refusé
- [ ] T15 Flutter — `StageBloc` (acte 1 à 3, remise à vide) et `HttpCanvasResetClient` (`POST /canvas/reset`, échec silencieux journalisé, délai) · test d'abord : `stage_bloc_test`, `http_canvas_reset_client_test` (faux serveur local réel)
- [ ] T16 Flutter — widgets : `protocol_panel`, `catalog_shelf`, `replay_bar` (emplacement), `stage_bar` (acte + remise à vide), rail enrichi, `CanvasBoard` (grille 2 × 2, cerclage pointillé D2) ; page à six zones et fermeture ordonnée des nouveaux Blocs · test d'abord : un test de widget par zone + `genesis_canvas_page_composition_test` étendu ; `layer_imports_test` vert
- [ ] T17 [P] Go — route `POST /canvas/reset` : port `Canvas` de l'orchestrateur (liste des surfaces actives, retrait + publication des `deleteSurface`), handler `httpapi`, câblage `cmd` · test d'abord : tests unitaires du registre/pipeline et du handler (G7 de T04 vert)

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert (Flutter + Go)
- [ ] T91 Revue architect-reviewer (mode CODE) et refactorisations par lots
- [ ] T92 Vérification : `gate --full`, `app-smoke.sh` (capture à lire), essai réel unique si le budget le permet ; clôture : docs `product/` (frontend, screen, catalog, security, app-channel-contract, roadmap, backlog), fusion, `publish.sh`, `fresh_session`
