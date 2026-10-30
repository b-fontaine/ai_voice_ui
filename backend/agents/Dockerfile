# Agents Genesis Canvas : image minimale, non-root (pdr-0029, pdr-0047).
# Contexte de build : backend/agents. L'agent est choisi par --build-arg AGENT=<nom>
# (binaire ./cmd/agent-<nom>) ; sans valeur, la construction échoue.
FROM golang:1.27.3@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b AS build
ARG AGENT
RUN test -n "$AGENT"
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/agent ./cmd/agent-${AGENT}

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab
COPY --from=build /out/agent /agent
ENTRYPOINT ["/agent"]
