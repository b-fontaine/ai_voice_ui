---
name: kb-lookup
description: Consulte la base de connaissances knowledge/ (zettelkasten + index YAML) AVANT toute tâche sur ce projet. À utiliser au début de chaque tâche, qu'il s'agisse de code, de plan, de revue ou d'une question sur la voix temps réel (gpt-live, Gemini Live, WebRTC), GenUI/A2UI, l'architecture Flutter (Clean, FSD), la DI (get_it/injectable), Bloc, les tests TDD/BDD, la performance ou les protocoles d'agents (MCP, A2A, AG-UI).
---

# kb-lookup

Objectif : récupérer les notes pertinentes en lisant le moins de fichiers possible, puis agir en les citant.

## Étapes

1. **Router.** Lire `knowledge/index.yaml`.
   - Si la tâche correspond à une entrée de `tasks`, prendre ses ids.
   - Sinon, choisir 1 à 3 domaines selon leurs `keywords`.
2. **Sélectionner.** Lire le `index.yaml` de chaque domaine retenu et garder les notes dont le `summary` ou les `tags` correspondent à la tâche. Viser 3 à 8 notes.
3. **Compléter si besoin.**
   - Par tag : `knowledge/tags.yaml`.
   - Par texte : `grep -ril "<terme>" knowledge --include=*.md | head`.
4. **Lire** les notes retenues. Suivre leurs `links` sur un niveau seulement, et uniquement si c'est pertinent.
5. **Évaluer la fiabilité :**
   - `status: verified` : fait vérifié sur la doc officielle à la date `updated`.
   - `sourced` : source secondaire.
   - `opinion` : convention ou recommandation du projet. Elle s'impose comme règle interne, pas comme fait externe.
   - Si `updated` date de plus de 3 mois et que le sujet bouge vite (modèles, `genui`, A2UI, MCP), revérifier sur la doc officielle avant de s'y fier.
6. **Agir** en citant les ids, par exemple : « D'après [rt-gpt-live-webrtc-session] … ».
7. **Combler les trous.** Si une information manquait ou était fausse, la noter. En fin de tâche, l'ajouter ou la corriger via le skill `kb-curate`.

## Garde-fous
- Ne pas charger tout un domaine d'un coup : passer par les index.
- Une note qui contredit la doc officielle actuelle doit être corrigée, pas suivie.
