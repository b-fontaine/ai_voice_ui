---
name: kb-curate
description: Ajoute, corrige ou réorganise des notes de la base de connaissances knowledge/ (zettelkasten). À utiliser après avoir appris un fait nouveau et vérifié, quand une note est obsolète ou fausse, ou pour un refactoring périodique (fusion de doublons, scission, réindexation).
---

# kb-curate

Le format de référence est `knowledge/_conventions.md`. Le relire avant d'écrire.

## Ajouter ou corriger une note
1. **Vérifier qu'elle n'existe pas déjà.** Chercher dans `knowledge/tags.yaml`, puis avec `grep -ril` sur le sujet. Si une note couvre le sujet, la **modifier** plutôt que d'en créer une nouvelle.
2. **Rédiger une note atomique** : une idée, moins de 60 lignes. Frontmatter complet (`id` avec le préfixe du domaine, `status`, `updated` à la date du jour, `sources` réelles, `links`).
3. **Lier dans les deux sens :** ajouter l'id de la nouvelle note dans les `links` de 1 à 3 notes voisines.
4. **Mettre à jour les index :**
   - le `index.yaml` du domaine ;
   - `knowledge/tags.yaml` ;
   - si c'est une nouvelle tâche type, la section `tasks` de `knowledge/index.yaml`.
5. **Contrôler :** `python3 -I knowledge/_tools/kb_lint.py` doit afficher 0 erreur.

## Enregistrer une décision (ADR)
1. Prendre le numéro suivant dans `knowledge/decisions/index.yaml`.
2. Écrire `knowledge/decisions/adr-NNNN-<slug>.md` selon `_conventions.md` : date, statut, décideur, contexte et hypothèses (en marquant celles qui ne sont pas confirmées), options, décision, raisons, options écartées, cas de réexamen, archives.
3. Archiver les sorties brutes (propositions, vérifications, jugements, synthèse) dans `decisions/_archive/AAAA-MM-JJ-<slug>.md`, puis les référencer dans la section `archives` de l'index.
4. Si la décision en remplace une autre, passer l'ancien ADR à « remplacée par adr-NNNN ». Ne jamais le supprimer.
5. Lier l'ADR aux notes techniques concernées, dans les deux sens.

## Refactoring (environ tous les 10 ajouts, ou sur demande)
- Fusionner les doublons : garder une note canonique et rediriger les `links`.
- Scinder les notes de plus de 60 lignes.
- Créer un sous-dossier, avec son `index.yaml`, quand un domaine dépasse 8 notes sur un même sous-thème.
- Revoir `entrypoints` et `tasks` dans `knowledge/index.yaml` en fonction des tâches réellement effectuées.
- Repérer les notes `updated` de plus de 3 mois sur un sujet volatil et les revérifier.
- Relancer le lint.
