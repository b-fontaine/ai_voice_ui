# 012 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante. Go et Flutter peuvent avancer en parallèle (piles distinctes) ; `product/`, `specs/`, `docker-compose.yaml` : session principale seule. Go agents et Go orchestrateur : séquentiels (fichiers partagés).

## Gherkin
- [ ] T01 Go — acceptation (tag `acceptance`) agents C-01 à C-06 avec une passerelle simulée (`httptest`) · rouges : aucun appel à la passerelle ; pas de surface `crashes` ; pas de motif `view_unavailable`
- [ ] T02 Go — acceptation orchestrateur C-07 (passerelle) et C-08 (bout en bout simulé) · rouges : écouteur absent ; `crashes` refusé par la liste blanche
- [ ] T03 Flutter — `acte_crashlist.feature` F-01, F-02 · rouges : composant `CrashList` inconnu du catalogue fermé ; étagère « inutilisé »

## Contrat et données (session principale)
- [ ] T10 Go — jeu de données : `crashes` (5 lignes de `dataset.md`), `TopCrashes`, contrôles de cohérence · `dataset_test.go` (ordre, filtre de plateforme, bornes)
- [ ] T11 contrat — `catalog.json` : `CrashList` dans `components` (6), définition, `dataModel` ; fixtures `crashlist-*.jsonl` ; négatives ; README ; `docker-compose.yaml` `A2UI_COMPONENTS` · `check-compose.sh` et tests de parité rouges avant la mise à jour

## TDD Go — orchestrateur (séquentiel)
- [ ] T20 Go — `domain.LlmRequest/LlmResult`, port `LlmText`, adaptateur `openaitext` (délai, jetons, erreurs fermées, clé jamais journalisée) · `provider_test.go` (serveur factice, délai, 4xx/5xx, corps énorme)
- [ ] T21 Go — passerelle `llmgateway` (route, bornes, débit, `no-store`, `disabled` si modèle vide) · `gateway_test.go` (table de rejets C-07)
- [ ] T22 Go — `bootstrap` : `LLM_GATEWAY_ADDR`, `COMPOSER_*`, second `http.Server` et arrêt propre · `config_test.go`, `main_test.go`
- [ ] T23 Go — `A2UI_COMPONENTS` à 6 composants en test de bout en bout (C-08), `TagPlanner` : tags « liste », « list », « top » sur Qualité · `planner_test.go`
- [ ] T24 compose — `docker-compose.yaml` (écouteur interne, `COMPOSER_*`, `COMPOSER_LLM_URL` des agents) et `check-compose.sh` · script rouge sur : `env_file` d'un agent, port publié, URL hors réseau interne

## TDD Go — agents (séquentiel)
- [ ] T30 Go — `kit` : `Intent.View`, `ParseIntent` (« liste des crashs » et variantes), `ReasonViewUnavailable`, tag de profil · `scope_test.go` (tables)
- [ ] T31 Go — builders Qualité (`KeyIndicator`, `TrendChart`, `CrashList`) et composeur déterministe réécrit dessus, sorties identiques aux fixtures · tests existants verts + `crashlist_test.go`
- [ ] T32 Go — `llmcompose` : `Plan`/`Refusal`, `Validator`, `FallbackReason` · `validator_test.go` (listes fermées, tailles)
- [ ] T33 Go — `llmcompose.Client` (HTTP, un essai, délai) et `Composer` (plan → builders ; repli ; contexte annulé) · `composer_test.go` (C-01 à C-05 en unitaire)
- [ ] T34 Go — `Prompt` : consignes et écrans d'exemple extraits des fixtures (demande → plan, sans valeurs) · test d'instantané du prompt et d'absence de valeurs
- [ ] T35 Go — builders et `llmcompose` pour Voix du client et Livraison (actions déterministes) · tests de profil et d'équivalence
- [ ] T36 Go — câblage des `main` des agents (`COMPOSER_LLM_URL`, `COMPOSER_TIMEOUT`, absent = déterministe) et motifs de repli journalisés · `main_test.go`
- [ ] T37 Go — consignes vocales (`voice-instructions.fr.md`) : la liste des crashs existe, vue inconnue refusée avec alternative · test du texte

## TDD Flutter
- [ ] T40 Flutter — `genesis_contract.dart` : `CrashList` dans `components`, schéma, parité Go/Dart sur les fixtures positives et négatives · `genesis_contract_test.dart`
- [ ] T41 Flutter — `CrashList` (`CatalogItem`, `BoundObject`, trois états, texte ≥ 24 px, ellipse d'une ligne) et enregistrement dans `genesis_catalog.dart` · `genesis_catalog_test.dart`, goldens
- [ ] T42 Flutter — grille : `crashes` en 5ᵉ cellule (3×2), cellules existantes inchangées ; étagère « utilisée » · `canvas_board_test.dart`, `catalog_shelf_bloc_test.dart`
- [ ] T43 Flutter — faux backend et rejeu : fixture `crashlist-*` dans le mode scénario, panneau du protocole · `acte_crashlist` vert

## Mesure et vérification réelle
- [ ] T50 Go — `cmd/composer-bench` (agents) : p50/p90, validité, coût · test d'unité de l'agrégation (faux client)
- [ ] T51 manuel payant — exécuter T50 une fois sous `openai-budget.sh` (estimation d'abord), fixer `COMPOSER_MODEL` (ou déclarer le repli définitif) et verser le fait dans `knowledge/` (kb-curate)
- [ ] T52 conditionnel — si le p90 du premier squelette > 1,5 s : `Anticipate` (squelette déterministe avant l'appel) · test d'ordre des messages

## Clôture
- [ ] T90 product — scénarios `features/llm-composer-012.feature`, corrections de pdr-0014, `catalog.md`, `dataset.md`, `backend.md`, `security.md`, `agents-protocols.md`, `quality.md`, roadmap/backlog, `open-questions.md`
