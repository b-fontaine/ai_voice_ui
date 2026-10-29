# Orchestrateur Genesis Canvas : image minimale, non-root (pdr-0029, pdr-0047).
# Contexte de build : backend/orchestrator.
FROM golang:1.27.3 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/orchestrator ./cmd/orchestrator

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/orchestrator /orchestrator
ENTRYPOINT ["/orchestrator"]
