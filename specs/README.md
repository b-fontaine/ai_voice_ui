# specs/ — une fonctionnalité = un dossier (SDD léger)

Gabarit SDD retenu par le porteur : « option 2 », un Spec Kit léger (Q-09). `product/` reste la **seule** référence produit. Chaque dossier `specs/NNN-<slug>/` décrit une fonctionnalité en **renvoyant** aux exigences de `product/` (FR-xx, NFR-xx, RG-xx, scénarios Gherkin, PDR) au lieu de les recopier.

| Fichier | Rôle | Écrit à l'étape |
|---|---|---|
| `spec.md` | quoi et pourquoi : périmètre, exigences visées (ids), scénarios Gherkin, critères d'acceptation | Définir |
| `plan.md` | comment : slices, couches, ports, fichiers touchés, notes `knowledge/` | Définir |
| `tasks.md` | tâches ordonnées T01…, chacune avec son test d'abord ; `[P]` = parallélisable | Définir |
| `status.md` | état vivant : étape courante, tâches faites, journaux de `gate.sh`, rapport d'architecte, questions | toutes |

Gabarits : `_templates/`. Tests d'acceptation : Flutter dans `test/acceptance/` (bdd_widget_test), Go avec le build tag `acceptance` ; ils ne comptent que dans la porte complète (`tools/loop/gate.sh --full`). Une fonctionnalité vit sur sa branche `feat/NNN-<slug>` et n'est fusionnée qu'une fois verte. `openai-spend.tsv` : registre versionné des dépenses OpenAI réelles de la boucle. Numérotation : `NNN` séquentiel, jamais réutilisé. L'ordre des fonctionnalités suit `product/roadmap/roadmap.md`.

La boucle qui exploite ces dossiers est décrite dans `.claude/skills/dev-loop/SKILL.md` et `tools/loop/README.md`.
