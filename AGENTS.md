# AGENTS.md — ai_voice_ui

Application Flutter multi-agents. Elle réunit :
- un **orchestrateur** ;
- un **agent vocal** voice-to-voice temps réel (OpenAI `gpt-live-1` en WebRTC, ou Gemini Live via Firebase AI Logic) ;
- un **agent GenUI**, qui génère des écrans avec le package `genui` et le protocole A2UI ;
- des **outils**, exposés via MCP et A2A.

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
6. Si une note contredit la doc officielle actuelle, la doc gagne. **Corriger alors la note** (voir § 4).

Sous Claude Code, le skill `kb-lookup` automatise cette procédure.

## 2. Règles du projet (non négociables)

- **Architecture :** Clean Architecture combinée à Feature Sliced Design (voir les notes `arch-*`). Les imports ne descendent que vers les couches inférieures. Chaque slice expose une API publique (barrel).
- **DI :** `get_it` + `injectable`, avec injection **par constructeur**. Interdit d'appeler `getIt` dans un widget ou un Bloc.
- **État :** `flutter_bloc` en **Bloc uniquement, Cubit interdit**. Events et states sont des `sealed`/`freezed`. Les flux passent par `emit.forEach`/`onEach`. Choisir un transformer de concurrence explicite.
- **Tests :** TDD (rouge → vert → refactor). Les comportements utilisateur sont décrits en BDD avec `bdd_widget_test` (fichiers `.feature`) **avant** l'implémentation. On ne mocke qu'aux frontières (runners voix, réseau, plateforme).
- **Orchestrateur :** il tourne **côté backend dès le départ** (décision du 2026-10-27). L'app Flutter ne porte que l'audio et WebRTC, le rendu A2UI et les outils locaux sans secret. Voir `ma-target-architecture` et `ma-where-to-run-agents`.
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

## 4. Entretenir la base

- **Format :** respecter `knowledge/_conventions.md` (une idée par note, moins de 60 lignes, frontmatter `id`/`tags`/`status`/`updated`/`sources`/`links`).
- **Quand écrire une note :**
  - un fait nouveau et vérifié a été appris (API, piège, décision d'architecture) ;
  - une note est obsolète : la corriger et mettre à jour `updated`.
- **Après chaque ajout :** mettre à jour le `index.yaml` du domaine. Si une nouvelle tâche type apparaît, mettre aussi à jour la section `tasks` de `knowledge/index.yaml`. Mettre à jour `knowledge/tags.yaml`.
- **Contrôle :** lancer `python3 -I knowledge/_tools/kb_lint.py`, qui doit sortir sans erreur.
- **Refactoring périodique :** environ tous les 10 ajouts, fusionner les doublons, scinder les notes trop longues et revoir `entrypoints`/`tasks`. Sous Claude Code : skill `kb-curate`.
