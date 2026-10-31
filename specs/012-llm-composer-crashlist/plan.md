# 012 — Plan

Références : [pdr-0074](../../product/decisions/pdr-0074-012-llm-composer-gateway-crashlist-details.md), [p-ar-backend](../../product/architecture/backend.md), [p-ar-security](../../product/architecture/security.md), [p-ar-agents-protocols](../../product/architecture/agents-protocols.md), [p-fn-catalog](../../product/functional/catalog.md), [p-fn-dataset](../../product/functional/dataset.md) (§ Liste des crashs). Faits techniques à relire avant le code : `rt-ephemeral-keys`, `genui-custom-catalog-item`, `genui-data-model`, `test-mock-boundaries-only` (kb-lookup).

## Architecture

```
agent (Qualité | Voix | Livraison)         orchestrateur (seul détenteur de la clé)
  kit.Executor ─ Compose ─▶ llmcompose.Composer ──HTTP interne──▶ passerelle LLM ──▶ out.LlmText ──▶ OpenAI
                      │        (plan structuré)    réseau `agents`   (bornes, débit)        (adaptateur)
                      ├─ valide le plan (profil, listes fermées)
                      ├─ construit les data models depuis le jeu de données (Builder)
                      └─ erreur / plan invalide / délai ─▶ composeur déterministe (repli, motif fermé)
```

### Unités (Go)
- **Orchestrateur** : `domain.LlmRequest{Instructions, Input, SchemaName, Schema}` / `LlmResult{JSON}` ; port `port.LlmText.Complete(ctx, req)` ; adaptateur `adapter/openaitext` (HTTP, délai, plafond de jetons, clé jamais journalisée, erreurs fermées) ; `adapter/llmgateway` (second `http.Server` : `POST /v1/complete`, méthode et chemin stricts, `Content-Type` JSON, corps ≤ `COMPOSER_MAX_REQUEST_BYTES`, schéma objet requis, limiteur de débit, `Cache-Control: no-store`, journal sans contenu) ; `bootstrap` : `LLM_GATEWAY_ADDR`, `COMPOSER_MODEL` (vide : passerelle répond 503 `disabled`), `COMPOSER_TIMEOUT`, `COMPOSER_MAX_OUTPUT_TOKENS`, `COMPOSER_RATE_BURST|WINDOW`, `COMPOSER_MAX_REQUEST_BYTES`.
- **Agents** : `internal/llmcompose` — `Plan{Surfaces[]{Surface, Component, Params}}` ou `Refusal{Reason}` ; `Client` (port `Completer`, adaptateur HTTP vers `COMPOSER_LLM_URL`, un seul essai, délai `COMPOSER_TIMEOUT`) ; `Validator` (profil de l'agent : composants autorisés, paramètres de listes fermées, 1 à N surfaces) ; `Prompt` (consignes + écrans d'exemple extraits des fixtures sous forme demande → plan ; les valeurs ne sont jamais montrées au modèle) ; `Composer` (décorateur de `kit.Composer` : plan → `Builder` → messages ; sinon repli) ; `FallbackReason` (ensemble fermé : `disabled`, `timeout`, `transport`, `rate_limited`, `invalid_json`, `invalid_plan`, `refused_unknown`).
- **Builders** par agent (`quality`, `voice`, `delivery`) : pour chaque composant du profil, fonction pure `(Params, Dataset) → (value, summary)`. Le composeur déterministe actuel est réécrit **sur ces mêmes builders** (une seule source des valeurs) : le plan déterministe de l'acte 1 (vue globale) est donc le plan « par défaut » que le modèle doit retrouver (C-01).
- **Kit** : `Intent.View` (fermé : `""`, `crashlist`), reconnu par `ParseIntent` (« liste des crashs », « crash list », « top crashs », « principaux crashs »), `ReasonViewUnavailable`, tag de profil, motifs relayés comme aujourd'hui.

### Contrat et données (CrashList)
- `dataset.json` : `crashes` = 5 lignes de [p-fn-dataset](../../product/functional/dataset.md) (libellé, plateforme, volume, sessions) ; accesseur `TopCrashes(version, platform, limit)` ; contrôles de cohérence (somme ≤ crashs journaliers, ordre décroissant).
- `catalog.json` : `CrashList` entre dans `components` (6), définition `surface: crashes`, `dataModel.path: /crashes` `{title, items[{rank, label, platform, volume, sessions}]}` ; `docker-compose.yaml` `A2UI_COMPONENTS` et `check-compose.sh` suivent ; fixtures `examples/crashlist-global.jsonl`, `crashlist-android.jsonl` ; négatives (`items` mal typé, ligne sans libellé, composant avec propriété inconnue) ; parité Go/Dart (`genesis_contract.dart`).
- Flutter : `CrashList` (`CatalogItem` lu par `BoundObject`, comme `ReviewSentiment`) ; trois états ; liste de lignes `Row` (rang, libellé sur une ligne avec ellipse, plateforme, volume), texte ≥ 24 px ; placement : `crashes` est la 5ᵉ surface de la grille (3×2) ; l'étagère passe de « 5/6 » à « 6/6 » seulement si `crashes` existe.

