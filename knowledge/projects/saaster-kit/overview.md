---
id: proj-sk-overview
title: septeo_saaster_kit — vue d'ensemble
tags: [project, flutter, go, saas, bdd]
status: verified
updated: 2026-10-26
sources: ["~/septeo/septeo_saaster_kit (analyse locale du code, 2026-10-26)"]
links: [proj-sk-patterns, proj-avw-overview, arch-recommended-structure, test-coverage-ci]
---
# septeo_saaster_kit

Starter kit B2B SaaS.

- **Backend :** Go hexagonal, avec gRPC, Postgres, Temporal, et des tests BDD Godog + testcontainers.
- **Infra :** Kong, Keycloak / OIDC, SigNoz / OTel.
- **Workspace Flutter `frontend/` :**
  - `main_app` (package `saaster`), `website`
  - `design_system` (Atomic Design + Widgetbook)
  - `features/ai`
- **`main_app` :** découpé par couches horizontales :
  - `lib/core/{di,telemetry}`
  - `lib/data/{dto,repository}`
  - `lib/domain/{entities,protocol,usecases}`
  - `lib/ui/<domaine>/<feature>/{bloc,interactor,module,view}`
  - ⚠️ `frontend/CLAUDE.md` décrit pourtant une structure `features/<f>/{data,domain,presentation}`.
- **Chaîne :** DTO → Repository → UseCase (classe appelable `@injectable`) → Interactor → Bloc → UI.
- **`features/ai` :** copie **antérieure** du code voix d'ai_voice_widget, sans tools, sans Gemini câblé, sans GenUI, non intégrée à l'app, avec son propre `getIt` (risque de conflit).
- **Docs internes :**
  - `agent-os/standards/` : 18 standards, indexés dans `index.yml`.
  - `.claude/agents/` : 7 sous-agents.
  - Spec Kit : `.specify/memory/constitution.md`.
  - `docs/tdd.md`.
- **Règles affichées :** couverture ≥ 80 %, BDD avant implémentation, ne jamais supprimer un test qui échoue, composants `DS*` uniquement, pas de méthodes `_buildX()`.
- **CI :** Azure, build Docker uniquement. **Aucun test** n'y est lancé.
