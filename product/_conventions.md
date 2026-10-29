---
id: p-conventions
title: Conventions de la documentation produit
area: meta
status: draft
updated: 2026-10-29
sources: [AGENTS.md, knowledge/_conventions.md]
links: [p-readme, p-rm-open-questions, adr-0001-initial-constraints, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0018-a2ui-v09-genui-0-10-4, p-sources, p-fn-mockups]
tags: [meta, conventions, documentation, lint, decision]
---
# Conventions de `product/`

**En bref.** `product/` décrit tout ce qui est **propre à Genesis Canvas** : fonctionnel, roadmap, architecture du produit et décisions produit (PDR). Le savoir réutilisable ailleurs reste dans `knowledge/`, qu'on cite par id au lieu de le recopier. Le lint `python3 -I product/_tools/product_lint.py` doit sortir sans erreur après chaque modification.

## 1. Où écrire ?

```text
L'information est…
├─ un fait externe vérifié (API, version, piège) ou un pattern réutilisable ?
│     → knowledge/<domaine>/ via le skill kb-curate
├─ une décision technologique valable pour d'autres projets ?
│     → knowledge/decisions/adr-NNNN-*.md via kb-curate
├─ une décision propre à Genesis Canvas (fonctionnelle ou technique) ?
│     → product/decisions/pdr-NNNN-*.md via le skill product-decide
├─ une question non tranchée (vrai arbitrage), une hypothèse ?
│     → product/roadmap/open-questions.md (Q-xx), via product-curate
│       (une question à réponse unique imposée par les faits = décision contrainte, § 5)
└─ tout autre contenu propre au produit (exigence, écran, archi, jalon…)
      → product/<zone>/ via le skill product-curate
```

| Zone | Dossier | Préfixe d'id | `area` |
|---|---|---|---|
| Méta (README, conventions, sources) | `product/`, `product/sources/` | `p-` (ex. `p-readme`) | `meta` |
| Fonctionnel | `functional/` (+ `features/*.feature`) | `p-fn-` | `functional` |
| Architecture du produit | `architecture/` | `p-ar-` | `architecture` |
| Roadmap | `roadmap/` | `p-rm-` | `roadmap` |
| Décisions produit | `decisions/` | `pdr-NNNN-` | `decisions` |

## 2. Frontmatter (tout `.md` de `product/`, sauf `decisions/_template.md`)

```yaml
---
id: p-fn-screen              # unique dans product/ ET knowledge/, stable, kebab-case
title: Écran unique en 6 zones
area: functional             # functional | roadmap | architecture | decisions | meta
status: validated            # draft | validated | proposed | superseded
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p5, knowledge:rt-barge-in]
links: [p-fn-catalog, pdr-0008-single-screen-show-the-making, rt-barge-in]
tags: [ecran, orbe]
---
```

| `status` | Sens |
|---|---|
| `validated` | repris d'une source validée par le porteur (la fiche produit), ou décision acceptée |
| `draft` | synthèse de l'assistant, à relire par le porteur |
| `proposed` | proposition en attente de décision |
| `superseded` | remplacé ou abandonné ; conservé pour l'historique |

Les `.feature` (Gherkin, `# language: fr`) n'ont pas de frontmatter : un commentaire `# id: p-fn-feature-<slug>` dans les 5 premières lignes, et chaque scénario étiqueté avec ses exigences (`@FR-01 @NFR-02`).

## 3. Écriture

- **Une page = un sujet.** Viser < 150 lignes ; au-delà de 250, scinder (le lint échoue).
- **Commencer par « En bref »** (2-3 lignes). Préférer les tableaux aux paragraphes.
- **Français correct**, accents compris ; code et identifiants dans leur langue d'origine.
- **Identifiants stables** : exigences `FR-xx` / `NFR-xx`, règles `RG-xx`, questions `Q-xx`, écarts `Ex`, scénarios BDD `S-xx` (tags des `.feature`), spikes `SP-xx` (préfixe distinct des scénarios), jalons `Jx`, epics `EP-xx`. Un numéro n'est jamais réutilisé ; une exigence retirée est barrée et marquée « retirée (pdr-NNNN) ».
- **Liens** : ids dans `links` + liens markdown relatifs dans le corps (`[écran](screen.md)`). Lier dans les deux sens.

## 4. Traçabilité

| Type d'affirmation | Référence obligatoire |
|---|---|
| Fonctionnelle | § ou page de la fiche (`product-description.pdf#p4`), n° de maquette |
| Technique | id de note `knowledge/` (`[rt-gpt-live-lifecycle]`) ou ADR (`adr-0003-backend-go`) |
| Choix propre au produit | id de PDR (`pdr-0006-replay-fallback-must`) |
| Hypothèse non confirmée | « ⚠️ Hypothèse non confirmée » + renvoi à une `Q-xx` |

- **Hiérarchie des sources** ([pdr-0017](decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md), remplace la consigne « tout laisser ouvert » du 2026-10-28) : la **fiche produit fait foi**. Les **maquettes illustrent la vision** du porteur, ne sont jamais une spécification ni suivies à la lettre.
  - Écart fiche/maquette : ce n'est **pas une question**, la fiche l'emporte ; on le note dans [p-fn-mockups](functional/mockups.md) comme « différence avec l'illustration ».
  - Fiche muette : la maquette n'est qu'une inspiration et n'impose rien.
  - Point technique (version A2UI, noms de messages, ids de surfaces, `Grid`, `catalogId`…) : la maquette ne compte pas du tout ; seuls les faits vérifiés et les décisions décident.
  - Exception : les PDR déjà acceptées par le porteur (pdr-0013 à pdr-0016) restent valables telles quelles.