### Mesure (D4, D8)
Outil `cmd/composer-bench` (agents) : N demandes types × répétitions, via la passerelle réelle ; sort p50/p90, taux de plans valides, coût estimé ; exécuté **une fois** sous `openai-budget.sh`, résultat versé dans `knowledge/` (kb-curate) et dans `status.md`. Le critère de repli est celui de pdr-0060/0074.

## Sécurité
- La clé reste dans l'orchestrateur ; les agents n'ont ni `env_file` ni clé ni sortie réseau ; le port de la passerelle n'est **pas publié** ; `check-compose.sh` vérifie : agent sans `env_file`, port non publié, `COMPOSER_LLM_URL` pointant l'orchestrateur sur le réseau `agents`.
- La passerelle n'est pas un proxy ouvert : endpoint, modèle, jetons et taille fixés par l'orchestrateur ; seul le schéma de sortie et le texte viennent de l'agent ; débit limité (budget pdr-0030).
- Le texte de la demande du speaker est de l'entrée non fiable : il est borné (1 000 runes déjà), placé dans le champ `Input` (pas dans `Instructions`), et le plan est de toute façon validé contre des listes fermées (injection sans effet : au pire, repli).
- Aucun contenu de demande ni de sortie du modèle dans les journaux ; seuls les motifs fermés.

## Cycle de vie et erreurs
Un appel par composition, annulé avec le contexte de la tâche (« Stop », 011) ; aucune goroutine détachée ; `http.Client` à délai ; arrêt propre du second écouteur avec le premier ; pas d'état partagé entre appels (composeurs sans état, sûrs en concurrence). Repli : jamais de second appel au modèle, jamais d'erreur remontée à l'utilisateur si le déterministe réussit.

## Ordre et parallélisme
Contrat et données d'abord (tâches partagées, session principale), puis Go orchestrateur (passerelle) en séquence, Go agents (séquence, fichiers partagés `kit`), Flutter (CrashList) en parallèle de Go à partir du contrat. `docker-compose.yaml`, `product/`, `specs/` : session principale seule.

## Risques
| Risque | Parade |
|---|---|
| Latence du modèle > NFR-02/03 | repli, T-skel conditionnel (D8), mesure avant de fixer le modèle |
| Plan incohérent entre exécutions (NFR-08) | valeurs figées par les builders ; plans validés ; test C-01 sur la sortie |
| Coût | plafond de débit, jetons bornés, mesure unique, essai réel unique |
| Prompt trop long | exemples compacts (couples demande → plan), pas de valeurs |
| Nouvelle surface interne | écouteur non publié, bornes, tests C-07 |

## Amendements de la revue du plan (A1 à A8) — prioritaires sur le texte ci-dessus

Verdict PLAN de l'architecte : **À AMENDER** (3 bloquants, 4 importants, 1 mineur ; 3 conflits signalés).

