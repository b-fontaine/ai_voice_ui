---
name: product-curate
description: Ajoute, modifie ou réorganise un document de la documentation produit product/ de Genesis Canvas (fonctionnel, exigences FR/NFR, règles RG, écran, catalogue, jeu de données, scénarios Gherkin, roadmap, backlog, spikes, questions ouvertes Q-xx, architecture du produit, README). À utiliser dès qu'un fait propre au produit est appris, qu'un document produit est obsolète ou incomplet, qu'un écart entre sources est découvert, ou pour un refactoring (scission, fusion, réindexation). Pour enregistrer une décision, utiliser product-decide ; pour un savoir réutilisable, kb-curate.
---

# product-curate

Le format de référence est `product/_conventions.md`. Le relire avant d'écrire.

## 0. Est-ce le bon endroit ?
Appliquer l'arbre « Où écrire ? » (`_conventions.md` § 1) :
- fait externe vérifié ou pattern réutilisable → `knowledge/` via `kb-curate` ;
- décision (produit) → `product-decide` ;
- tout le reste propre à Genesis Canvas → ici.

## 1. Ajouter ou modifier un document
1. **Chercher l'existant** avec `product-lookup` (index de zone, `grep`). Si un document couvre le sujet, le **modifier** plutôt que d'en créer un.
2. **Frontmatter complet** : `id` avec le préfixe de la zone (`p-fn-`, `p-ar-`, `p-rm-`, `p-` pour la racine), `title`, `area`, `status`, `updated` à la date du jour, `sources`, `links`, `tags`.
   - `status: validated` seulement si le contenu vient d'une source validée par le porteur ; sinon `draft`.
3. **Corps** : « En bref » de 2-3 lignes, tableaux plutôt que paragraphes, < 150 lignes (250 maximum, sinon scinder).
4. **Traçabilité** : chaque affirmation fonctionnelle cite son § ou sa page de fiche, ou son n° de maquette ; chaque affirmation technique cite un id `knowledge/` ou un ADR ; chaque choix propre au produit cite sa PDR.
5. **Identifiants** : nouveaux `FR-xx`, `NFR-xx`, `RG-xx`, `Q-xx` = numéro suivant, jamais réutilisé. Une exigence retirée est barrée avec un renvoi à la PDR qui la retire.
6. **Scénarios Gherkin** (`functional/features/*.feature`) : `# language: fr`, en-tête `# id: p-fn-feature-<slug>`, chaque scénario étiqueté avec ses exigences (`@FR-01 @NFR-02`).

## 2. Questions ouvertes et écarts
- Un écart entre sources (fiche vs maquettes, fiche vs `knowledge/`) ou une hypothèse non confirmée : **ne pas trancher**. Le décrire dans le document avec « ⚠️ Hypothèse non confirmée » ou « Écart », citer les deux sources, et créer ou compléter une `Q-xx` dans `roadmap/open-questions.md` (contexte, options, recommandation éventuelle de l'assistant, décideur, échéance, statut).
- Ne jamais modifier un document `validated` pour y inscrire un choix qui n'a pas été décidé : passer par `product-decide`.

## 3. Lier et indexer
1. **Liens dans les deux sens** : ajouter l'id du document dans les `links` de 1 à 3 documents voisins, et des liens markdown relatifs dans le corps.
2. **Index de zone** (`<zone>/index.yaml`) : ajouter, renommer ou retirer l'entrée `{id, path, summary, tags}`.
3. **`product/index.yaml`** :
   - nouveau document à la racine ou dans `sources/` → section `meta` ;
   - nouvelle tâche type → nouvelle entrée `tasks` (`task`, `docs`, `knowledge`) ;
   - nouveaux mots de routage → `keywords` de la zone.
4. Si un fait réutilisable a été appris en route, l'ajouter aussi à `knowledge/` via `kb-curate` et le citer par id.

## 4. Contrôler
`python3 -I product/_tools/product_lint.py` doit afficher **0 erreur**. Traiter aussi les avertissements (tag `@FR-xx` inconnu, `Q-xx` absente, document > 150 lignes).

## Refactoring (sur demande ou tous les ~10 ajouts)
- Scinder les documents de plus de 150 lignes ; fusionner les doublons en redirigeant les `links`.
- Revoir `entrypoints` et `tasks` de `product/index.yaml` selon les tâches réellement faites.
- Vérifier que chaque `Q-xx` « tranchée » pointe vers une PDR, et que chaque PDR acceptée a ses conséquences reportées dans les documents impactés.
- Relancer le lint.