- **Écart fiche vs `knowledge/`** : décrire l'écart, citer les deux sources ; décision contrainte (§ 5) si les faits imposent la réponse, sinon `Q-xx`.
- Si une note `knowledge/` contredit la doc officielle actuelle, corriger la note via `kb-curate` (AGENTS.md § 1).

## 5. Décisions produit (PDR)

Fichier `decisions/pdr-NNNN-<slug>.md`, à partir de [`_template.md`](decisions/_template.md). `NNNN` = `next_id` de `decisions/index.yaml`, puis on l'incrémente. Numéros séquentiels, sans trou, jamais réutilisés.

Champs en plus du frontmatter commun :

| Champ | Valeurs |
|---|---|
| `decision_status` | `proposée` · `acceptée` · `remplacée par pdr-NNNN-<slug>` · `abandonnée` |
| `decided_on` | date de la décision (ou de la proposition) |
| `decided_by` | toujours renseigné : qui a décidé, ou qui doit décider, et par quel canal |
| `scope` | `fonctionnel` · `technique` · `mixte` |
| `supersedes` | liste des PDR remplacés (`[]` sinon) |
| `superseded_by` | id du PDR remplaçant, ou `null` |
| `constraint_basis` | **optionnel**, obligatoire pour une décision contrainte : liste des ids (notes `knowledge/` vérifiées, `pdr-*`, `adr-*`, ou `AGENTS.md#<règle>`) qui imposent la réponse ; résolus par le lint comme les `links` |

Cohérence vérifiée par le lint : `acceptée` → `status: validated` ; `proposée` → `proposed` ; `remplacée par …` et `abandonnée` → `superseded` (et `superseded_by` égal au remplaçant).

**Cycle de vie** : proposée → acceptée → remplacée / abandonnée.
- **L'assistant recommande, le porteur décide.** L'assistant ne passe jamais une PDR à `acceptée` sans une parole explicite du porteur, citée dans l'historique — **sauf décision contrainte**.
- **Décision contrainte** (délégation du porteur du 2026-10-29) : question dont **une seule réponse est correcte** au vu de faits vérifiés (notes `knowledge/` `status: verified`, doc officielle) et/ou de décisions déjà acceptées (`pdr-*`, `adr-*` hérités, règles AGENTS.md § 2). L'assistant la tranche lui-même et l'enregistre en PDR `acceptée` avec `decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"` et `constraint_basis`, puis la **signale au porteur** dans son compte rendu. Le porteur peut la contester : elle est alors remplacée par une PDR de sa main. Le lint exige `constraint_basis` dès que `decided_by` commence par « Assistant (décision contrainte) ».
- **Restent au porteur** : les vrais arbitrages (goûts, priorités, mise en scène, budget, calendrier, matériel, écarts fiche/maquettes de nature produit, compromis entre options toutes valables) et toute hypothèse sur l'équipe, l'hébergement ou le contexte.
- **Archives** : les sorties brutes (panels, recherches) d'une PDR vont dans `product/decisions/_archive/AAAA-MM-JJ-<slug>.md` (ignoré par le lint) ; celles d'un ADR, dans `knowledge/decisions/_archive/`.
- **Jamais supprimée.** Remplacer = nouvelle PDR avec `supersedes`, ancienne marquée `remplacée par …`.
- **Reconfirmer** = ajouter une ligne au tableau « Historique » de la PDR existante (pas de nouveau numéro).
- **Questions ↔ décisions** : une `Q-xx` tranchée passe à « tranchée → pdr-NNNN » dans `roadmap/open-questions.md` ; la PDR cite la `Q-xx` dans son contexte. Une PDR proposée garde sa `Q-xx` ouverte.
- **Héritage** : les ADR génériques de `knowledge/decisions/` qui s'appliquent au produit sont listés dans la section `inherited` de `decisions/index.yaml` (cf. `pdr-0011-adopt-knowledge-adrs`).

## 6. Index YAML

Chaque zone a un `index.yaml` qui liste **tous** ses documents (y compris `features/*.feature`) :

```yaml
domain: functional
description: <une ligne>
docs:
  - {id: p-fn-screen, path: screen.md, summary: "<une ligne>", tags: [ecran]}
```

`decisions/index.yaml` ajoute `next_id: pdr-NNNN` (obligatoirement sous cette forme, ex. `pdr-0013`), un champ `decision_status` par entrée de `docs` (identique à celui du fichier), et `inherited:` (`- {id: adr-0001-…, path: ../../knowledge/decisions/adr-0001-….md, summary: "…"}`).

`product/index.yaml` (racine) : `zones` (`name`, `prefix`, `index`, `description`, `keywords`), `meta` (documents de la racine et de `sources/`), `entrypoints`, et `tasks` (`- task: "…"` puis `docs: [ids product]`, éventuellement `knowledge: [ids]`). Une nouvelle tâche type → nouvelle entrée `tasks`.

## 7. Contrôle

`python3 -I product/_tools/product_lint.py` vérifie : frontmatter, ids uniques et préfixes, `area`/`status`/`updated`, champs et numérotation des PDR, `constraint_basis` (liste, ids résolus, obligatoire pour une décision contrainte), `next_id` au format `pdr-NNNN`, `decision_status` index ↔ fichier, questions « Avant Jn » du registre citées dans la colonne « Dépend de » du jalon Jn de `roadmap/roadmap.md`, `links` résolus (product ou knowledge hors `_archive`), en-têtes des `.feature`, index ↔ fichiers, index racine, liens markdown relatifs, tailles. Avertissements : tags `@FR-xx` inconnus, `Q-xx` absente de `open-questions.md`, `supersedes` non réciproque. Code retour 1 en cas d'erreur.
