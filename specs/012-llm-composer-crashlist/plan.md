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
