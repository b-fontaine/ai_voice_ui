#!/usr/bin/env bash
# Contrôle statique de docker-compose.yaml (pdr-0029, pdr-0031, pdr-0041).
# Lit uniquement `docker compose config --no-env-resolution --format json` (jamais la
# sortie résolue, jamais `.env`) ; fonctionne sans `.env`. N'affiche aucune valeur de configuration.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

docker compose config --no-env-resolution --format json | python3 -I -c '
import json, sys

cfg = json.load(sys.stdin)
services = cfg.get("services", {})
networks = cfg.get("networks", {})
errors = []


def check(ok, message):
    if not ok:
        errors.append(message)


orch = services.get("orchestrator")
agent = services.get("agent-quality")
check(orch is not None, "service orchestrator absent")
check(agent is not None, "service agent-quality absent")
orch = orch or {}
agent = agent or {}

check(not agent.get("ports"), "agent-quality ne doit publier aucun port")
check(set((agent.get("networks") or {}).keys()) == {"agents"},
      "agent-quality doit etre uniquement sur le reseau agents")
check(bool((networks.get("agents") or {}).get("internal")), "le reseau agents doit etre internal: true")
check({"default", "agents"} <= set((orch.get("networks") or {"default": None}).keys()),
      "orchestrator doit etre sur les reseaux default et agents")
check("env_file" not in agent, "agent-quality ne doit pas recevoir env_file")

for name, svc in (("orchestrator", orch), ("agent-quality", agent)):
    check(svc.get("read_only") is True, name + " : read_only requis")
    check("ALL" in (svc.get("cap_drop") or []), name + " : cap_drop ALL requis")
    check("no-new-privileges:true" in (svc.get("security_opt") or []),
          name + " : no-new-privileges:true requis")
    check(bool(svc.get("healthcheck")), name + " : healthcheck requis")

for port in orch.get("ports") or []:
    check(isinstance(port, dict) and port.get("host_ip") == "127.0.0.1",
          "orchestrator : port publie hors de 127.0.0.1")

env = orch.get("environment") or {}
check(str(env.get("AGENTS", "")).startswith("http://agent-quality:8090/"),
      "orchestrator : AGENTS doit pointer vers http://agent-quality:8090/")
# R6(d) : une seule valeur de catalogue A2UI, partagée (ancre YAML) par orchestrator et agent-quality.
agent_env = agent.get("environment") or {}
check(bool(env.get("A2UI_CATALOG_ID")) and env.get("A2UI_CATALOG_ID") == agent_env.get("A2UI_CATALOG_ID"),
      "A2UI_CATALOG_ID doit etre identique (ancre) pour orchestrator et agent-quality")
dep = (orch.get("depends_on") or {}).get("agent-quality") or {}
check(dep.get("condition") == "service_healthy",
      "orchestrator : depends_on agent-quality service_healthy requis")

check("sk-" not in json.dumps(cfg), "une valeur contient sk- (secret possible)")

if errors:
    for e in errors:
        print("ECHEC : " + e, file=sys.stderr)
    sys.exit(1)
print("check-compose : OK")
'
