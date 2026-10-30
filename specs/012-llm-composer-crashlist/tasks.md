# 012 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante. Go et Flutter peuvent avancer en parallèle (piles distinctes) ; `product/`, `specs/`, `docker-compose.yaml` : session principale seule. Go agents et Go orchestrateur : séquentiels (fichiers partagés).

## Gherkin
- [x] T01 Go — acceptation (tag `acceptance`) agents C-01 à C-06 (C-06 en deux variantes) avec une passerelle simulée (`httptest`) · rouges : aucun appel à la passerelle ; pas de surface `crashes` ; pas de motif `view_unavailable`
- [x] T02 Go — acceptation orchestrateur C-07 (passerelle) et C-08 (bout en bout simulé) · rouges : écouteur absent ; `crashes` refusé par la liste blanche
- [x] T03 Flutter — `acte_crashlist.feature` F-01, F-02 · rouges : composant `CrashList` inconnu du catalogue fermé ; étagère « inutilisé »

## Contrat et données (session principale)
- [x] T10 Go — jeu de données : `crashes` (5 lignes de `dataset.md`), `TopCrashes`, contrôles de cohérence · `dataset_test.go` (ordre, filtre de plateforme, bornes)
- [x] T11 contrat — `catalog.json` : `CrashList` en dernier dans `components` (6), définition, `dataModel` ; fixtures `crashlist-global.jsonl`, `crashlist-android.jsonl` (pas de nouvelle négative, A8) ; README ; `docker-compose.yaml` `A2UI_COMPONENTS` et son commentaire ; `genesis_contract_test.dart` (6), docstring de `genesis_contract.dart`, `genesis_fixtures_test.go` · `check-compose.sh` et tests de parité rouges avant la mise à jour

## TDD Go — orchestrateur (séquentiel)
- [x] T19 savoir — vérifier la doc officielle de l'API Responses (sortie structurée, `store`, effort de raisonnement, `incomplete`) et créer la note `knowledge/` (kb-curate) avant T20 · `kb_lint.py` vert
- [x] T20 Go — `domain.LlmRequest/LlmResult`, port `LlmText`, adaptateur `openaitext` (Responses, `store: false`, aucun outil, effort configurable, `incomplete` = erreur fermée, délai, jetons, clé et contenu jamais journalisés, jetons `usage` journalisés) · `provider_test.go` (serveur factice, délai, 4xx/5xx, corps énorme)
- [x] T21 Go — passerelle `llmgateway` (route, `RemoteAddr` autorisée, `Host` 421, `Origin` 403, 415, `DisallowUnknownFields`, schéma et champs bornés, débit, `no-store`, `disabled` si modèle vide, appel amont sous `r.Context()`, délais du serveur) · `gateway_test.go` (table de rejets C-07)
- [x] T22 Go — `bootstrap` : `LLM_GATEWAY_ADDR`, `LLM_GATEWAY_ALLOWED_SOURCES`, `COMPOSER_*`, second `http.Server`, arrêt conjoint des deux serveurs (`errors.Join`) · `config_test.go`, `main_test.go`
- [x] T23 Go — `A2UI_COMPONENTS` à 6 composants en test de bout en bout (C-08) ; `TagPlanner` inchangé (cas « la liste des avis » → Voix seule, « liste des crashs » → Qualité) · `planner_test.go`
- [x] T25 Go — `view_unavailable` dans `scopeReasons`, phrase `failure_rejected_view`, choix de la phrase par `ScopeReason` quand tous les agents refusent · `pipeline_scope_reason_test.go`, `phrases_test.go`
- [x] T24 compose — `docker-compose.yaml` (`ipam` et `ipv4_address` fixes, écouteur interne, ancre `COMPOSER_TIMEOUT`, `COMPOSER_*`, `COMPOSER_LLM_URL` par agent, service `composer-bench` sous le profil `bench` : reporté en T50, quand `cmd/composer-bench` existe), règles de `check-compose.sh` (A5) et auto-test `backend/check-compose-selftest.sh` · surcharges `backend/testdata/compose-bad-*.yaml` qui doivent faire échouer le script (`env_file`, port publié, URL hors réseau, délais incohérents, `OPENAI_*` chez un agent)