**A1 — Couture d'émission progressive et critère de latence calculable.**
- `kit.Composer.Compose` gagne une fonction d'émission : `Compose(ctx, req, ds, emit func(map[string]any) error) (Composition, error)`. L'exécuteur émet au fil de l'eau (un `status-update` par message) ; ordre et contenu inchangés (fixtures). Cette couture est posée en T33, avant toute mesure.
- Règle de T52 (squelette anticipé), fixée maintenant : le squelette part du **plan déterministe** (`ParseIntent`) ; un plan du modèle dont l'ensemble de surfaces diffère de l'ensemble anticipé est `invalid_plan` (repli) ; **jamais de `deleteSurface` correctif**. Tests : ordre des messages, absence de `deleteSurface`.
- `composer-bench` mesure p50/p90 de la passerelle au premier octet et au total, **par agent** ; T51 additionne le p90 de la base 011 (horloge de l'app, pdr-0038) et celui de la passerelle et le compare à 1,5 s (NFR-02) et à 8 s (NFR-03). Le banc tourne **dans** le réseau `agents` : service compose sous le profil `bench` (`docker compose --profile bench run --rm composer-bench`).

**A2 — Autorité de `ParseIntent` et table de décision.**
| Sujet | Règle |
|---|---|
| Surface d'un composant | déduite de `definitions[component].surface` ; `Plan.Surfaces[]` n'a pas de champ `surface` |
| Version, plateforme, comparaison, focus, refus existants | `ParseIntent` s'exécute **avant** l'appel et reste seul juge ; un plan dont la plateforme ou la comparaison diffère est `invalid_plan` |
| Composants choisissables | Qualité : `KeyIndicator`, `TrendChart`, `CrashList` ; Voix du client : `ReviewSentiment` ; Livraison : `ReleaseChecklist`. **`ActionBar` n'est jamais choisi par le modèle** (règle déterministe de `delivery/composer.go`, pdr-0061) |
| Surfaces actives | toute surface active de l'agent est rafraîchie par l'Intent même si le plan l'omet ; tous les messages passent par `kit.SurfaceMessages` (jamais de `createSurface` pour une surface active) |
| Acte 1 | exactement les quatre surfaces de pdr-0020 : CrashList n'y est pas choisie (plan à 5 surfaces à l'acte 1 = `invalid_plan`) |
| Plan valide mais différent du plan attendu | accepté (pdr-0023) ; T50 mesure le **taux d'accord** avec le plan attendu par demande type (acte 1, Android + comparaison 3.3, « plutôt iOS », liste globale, liste Android, vue inconnue) ; seuil 100 % sur le script recommandé, sinon repli définitif déclaré |
| `Intent.View` | **hors** de la metadata `genesis/intent` (`intentFrom` rejette `len(raw) != 2`) ; « liste des crashs » ne déplace pas le focus (`Composition.Intent` = nil pour `crashlist`) ; la liste **n'hérite pas** du focus (global sans plateforme nommée) |
| Annulations | parent annulé (« Stop », 011) → retour `ctx.Err()`, ni repli ni journal `fallback` ; `COMPOSER_TIMEOUT` (contexte enfant) → repli `timeout` |
- C-01 compare aussi `Summary`. Tests d'équivalence « plan simulé → builders = fixtures » pour `act1-*`, `act2-*`, `correction-ios-*`, `crashlist-*`.

**A3 — Le refus honnête doit atteindre la voix.**
- Nouvelle tâche orchestrateur (T25) : `view_unavailable` ajouté à `scopeReasons` (`a2aclient/agent.go`) ; phrase `failure_rejected_view` dans `phrases.fr.json` (validée par `phrases.go`) ; `pipeline.go` choisit la phrase selon le `ScopeReason` quand tous les agents refusent.
- Règle déterministe fermée de « vue inconnue » (T30) : un verbe d'affichage suivi d'un nom de vue d'un lexique fermé que le profil ne produit pas (« carte », « tableau », « camembert », « histogramme », « par pays »…) → `view_unavailable` ; sinon vue globale. C-06 tient donc sans modèle.
- Un `Refusal` du modèle de motif `view_unavailable` donne directement la `ScopeError` (sans repli) ; tout autre motif donne le repli `refused_unknown`. C-06 en deux variantes (avec modèle, en repli).

**A4 — Passerelle : joignable des seuls agents.**
- Compose : sous-réseau `ipam` fixe de `agents`, `ipv4_address` fixes ; `LLM_GATEWAY_ADDR` = IP de l'orchestrateur sur `agents` (pas `0.0.0.0`) ; la passerelle refuse toute `RemoteAddr` hors `LLM_GATEWAY_ALLOWED_SOURCES` (IP des agents).
- Gardes reprises de `/canvas/*` : `Host` égal à l'hôte de `COMPOSER_LLM_URL` (sinon 421), `Origin` présent → 403, `application/json` exigé (415), aucun en-tête CORS, `DisallowUnknownFields`.
- Schéma borné (taille, profondeur, `type: object`, `additionalProperties: false`) ; `Instructions` et `Input` bornés chacun. `Instructions` vient de l'agent (code du dépôt, de confiance) ; seule la demande du speaker est non fiable, placée dans `Input`.
- Appel amont avec `r.Context()` ; `http.Server` avec `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout` (> délai amont), `MaxHeaderBytes` ; dans `run()` les deux serveurs s'arrêtent ensemble (`errors.Join`), la chute de l'un arrête l'autre.
- OpenAI : `store: false`, aucun outil ; journal = statut, motif fermé, durée, jetons `usage` (entrée/sortie), jamais de contenu.
- Agent : `COMPOSER_LLM_URL` validée (http, sans identifiants, chemin fixe), `CheckRedirect` → `http.ErrUseLastResponse`, corps de réponse borné.

