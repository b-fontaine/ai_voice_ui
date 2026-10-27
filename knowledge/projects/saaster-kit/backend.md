---
id: proj-sk-backend
title: septeo_saaster_kit — ce que le backend Go offre à l'orchestrateur
tags: [project, go, backend, hexagonal, temporal, bdd, security]
status: verified
updated: 2026-10-27
sources: ["~/septeo/septeo_saaster_kit (analyse locale du code, 2026-10-27)"]
links: [proj-sk-overview, proj-sk-patterns, ma-backend-stack-recommendation, ma-backend-phase1-plan, ma-otel-genai-spans]
---
# Backend Go du saaster kit (`backend/customer_service`, lu le 2026-10-27)

**Réutilisable tel quel (chemins relatifs à `backend/customer_service/`) :**
- Hexagonal : `internal/{domain/entities, ports/in, ports/out, adapters/{grpc,repositories,temporal,observability,logger}, application/services}` ; DI manuelle dans `cmd/main.go`.
- OTel → SigNoz : `internal/adapters/observability/otel_facade.go` + port `internal/ports/out/observability.go`.
- Temporal : `internal/adapters/temporal/client.go`, modèle `internal/workflows/customer_workflows.go` + `customer_activities.go`.
- BDD : `tests/` (module séparé, Godog v0.13.0, testcontainers-go v0.37.0), `tests/testcontainers.go`, 6 `tests/features/*.feature` dont `customer_temporal_workflows.feature`.
- Migrations golang-migrate v4.18.3 : `migrations/`.
- Contrat gRPC : `proto/customer.proto`.
- Racine : `docker-compose.yml` (temporal, keycloak, postgres, signoz-otel-collector, customer_service), `infra/kong/kong.yml` (routes REST via plugin `grpc-gateway`, `rate-limiting` par route), `azure-pipelines.yml`.

**Versions** : `go 1.23.0` / `toolchain go1.24.3`, `otel v1.35.0`, `temporal sdk v1.34.0`, `grpc v1.72.0`, `golang-jwt/v5 v5.2.2`.

⚠️ Pièges (à ne pas copier)
- `internal/adapters/grpc/server.go:137` : `jwt.Parser.ParseUnverified` — signature JWT jamais vérifiée ; `kong.yml` n'a aucun plugin jwt/oidc.
- `kong.yml` : `cors` avec `origins: ["*"]` et `credentials: true`.
- Seulement `grpc.UnaryInterceptor` (`server.go:60`) : pas d'intercepteur de stream.
- `Makefile` l. 33-34 : chemins `/Users/bfontaine/go/bin` en dur.
- `azure-pipelines.yml` : tâches `Docker@2` seulement, aucun `go test` ni Godog.
- Les SDK agents Go exigent Go ≥ 1.26 (adk/v2 : 1.26.10) et OTel ≥ v1.47 : prévoir un module séparé.
