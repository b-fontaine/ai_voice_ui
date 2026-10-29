# Genesis Canvas

Démo de conférence Flutter desktop : la **voix** du speaker déclenche un **orchestrateur** et des **agents A2A**, qui renvoient de l'**UI déclarative A2UI** rendue en direct par **GenUI**. Cas d'usage : **Release Copilot**, la préparation de la décision go/no-go d'une release mobile, sur des données fictives.

> « L'agent ne génère pas du code, il génère de la donnée d'interface ; le développeur Flutter garde la main sur le rendu via son catalogue. »

## Statut

- Livrable : **démo de talk**, pas un produit de production ([pdr-0001](product/decisions/pdr-0001-conference-demo-deliverable.md)).
- Phase : **cadrage** (jalon J0). Le dépôt ne contient **pas encore de code applicatif**. On y trouve la documentation produit, la base de connaissances et un spike.
- Plusieurs points restent ouverts, dont des écarts entre la fiche produit et les maquettes : voir le [registre des questions ouvertes](product/roadmap/open-questions.md).

## Carte du dépôt

| Dossier | Contenu |
|---|---|
| [`product/`](product/README.md) | Documentation **propre à Genesis Canvas** : fonctionnel (exigences, écran, catalogue, scénarios Gherkin), architecture du produit, roadmap, questions ouvertes, décisions produit (`pdr-*`), sources (fiche produit et maquettes en PDF) |
| [`knowledge/`](knowledge/index.yaml) | Base de connaissances **réutilisable** (zettelkasten) : faits vérifiés et datés sur la voix temps réel, GenUI/A2UI, l'architecture Flutter, Bloc, les tests, les protocoles d'agents, le design system, et décisions technologiques génériques (`adr-*`) |
| [`specs/`](specs/README.md) | Une fonctionnalité = un dossier (spec, plan, tâches, état) ; avancement dans [`specs/progress.md`](specs/progress.md) |
| [`tools/loop/`](tools/loop/README.md) | Boucle de développement autonome : porte de qualité, quota, superviseur, publication |
| [`spikes/`](spikes/) | Expériences techniques jetables (ex. [`spikes/widgetbook4`](spikes/widgetbook4/README.md)) |
| `.claude/` | Skills et agents utilisés par Claude Code pour consulter et entretenir `knowledge/` et `product/` |
| [`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md) | Règles du projet pour les agents IA |

## Par où commencer la lecture

1. [`product/README.md`](product/README.md) : le produit en 5 lignes, un parcours de lecture par profil (porteur, dev Flutter, dev backend, agent IA) et la carte des documents.
2. [Vision](product/functional/vision.md), [écran](product/functional/screen.md) et [exigences](product/functional/requirements.md) : ce que la démo doit faire.
3. [Vue d'ensemble de l'architecture](product/architecture/overview.md) et [roadmap](product/roadmap/roadmap.md) : comment elle est construite, et dans quel ordre.
4. [`knowledge/index.yaml`](knowledge/index.yaml) : les faits techniques sur lesquels tout repose.

## Conventions de travail

- **Architecture** : Clean Architecture + Feature Sliced Design ; DI `get_it` + `injectable` par constructeur ; `flutter_bloc` en Bloc uniquement. Orchestrateur côté backend, écrit en Go (architecture hexagonale). Détail : [`AGENTS.md`](AGENTS.md) § 2.
- **Tests** : TDD (rouge → vert → refactor). Les comportements sont décrits en BDD (`bdd_widget_test`, fichiers `.feature`) **avant** l'implémentation ; les scénarios de référence sont dans [`product/functional/features/`](product/functional/features/).
- **Décisions** : deux registres. Les ADR génériques vont dans [`knowledge/decisions/`](knowledge/decisions/index.yaml) et les décisions produit dans [`product/decisions/`](product/decisions/index.yaml). Une décision n'est jamais effacée, on la marque remplacée. L'assistant recommande, le porteur décide.
- **Contrôle de la documentation** : les deux commandes suivantes doivent sortir sans erreur.

```bash
python3 -I knowledge/_tools/kb_lint.py
python3 -I product/_tools/product_lint.py
```

## Comment les agents IA utilisent ce dépôt

- [`AGENTS.md`](AGENTS.md) est la consigne commune à tous les agents. Avant d'agir, ils consultent `knowledge/` (§ 1) et `product/` (§ 1 bis) à partir de leurs `index.yaml`, et respectent les règles non négociables (§ 2).
- Sous Claude Code ([`CLAUDE.md`](CLAUDE.md)), les skills automatisent ces procédures :

| Skill ou agent | Rôle |
|---|---|
| `kb-lookup` / `kb-curate` | lire / entretenir `knowledge/` |
| `product-lookup` / `product-curate` | lire / entretenir `product/` |
| `product-decide` | enregistrer une décision produit (`pdr-*`) |
| `product-steward` (agent) | mises à jour transverses de `product/` |

## Licence

Voir [`LICENSE`](LICENSE).
