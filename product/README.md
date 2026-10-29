---
id: p-readme
title: Documentation produit Genesis Canvas
area: meta
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf, product/sources/design-example.pdf, AGENTS.md]
links: [pdr-0041-backend-in-this-repo-local-no-auth, pdr-0042-calendar-and-cut-order-validated, pdr-0043-light-spec-kit-sdd-template, p-conventions, p-sources, p-fn-vision, p-fn-requirements, p-fn-screen, p-ar-overview, p-rm-roadmap, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0019-six-limit-applies-to-surfaces, pdr-0020-act1-four-surfaces, pdr-0021-mockup-data-not-corrected, pdr-0022-gherkin-steps-no-leading-digit, pdr-0023-example-guided-composition, pdr-0024-act2-android-only, pdr-0025-top-bar-speaker-and-ai-lines, pdr-0026-desktop-only-target, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0045-app-backend-channel-wss-recommended, pdr-0046-flutter-3-47-8-pinned, pdr-0047-go-and-tool-versions-pinned, pdr-0048-session-log-only-no-otel-signoz, pdr-0049-sheet-gherkin-scenarios-only]
tags: [meta, readme, entree, carte]
---
# Genesis Canvas — documentation produit

**En bref.** Tout ce qui est **propre** à Genesis Canvas : ce que fait le produit, comment on y arrive, comment il est construit, et chaque décision prise. Les humains lisent cette page ; les agents IA partent de [`index.yaml`](index.yaml). Le savoir technique réutilisable vit dans [`knowledge/`](../knowledge/), cité par id (`[rt-barge-in]`).

## Le produit en 5 lignes

1. Une **app Flutter desktop** (Linux, [pdr-0028](decisions/pdr-0028-linux-demo-machine.md)) projetée pendant un talk de 45 min au Meetup Flutter Nantes le 2026-11-12 ([pdr-0027](decisions/pdr-0027-talk-context-meetup-flutter-nantes.md)) construit des écrans sous les yeux du public, à partir de la **voix** du speaker ([vision](functional/vision.md), fiche p1).
2. La voix déclenche un **orchestrateur** côté backend, qui délègue à des **agents A2A** ; ceux-ci, vrais serveurs A2A, renvoient de l'**UI déclarative A2UI**, rendue par **GenUI** avec un catalogue fermé ([overview](architecture/overview.md), [pdr-0036](decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)). Tout tourne en local ([pdr-0029](decisions/pdr-0029-local-docker-compose-hosting.md)).
3. Cas d'usage : **Release Copilot**, la décision go/no-go d'une release mobile 3.4 face à la 3.3, sur des **données fictives figées** ([pdr-0003](decisions/pdr-0003-use-case-release-copilot.md), [pdr-0005](decisions/pdr-0005-frozen-fictional-dataset.md)).
4. La démo tient en **3 actes** (créer, transformer, interagir), plus un acte 4 de rejeu du flux A2UI ([pdr-0032](decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)), sur un **écran unique en 6 zones** qui montre la fabrication ([pdr-0004](decisions/pdr-0004-mvp-three-acts.md), [écran](functional/screen.md)).
5. Message du talk : « L'agent ne génère pas du code, il génère de la donnée d'interface ; le développeur Flutter garde la main sur le rendu via son catalogue. » C'est un **livrable de conférence**, pas un produit de production ([pdr-0001](decisions/pdr-0001-conference-demo-deliverable.md)).

## Par où commencer

| Profil | Lire dans cet ordre |
|---|---|
| **Porteur** (relire, décider) | [questions ouvertes](roadmap/open-questions.md) → [maquettes (illustration) et différences](functional/mockups.md) → [décisions](decisions/index.yaml) → [roadmap](roadmap/roadmap.md) |
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
| [decisions/](decisions/index.yaml) | `pdr-0001` … `pdr-0043`, ADR hérités de `knowledge/` | Qu'a-t-on décidé, pourquoi, qui l'a décidé ? |
| méta | [conventions](_conventions.md), [sources](sources/README.md), [`index.yaml`](index.yaml) | Comment écrire ici, d'où viennent les faits ? |

## État au 2026-10-29