**A5 — Délais, débit, compose.**
- Ancre YAML unique pour `COMPOSER_TIMEOUT`. Règles de `check-compose.sh` : délai de l'agent ≥ délai de la passerelle + marge ; `COMPOSER_TIMEOUT` + repli < `AGENT_TIMEOUT` ; `COMPOSER_RATE_BURST` ≥ nombre d'agents ayant une `COMPOSER_LLM_URL` ; aucun `ports[].target` égal au port de la passerelle ; ni `OPENAI_*` ni `COMPOSER_MODEL` chez un agent.
- `tools/loop/` est interdit à la boucle : `check-compose.sh` n'étant lancé que par la CI GitHub (pas par `gate.sh`/`verify.sh`), un auto-test `backend/check-compose-selftest.sh` (surcharges `backend/testdata/compose-bad-*.yaml` qui doivent échouer) est ajouté et **signalé au porteur** (brancher sur `verify.sh --full`).
- `COMPOSER_LLM_URL` **par agent** ; le modèle est branché sur Qualité d'abord (trois choix possibles, dont CrashList) ; Voix et Livraison n'ont qu'un composant choisissable : branchés en T35 seulement si la mesure par agent le justifie (sinon déterministes, coût divisé par trois).

**A6 — Découpage des paquets.**
- `backend/agents/arch_test.go` : `internal/llmcompose` rangé dans `shared`, test qu'il n'importe aucun agent.
- `kit.Main` prend une fabrique `func(Settings, *slog.Logger) (Composer, error)` ; `Settings` porte `ComposerLLMURL` et `ComposerTimeout` (erreurs sans valeur) ; la décoration se fait dans `cmd/agent-*/main.go` (pas de cycle `kit` ↔ `llmcompose`).
- Le prompt ne lit pas `contracts/` : fichier embarqué `internal/llmcompose/examples.json` (demande → plan), plus un test qui rejoue chaque plan par les builders et compare aux fixtures (comme `quality/views_test.go`). Préfixe d'instructions statique (cache de prompt), contexte variable à la fin.
- Avant T20 : **vérifier la doc officielle de l'API Responses** (sortie structurée `text.format` `json_schema` strict, `store`, effort de raisonnement, statut `incomplete`) et créer la note `knowledge/` (kb-curate) ; effort de raisonnement configurable (`COMPOSER_REASONING_EFFORT`) ; `incomplete` classé dans les erreurs fermées (repli `transport`).
- T23 : les tags vivent dans `quality/profile.json`, pas dans `TagPlanner` : voir le conflit ci-dessous (aucun tag ajouté).

**A7 — Flutter.**
- `CanvasBoard` construit une `Row` par ligne : passer de 2×2 à 3×2 recrée les `State` de `reviews` et `checklist`. T42 adopte une **disposition à parent unique** (`CustomMultiChildLayout` + `LayoutId`, ou `Stack` + `Positioned`) ; F-01 : « position » = rang dans l'ordre de lecture ; test `same(state)` sur les quatre `Surface` à l'arrivée de `crashes` (modèle du test du bandeau).
- Libellés : ~~deux lignes au plus, puis ellipse~~ **une ligne puis ellipse** (D9 remplacée par D10 après la capture à 1920×1080 : cinq lignes de deux lignes ne tiennent pas dans 250 px) ; spec F-02, T41 et tests alignés (les libellés vont jusqu'à ~60 caractères).

**A8 — Contrat.**
- « items mal typé » et « ligne sans libellé » : tests de rendu Dart (état neutre, RG-10) et tests des builders Go, pas fixtures de refus (aucun validateur Go ne contrôle les valeurs ; `expected.json` = codes fermés). « Propriété inconnue » double `bad_property_unknown.jsonl` : pas de nouvelle négative.
- Mis à jour avec le contrat (T11) : `packages/entities/catalog/test/genesis_contract_test.dart` (`hasLength(5)` → 6), docstring de `genesis_contract.dart`, commentaire « 5 composants » de `docker-compose.yaml`, `genesis_fixtures_test.go`. `CatalogShelfBloc` gère déjà CrashList : T42 côté étagère = un test.
- Détails tranchés (pdr-0062, D9) : rang renuméroté 1..n après filtre ; titre `Principaux crashs · 3.4` (`· Android` / `· iOS` si filtré) ; `count` 1 à 5, 5 par défaut ; `CrashList` en dernier dans `components` (5ᵉ cellule).

**Conflits avec une décision, traités.**
- **D7 de pdr-0074 (tags « liste », « list », « top »)** : inutiles (« crash » suffit) et source de faux positifs (« la liste des avis » retiendrait Qualité). **Remplacée** : aucun tag ajouté, `TagPlanner` inchangé.
- **D8 face à pdr-0060** : l'anticipation du squelette est une voie intermédiaire entre « modèle » et « écrans fixes » ; elle est conditionnelle (T52) et bornée par A1 (surfaces anticipées = surfaces du plan). **À signaler au porteur** dans `status.md`, sans bloquer.
- **pdr-0023** : D2 reste compatible si « données » = sélection fermée à valeurs figées ; `ParseIntent` décidant la plateforme, le modèle choisit composants et `count`. Écrit tel quel dans pdr-0014 et `backend.md` à la clôture.
