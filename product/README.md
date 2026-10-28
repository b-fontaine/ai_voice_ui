---
id: p-readme
title: Documentation produit Genesis Canvas
area: meta
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf, product/sources/design-example.pdf, AGENTS.md]
links: [p-conventions, p-sources, p-fn-vision, p-fn-requirements, p-fn-screen, p-ar-overview, p-rm-roadmap, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai]
tags: [meta, readme, entree, carte]
---
# Genesis Canvas — documentation produit

**En bref.** Tout ce qui est **propre** à Genesis Canvas : ce que fait le produit, comment on y arrive, comment il est construit, et chaque décision prise. Les humains lisent cette page ; les agents IA partent de [`index.yaml`](index.yaml). Le savoir technique réutilisable vit dans [`knowledge/`](../knowledge/), cité par id (`[rt-barge-in]`).

## Le produit en 5 lignes

1. Une **app Flutter desktop** projetée pendant un talk construit des écrans sous les yeux du public, à partir de la **voix** du speaker ([vision](functional/vision.md), fiche p1).
2. La voix déclenche un **orchestrateur** côté backend, qui délègue à des **agents A2A** ; ceux-ci renvoient de l'**UI déclarative A2UI**, rendue par **GenUI** avec un catalogue fermé ([overview](architecture/overview.md)).
3. Cas d'usage : **Release Copilot**, la décision go/no-go d'une release mobile 3.4 face à la 3.3, sur des **données fictives figées** ([pdr-0003](decisions/pdr-0003-use-case-release-copilot.md), [pdr-0005](decisions/pdr-0005-frozen-fictional-dataset.md)).
4. La démo tient en **3 actes** (créer, transformer, interagir), plus un rejeu optionnel, sur un **écran unique en 6 zones** qui montre la fabrication ([pdr-0004](decisions/pdr-0004-mvp-three-acts.md), [écran](functional/screen.md)).
5. Message du talk : « L'agent ne génère pas du code, il génère de la donnée d'interface ; le développeur Flutter garde la main sur le rendu via son catalogue. » C'est un **livrable de conférence**, pas un produit de production ([pdr-0001](decisions/pdr-0001-conference-demo-deliverable.md)).

## Par où commencer