| Élément | État |
|---|---|
| Jalon | **J0 Cadrage et docs** en relecture par le porteur ; calendrier daté validé (pdr-0042) : J1 29/10 → J7 9/11, gel 10-11/11, talk 12/11 ([roadmap](roadmap/roadmap.md)) ; développement par la boucle autonome (`tools/loop/`, fonctionnalités dans `specs/NNN-*`, [pdr-0043](decisions/pdr-0043-light-spec-kit-sdd-template.md)) ; aucun code applicatif encore |
| Sources | fiche produit validée + 3 maquettes ([sources](sources/README.md)) |
| Talk | 45 min, Meetup Flutter Nantes, **2026-11-12**, enregistré ; logistique et supports gérés par le porteur ([pdr-0027](decisions/pdr-0027-talk-context-meetup-flutter-nantes.md)) |
| Spikes | SP-00 Widgetbook 4 fait ; J1 réduit (29-30/10) : SP-10 genui sur Linux d'abord, SP-01, SP-03, SP-02 réduit ; SP-04 à SP-07 absorbés dans les jalons ; SP-09 sans objet ([spikes](roadmap/spikes.md)) |
| Décisions | 43 PDR : 41 acceptées (dont 9 décisions contraintes : pdr-0018 à pdr-0026), 2 remplacées (pdr-0002 → pdr-0028, pdr-0006 → pdr-0032), aucune proposée ; 8 ADR hérités ([index](decisions/index.yaml)) |
| Questions | 65 au registre : 43 closes (37 tranchées, 3 sans objet, 3 gérées par le porteur), 22 ouvertes ; 22 écarts entre sources, dont E1, E2, E3, E4, E10, E11, E15, E16, E19, E20, E21 et E22 tranchés (21 fiche ↔ maquettes, 1 fiche ↔ ADR hérités) ([registre](roadmap/open-questions.md)) |

## Décisions clés

Liste complète et résumés : [`decisions/index.yaml`](decisions/index.yaml). Les plus structurantes : démo de conférence ([pdr-0001](decisions/pdr-0001-conference-demo-deliverable.md)), Flutter desktop Linux ([pdr-0028](decisions/pdr-0028-linux-demo-machine.md)), 3 actes ([pdr-0004](decisions/pdr-0004-mvp-three-acts.md)), rejeu A2UI en acte 4 et secours vidéo géré par le porteur ([pdr-0032](decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)), hébergement local ([pdr-0029](decisions/pdr-0029-local-docker-compose-hosting.md)), agents A2A réels ([pdr-0036](decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)), voix gpt-live-1 ([pdr-0012](decisions/pdr-0012-voice-provider-openai.md)), catalogue fermé et thème de scène ([pdr-0007](decisions/pdr-0007-closed-catalog-stage-theme.md)), versions figées ([pdr-0010](decisions/pdr-0010-pinned-experimental-versions.md)), A2UI v0.9 avec genui 0.10.4 ([pdr-0018](decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)), fiche produit = référence, maquettes = illustration ([pdr-0017](decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md)), application des ADR génériques — orchestrateur backend en Go, Bloc, TDD/BDD ([pdr-0011](decisions/pdr-0011-adopt-knowledge-adrs.md)).

## Questions ouvertes majeures

Règle en vigueur ([pdr-0017](decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md), remplace « tout laisser ouvert ») : la fiche produit fait foi, les maquettes n'illustrent que la vision et ne comptent pas pour le technique. Les questions à réponse unique imposée par les faits sont des **décisions contraintes**, tranchées par l'assistant et signalées au porteur ([_conventions.md](_conventions.md) § 5).

| Question | Pourquoi elle compte |
|---|---|
| Q-01, Q-02, Q-29, Q-60, Q-62 tranchées par le porteur (pdr-0013 à pdr-0016) ; décisions contraintes : Q-03 (pdr-0018, A2UI v0.9), Q-04 (pdr-0019, limite = surfaces), Q-28 (pdr-0020, acte 1 = 4 surfaces), Q-33 (pdr-0021), Q-34 (pdr-0022, steps sans chiffre), Q-38 (pdr-0023, composition guidée par exemples), Q-58 (pdr-0024, acte 2 Android seul), Q-59 (pdr-0025, répliques speaker + IA), Q-64 (pdr-0026, desktop seul) | Fixaient le contenu des actes 1 à 3 |
| Réponses du porteur du 2026-10-29 : Q-05, Q-06, Q-07, Q-08, Q-10, Q-11, Q-12, Q-13, Q-15, Q-16, Q-18, Q-19, Q-23, Q-26, Q-36, Q-37, Q-54, Q-56, Q-61 (pdr-0012 acceptée, pdr-0027 à pdr-0040) ; Q-45, Q-50, Q-51 sans objet ; Q-14, Q-24, Q-57 gérées par le porteur | Fixent le calendrier, la plateforme, l'hébergement et le backend |
| Q-52 — pas-à-pas du rejeu (reco : aucun, à confirmer) | Bloque J6 |
| SP-10 — genui sous Linux : ✅ confirmé le 2026-10-29 | Plus de risque plateforme connu ([pdr-0028](decisions/pdr-0028-linux-demo-machine.md)) |
| Q-25, Q-39, Q-46, Q-55, Q-63 tranchées par le porteur le 2026-10-29 (pdr-0046, pdr-0045, pdr-0047, pdr-0048, pdr-0049) | Fixent les versions, le canal app ↔ backend, l'observabilité et la couverture Gherkin |
| Q-17 — LLM des agents ; Q-43, Q-47 — niveau audio de l'orbe, mode de délégation GPT-Live (spike SP-02) | Bloquent J2 / J3 |

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
