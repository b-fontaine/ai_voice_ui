# AGENTS.md — ai_voice_ui

Application Flutter multi-agents. Elle réunit :
- un **orchestrateur** ;
- un **agent vocal** voice-to-voice temps réel (OpenAI `gpt-live-1` en WebRTC, ou Gemini Live via Firebase AI Logic) ;
- un **agent GenUI**, qui génère des écrans avec le package `genui` et le protocole A2UI ;
- des **outils**, exposés via MCP et A2A.

Le produit en cours de construction est **Genesis Canvas** (cas d'usage « Release Copilot ») : une démo de conférence Flutter desktop. Sa documentation fonctionnelle et technique est dans `product/` (voir § 1 bis).

## 1. Règle n°1 : consulter la base de connaissances AVANT d'agir

La base `knowledge/` est un zettelkasten : des notes markdown atomiques avec frontmatter YAML, plus des index YAML. Elle contient des faits **vérifiés et datés** (fin 2026) sur des API qui changent vite : modèles Live, `genui` en alpha, A2UI en pré-1.0. Ta mémoire d'entraînement est probablement obsolète sur ces sujets.

**Procédure obligatoire au début de chaque tâche, avant d'écrire du code ou un plan :**

1. Lire `knowledge/index.yaml` :
   - `tasks` associe un type de tâche aux ids des notes utiles ;
   - `entrypoints` liste les notes fondatrices ;
   - `keywords` sert au routage par domaine.
2. Ouvrir le `index.yaml` du domaine concerné, puis les notes listées. Suivre les `links` sur un niveau au plus.
3. Si l'index ne suffit pas, chercher par mot-clé : `grep -ril "<terme>" knowledge/ --include=*.md`, ou par tag dans `knowledge/tags.yaml`.
4. Citer les ids des notes utilisées dans le plan ou la réponse (par exemple `[rt-gpt-live-lifecycle]`).
5. Une note avec `status: opinion` est une recommandation interne. Elle n'a pas la valeur d'une doc officielle.
6. Si une note contredit la doc officielle actuelle, la doc gagne. **Corriger alors la note** (voir § 5).

Sous Claude Code, le skill `kb-lookup` automatise cette procédure.

## 1 bis. Règle n°1 bis : consulter la documentation produit (`product/`) AVANT d'agir

`product/` décrit tout ce qui est **propre à Genesis Canvas** : fonctionnel (exigences `FR-xx`/`NFR-xx`, règles `RG-xx`, écran, catalogue, scénarios Gherkin), roadmap (jalons, backlog, spikes, questions ouvertes `Q-xx`), architecture du produit et décisions produit (`pdr-*`). Porte d'entrée humaine : `product/README.md`.

**Frontière :**

| `knowledge/` | `product/` |
|---|---|
| Savoir **réutilisable** sur d'autres projets : faits vérifiés, patterns, décisions technologiques génériques (`adr-*`) | Ce qui est **spécifique** à Genesis Canvas ; cite les notes `knowledge/` par id au lieu de recopier les faits |

**Procédure obligatoire avant toute tâche fonctionnelle, d'architecture produit ou de planification** (en plus du § 1) :

1. Lire `product/index.yaml` : `tasks` associe une tâche type aux ids produit **et** aux ids `knowledge/` utiles ; `zones` route par mots-clés ; `requirement_index` dit où est défini un `FR-xx`, `RG-xx`, `Q-xx`….
2. Ouvrir le `index.yaml` de la zone (`functional/`, `architecture/`, `roadmap/`, `decisions/`), puis les documents listés. Suivre les `links` sur un niveau au plus.
3. Si l'index ne suffit pas : `grep -rn "<terme>" product/ --include=*.md --include=*.feature`.
4. Avant d'agir, vérifier dans `product/decisions/index.yaml` et `product/roadmap/open-questions.md` si le sujet est décidé ou encore ouvert. **Ne jamais trancher une question ouverte ni un écart entre sources** sans décision du porteur.
5. Citer les ids utilisés (`[p-fn-screen]`, `FR-13`, `pdr-0006-replay-fallback-must`, `Q-03`).

**Où écrire :**
- décision **propre au produit** (fonctionnelle ou technique) → `product/decisions/pdr-NNNN-<slug>.md` (gabarit `_template.md`, `next_id` de `decisions/index.yaml`) ;
- décision **réutilisable** sur d'autres projets → `knowledge/decisions/adr-NNNN-<slug>.md` (§ 4) ;
- question non tranchée, écart entre sources, hypothèse non confirmée → `product/roadmap/open-questions.md` (`Q-xx` suivante) ;
- tout autre contenu produit → la zone concernée, en respectant `product/_conventions.md` ; mettre à jour l'`index.yaml` de la zone (et `tasks` de `product/index.yaml` si une nouvelle tâche type apparaît).

**Contrôle :** `python3 -I product/_tools/product_lint.py` doit sortir sans erreur.

Sous Claude Code, les skills `product-lookup` (lire), `product-curate` (écrire) et `product-decide` (décider) automatisent ces procédures ; l'agent `product-steward` les applique pour les mises à jour transverses.

## 2. Règles du projet (non négociables)

- **Architecture :** Clean Architecture combinée à Feature Sliced Design (voir les notes `arch-*`). Les imports ne descendent que vers les couches inférieures. Chaque slice expose une API publique (barrel).
- **DI :** `get_it` + `injectable`, avec injection **par constructeur**. Interdit d'appeler `getIt` dans un widget ou un Bloc.
- **État :** `flutter_bloc` en **Bloc uniquement, Cubit interdit**. Events et states sont des `sealed`/`freezed`. Les flux passent par `emit.forEach`/`onEach`. Choisir un transformer de concurrence explicite.
- **Tests :** TDD (rouge → vert → refactor). Les comportements utilisateur sont décrits en BDD avec `bdd_widget_test` (fichiers `.feature`) **avant** l'implémentation. On ne mocke qu'aux frontières (runners voix, réseau, plateforme).
- **Orchestrateur :** il tourne **côté backend dès le départ** (décision du 2026-10-27). L'app Flutter ne porte que l'audio et WebRTC, le rendu A2UI et les outils locaux sans secret. Voir `adr-0002-orchestrator-backend` ; architecture du produit : `product/architecture/overview.md` (patrons génériques : `ma-target-architecture`, `ma-where-to-run-agents`).
- **Backend :** écrit **en Go** (décision du 2026-10-27), dans un module `backend/agent_orchestrator` du `septeo_saaster_kit`, en architecture hexagonale. Les fournisseurs (Live, A2UI) sont isolés derrière des ports. Les JWT sont vérifiés par JWKS (jamais `ParseUnverified`) et les origines CORS sont restreintes. Voir `adr-0003-backend-go` ; architecture du produit : `product/architecture/backend.md` ; plan de construction : `product/roadmap/backend-production-plan.md` (patron générique : `ma-backend-stack-recommendation`).
- **Sécurité :** aucune clé API longue durée côté client. Utiliser des sessions ou jetons éphémères créés par un backend.
- **Voix :**
  - une seule source de capture micro ;
  - fermeture propre de la session (`stop`/`close` distinct de `dispose`) ;
  - les résultats d'outils renvoyés au modèle sont les vrais résultats.
- **Configuration :** modèles, voix et régions sont injectés par configuration, jamais codés en dur.
- **Bugs à ne pas reproduire :** relire `knowledge/projects/ai-voice-widget/risks.md` avant de toucher au code voix.

## 3. Projets de référence

- `~/septeo/ai_voice_widget` : runners OpenAI/Gemini et pont voix → GenUI (`knowledge/projects/ai-voice-widget/`).
- `~/septeo/septeo_saaster_kit` : DI par environnement, routing modulaire, fixture BDD (`knowledge/projects/saaster-kit/`).

## 4. Décisions (historique obligatoire, deux registres)

| Registre | Contenu | Outil sous Claude Code |
|---|---|---|
| `knowledge/decisions/adr-NNNN-*.md` | décisions technologiques **réutilisables** (stack, architecture générique) | `kb-curate` |
| `product/decisions/pdr-NNNN-*.md` | décisions **propres à Genesis Canvas**, fonctionnelles ou techniques ; la section `inherited` de `product/decisions/index.yaml` liste les ADR qui s'appliquent au produit | `product-decide` |

- **Lire les deux registres avant de proposer ou de contester un choix.** On y trouve les décisions déjà prises, leurs raisons, les options écartées et les cas où il faut les réexaminer.
- **Toute nouvelle décision** donne lieu à un nouvel ADR ou PDR. Une décision **remplacée** en donne aussi un nouveau, et l'ancien est marqué « remplacée par ». Une décision réévaluée puis **reconfirmée** s'ajoute à l'historique de son ADR ou PDR existant. Les sorties brutes des panels vont dans `knowledge/decisions/_archive/` pour un ADR, dans `product/decisions/_archive/` pour une PDR. Une décision n'est jamais effacée : on la marque remplacée.
- **Une question tranchée** de `product/roadmap/open-questions.md` passe à « tranchée → pdr-NNNN » ; la PDR cite la `Q-xx`.
- **Signaler explicitement toute hypothèse non confirmée** par le porteur du projet (compétences de l'équipe, contraintes d'hébergement…), et la faire confirmer avant de la noter comme décision. Dans `product/`, elle est marquée « ⚠️ Hypothèse non confirmée » et renvoie à une `Q-xx`.
- **L'assistant recommande, le porteur décide.** L'ADR ou la PDR indique qui a décidé (`decided_by` pour les PDR).

## 5. Entretenir la base `knowledge/`

- **Format :** respecter `knowledge/_conventions.md` (une idée par note, moins de 60 lignes, frontmatter `id`/`tags`/`status`/`updated`/`sources`/`links`).
- **Quand écrire une note :**
  - un fait nouveau et vérifié a été appris (API, piège, décision d'architecture) ;
  - une note est obsolète : la corriger et mettre à jour `updated`.
- **Après chaque ajout :** mettre à jour le `index.yaml` du domaine. Si une nouvelle tâche type apparaît, mettre aussi à jour la section `tasks` de `knowledge/index.yaml`. Mettre à jour `knowledge/tags.yaml`.
- **Contrôle :** lancer `python3 -I knowledge/_tools/kb_lint.py`, qui doit sortir sans erreur.
- **Refactoring périodique :** environ tous les 10 ajouts, fusionner les doublons, scinder les notes trop longues et revoir `entrypoints`/`tasks`. Sous Claude Code : skill `kb-curate`.
- **Documentation produit :** même discipline pour `product/` (voir § 1 bis et `product/_conventions.md`) ; contrôle par `python3 -I product/_tools/product_lint.py`.