| Profil | Lire dans cet ordre |
|---|---|
| **Porteur** (relire, décider) | [questions ouvertes](roadmap/open-questions.md) → [maquettes et écarts](functional/mockups.md) → [décisions](decisions/index.yaml) (dont [pdr-0012](decisions/pdr-0012-voice-provider-openai.md), proposée) → [roadmap](roadmap/roadmap.md) |
| **Dev Flutter** | [vision](functional/vision.md) → [écran](functional/screen.md) → [exigences](functional/requirements.md) et [scénarios](functional/features/) → [catalogue](functional/catalog.md) → [frontend](architecture/frontend.md) → [qualité](architecture/quality.md) |
| **Dev backend (Go)** | [vue d'ensemble](architecture/overview.md) → [backend](architecture/backend.md) → [agents et protocoles](architecture/agents-protocols.md) → [sécurité](architecture/security.md) → [rejeu](architecture/replay.md) → [jeu de données](functional/dataset.md) |
| **Agent IA** | [`index.yaml`](index.yaml) (section `tasks`) → documents listés → leurs `links` sur un niveau ; skill `product-lookup` sous Claude Code ; procédure manuelle dans `AGENTS.md` § 1 bis |

## Carte des documents

| Zone | Documents | Répond à la question |
|---|---|---|
| [functional/](functional/index.yaml) | [vision](functional/vision.md), [personas et parcours](functional/personas-journey.md), [périmètre](functional/scope.md) | Pourquoi ce produit, pour qui, qu'est-ce qui est dedans ou dehors ? |
| | [exigences FR](functional/requirements.md), [NFR](functional/nfr.md), [règles RG](functional/business-rules.md), [scénarios Gherkin](functional/features/) | Que doit faire le produit, et comment le vérifie-t-on ? |
| | [écran](functional/screen.md), [catalogue](functional/catalog.md), [jeu de données](functional/dataset.md), [maquettes](functional/mockups.md), [glossaire](functional/glossary.md) | À quoi ressemble-t-il, avec quels composants et quelles données ? |
| | [risques, plan B, DoD](functional/risks-acceptance.md) | Qu'est-ce qui peut rater sur scène, et quand est-ce « fini » ? |
| [architecture/](architecture/index.yaml) | [vue d'ensemble](architecture/overview.md), [frontend](architecture/frontend.md), [backend](architecture/backend.md), [agents et protocoles](architecture/agents-protocols.md) | Comment est-il construit, qui parle à qui ? |
| | [stack](architecture/stack.md), [rejeu](architecture/replay.md), [sécurité](architecture/security.md), [qualité](architecture/quality.md), [scène](architecture/stage-runtime.md) | Avec quelles versions, comment tient-il sans réseau, comment le teste-t-on et le joue-t-on en salle ? |
| [roadmap/](roadmap/index.yaml) | [roadmap](roadmap/roadmap.md), [backlog](roadmap/backlog.md), [spikes](roadmap/spikes.md), [questions ouvertes](roadmap/open-questions.md), [au-delà](roadmap/beyond.md), [plan backend de production](roadmap/backend-production-plan.md) | Dans quel ordre le construire, que reste-t-il à décider, que faire après le talk ? |
| [decisions/](decisions/index.yaml) | `pdr-0001` … `pdr-0012`, ADR hérités de `knowledge/` | Qu'a-t-on décidé, pourquoi, qui l'a décidé ? |
| méta | [conventions](_conventions.md), [sources](sources/README.md), [`index.yaml`](index.yaml) | Comment écrire ici, d'où viennent les faits ? |

## État au 2026-10-28

| Élément | État |
|---|---|
| Jalon | **J0 Cadrage et docs** en cours, en attente de relecture du porteur ([roadmap](roadmap/roadmap.md)) ; aucun code applicatif |
| Sources | fiche produit validée + 3 maquettes ([sources](sources/README.md)) |
| Spikes | SP-00 Widgetbook 4 fait ; SP-01 à SP-07 et SP-09 (secours Windows) à mener en J1 ([spikes](roadmap/spikes.md)) |
| Décisions | 11 PDR acceptées, 1 proposée (pdr-0012) ; 8 ADR hérités ([index](decisions/index.yaml)) |
| Questions | 64 ouvertes, dont 22 écarts entre sources (21 fiche ↔ maquettes, 1 fiche ↔ ADR hérités) ([registre](roadmap/open-questions.md)) |

## Décisions clés

Liste complète et résumés : [`decisions/index.yaml`](decisions/index.yaml). Les plus structurantes : démo de conférence ([pdr-0001](decisions/pdr-0001-conference-demo-deliverable.md)), Flutter desktop macOS ([pdr-0002](decisions/pdr-0002-desktop-platform.md)), 3 actes ([pdr-0004](decisions/pdr-0004-mvp-three-acts.md)), rejeu et mode secours obligatoires ([pdr-0006](decisions/pdr-0006-replay-fallback-must.md)), catalogue fermé et thème de scène ([pdr-0007](decisions/pdr-0007-closed-catalog-stage-theme.md)), versions figées ([pdr-0010](decisions/pdr-0010-pinned-experimental-versions.md)), application des ADR génériques — orchestrateur backend en Go, Bloc, TDD/BDD ([pdr-0011](decisions/pdr-0011-adopt-knowledge-adrs.md)).

## Questions ouvertes majeures

Consigne du porteur : **tout laisser ouvert** ; rien n'est tranché dans les docs.

| Question | Pourquoi elle compte |
|---|---|
| Q-01 / Q-02 — agents et catalogue (fiche ≠ maquettes) | Fixent le contenu des actes 1 à 3 |
| Q-03 — A2UI v0.8 (maquettes) ou v0.9 (genui 0.10) | Fixe le protocole affiché et le code de rendu |
| Q-11 — confirmer `gpt-live-1` ([pdr-0012](decisions/pdr-0012-voice-provider-openai.md)) | Bloque J2 |
| Q-15 / Q-16 / Q-37 — où tourne le backend, agents A2A réels, qui produit l'A2UI | Structurent le backend |
| Q-12 — conférence et date | Fixe le calendrier de tous les jalons |

## Contribuer

| Besoin | Outil |
|---|---|
| Lire avant d'agir | skill `product-lookup` (avec `kb-lookup` pour les faits techniques) |
| Ajouter ou corriger un document, une exigence, une question | skill `product-curate` |
| Proposer, accepter, remplacer une décision | skill `product-decide` → `decisions/pdr-NNNN-*.md` |
| Mise à jour transverse (plusieurs zones) | agent `product-steward` |
| Contrôler | `python3 -I product/_tools/product_lint.py` (0 erreur exigée) |

Règles d'écriture : [`_conventions.md`](_conventions.md). L'assistant recommande, le porteur décide.

## Frontière `knowledge/` ↔ `product/`

| `knowledge/` | `product/` |
|---|---|
| Savoir **réutilisable** sur d'autres projets : faits vérifiés et datés, patterns, ADR technologiques génériques (`adr-*`) | Ce qui est **propre à Genesis Canvas** : fonctionnel, roadmap, architecture du produit, décisions produit (`pdr-*`) |
| Ex. : « GPT-Live n'émet pas d'événement d'interruption » `[rt-barge-in]` | Ex. : « l'orbe passe par l'état Interrompue » (RG-17) et la question de sa détection (Q-40) |
| Skills `kb-lookup`, `kb-curate` | Skills `product-lookup`, `product-curate`, `product-decide` |
