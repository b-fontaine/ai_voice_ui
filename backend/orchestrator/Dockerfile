# Orchestrateur Genesis Canvas : image minimale, non-root (pdr-0029, pdr-0047).
# Contexte de build : backend/orchestrator.
FROM golang:1.27.3@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/orchestrator ./cmd/orchestrator
# Dossier du journal : un volume nommé neuf hérite de son propriétaire et de ses droits.
RUN mkdir -p /out/journal

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab
COPY --from=build /out/orchestrator /orchestrator
COPY --from=build --chown=65532:65532 /out/journal /var/lib/genesis/journal
ENTRYPOINT ["/orchestrator"]