## TDD Go — agents (séquentiel)
- [x] T30 Go — `kit` : `Intent.View` (hors metadata `genesis/intent`), `ParseIntent` (« liste des crashs » et variantes ; lexique fermé de vues inconnues → `view_unavailable`), la liste ne déplace pas le focus et n'en hérite pas · `scope_test.go` (tables)
- [x] T31 Go — builders Qualité (`KeyIndicator`, `TrendChart`, `CrashList` : rang renuméroté, titre, `count` 1 à 5) et composeur déterministe réécrit dessus, sorties identiques aux fixtures · tests existants verts + `crashlist_test.go`
- [x] T32 Go — `llmcompose` (rangé dans `shared` de `arch_test.go`) : `Plan` sans champ `surface`/`Refusal`, `Validator` (table de décision A2), `FallbackReason` · `validator_test.go` (listes fermées, tailles, `ActionBar` refusée, acte 1 à 5 surfaces refusé, plateforme contradictoire)
- [x] T33 Go — couture `emit` de `kit.Composer`/`executor` (A1) ; `llmcompose.Client` (URL validée, `CheckRedirect`, corps borné, un essai, délai) et `Composer` (`ParseIntent` avant l'appel, plan → builders, surfaces actives rafraîchies, repli, parent annulé ≠ délai) · `composer_test.go` (C-01 à C-05, `Summary` comparé), `executor_test.go` (ordre inchangé)
- [x] T34 Go — `Prompt` et `internal/llmcompose/examples.json` embarqué (demande → plan, sans valeurs ; préfixe statique) · test qui rejoue chaque plan d'exemple par les builders et compare aux fixtures `act1-*`, `act2-*`, `correction-ios-*`, `crashlist-*` ; test d'absence de valeurs
- [ ] T35 Go — builders pour Voix du client et Livraison ; modèle branché dessus **seulement si la mesure par agent (T51) le justifie** (actions toujours déterministes) · tests de profil et d'équivalence
- [x] T36 Go — `kit.Main` prend une fabrique `func(Settings, *slog.Logger) (Composer, error)` ; `Settings.ComposerLLMURL`/`ComposerTimeout` ; décoration dans `cmd/agent-*/main.go` (absent = déterministe) ; motifs de repli journalisés · `env_test.go`, `main_test.go`
- [x] T37 Go — consignes vocales (`voice-instructions.fr.md`) : la liste des crashs existe, vue inconnue refusée avec alternative (après T25) · test du texte

## TDD Flutter
- [x] T40 Flutter — `genesis_contract.dart` : `CrashList` dans `components`, schéma, parité Go/Dart sur les fixtures positives et négatives · `genesis_contract_test.dart`
- [x] T41 Flutter — `CrashList` (`CatalogItem`, `BoundObject`, trois états, texte ≥ 24 px, libellé sur deux lignes au plus puis ellipse ; ligne incomplète → état neutre) et enregistrement dans `genesis_catalog.dart` · `genesis_catalog_test.dart`, goldens
- [x] T42 Flutter — grille à parent unique (`CustomMultiChildLayout` ou `Stack`), `crashes` en 5ᵉ cellule (3×2) ; `State` des quatre `Surface` conservés (`same(state)`) ; étagère « utilisée » · `canvas_board_test.dart`, `catalog_shelf_bloc_test.dart`
- [x] T43 Flutter — faux backend et rejeu : fixture `crashlist-*` dans le mode scénario, panneau du protocole · `acte_crashlist` vert
- [x] T44 Flutter — lisibilité de `CrashList` à 1920×1080 (capture `crashlist-replay`) : libellé sur UNE ligne avec ellipse, plateforme et volume à droite, `sessions` conservé dans les données mais non affiché (D10) ; scénarios F-02 et tests ajustés · rouge : `maxLines: 2`, « N sess. » encore affichés

## Mesure et vérification réelle
- [x] T50 Go — `cmd/composer-bench` (agents, dans le réseau `agents`) : p50/p90 au premier octet et au total, par agent ; validité ; taux d'accord avec le plan attendu ; coût · test d'unité de l'agrégation (faux client)
- [x] T51 manuel payant — exécuter T50 une fois sous `openai-budget.sh` (estimation d'abord), fixer `COMPOSER_MODEL` (ou déclarer le repli définitif) et verser le fait dans `knowledge/` (kb-curate)
- [ ] T52 conditionnel — si p90 de la base 011 + p90 de la passerelle > 1,5 s : squelette du plan déterministe émis avant l'appel (via `emit`) ; plan du modèle à surfaces différentes = `invalid_plan` ; jamais de `deleteSurface` · tests d'ordre des messages et d'absence de `deleteSurface`

## Clôture
- [ ] T90 product — scénarios `features/llm-composer-012.feature`, corrections de pdr-0014, `catalog.md`, `dataset.md`, `backend.md`, `security.md`, `agents-protocols.md`, `quality.md`, roadmap/backlog, `open-questions.md`
