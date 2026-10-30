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
check(orch is not None, "service orchestrator absent")
orch = orch or {}

# Tous les services agent-* sont contrôlés de la même façon (A8 e).
agent_names = sorted(n for n in services if n.startswith("agent-"))
for required in ("agent-quality", "agent-voice", "agent-delivery"):
    check(required in services, "service " + required + " absent")

check(bool((networks.get("agents") or {}).get("internal")), "le reseau agents doit etre internal: true")
check({"default", "agents"} <= set((orch.get("networks") or {"default": None}).keys()),
      "orchestrator doit etre sur les reseaux default et agents")

env = orch.get("environment") or {}
depends = orch.get("depends_on") or {}

for name in ["orchestrator"] + agent_names:
    svc = services[name]
    check(svc.get("read_only") is True, name + " : read_only requis")
    check("ALL" in (svc.get("cap_drop") or []), name + " : cap_drop ALL requis")
    check("no-new-privileges:true" in (svc.get("security_opt") or []),
          name + " : no-new-privileges:true requis")
    check(bool(svc.get("healthcheck")), name + " : healthcheck requis")

for name in agent_names:
    agent = services[name]
    agent_env = agent.get("environment") or {}
    check(not agent.get("ports"), name + " ne doit publier aucun port")
    check(set((agent.get("networks") or {}).keys()) == {"agents"},
          name + " doit etre uniquement sur le reseau agents")
    check("env_file" not in agent, name + " ne doit pas recevoir env_file")
    # R6(d) : une seule valeur de catalogue A2UI, partagée (ancre YAML) par orchestrateur et chaque agent.
    check(bool(env.get("A2UI_CATALOG_ID")) and env.get("A2UI_CATALOG_ID") == agent_env.get("A2UI_CATALOG_ID"),
          "A2UI_CATALOG_ID doit etre identique (ancre) pour orchestrator et " + name)
    dep = depends.get(name) or {}
    check(dep.get("condition") == "service_healthy",
          "orchestrator : depends_on " + name + " service_healthy requis")

for port in orch.get("ports") or []:
    check(isinstance(port, dict) and port.get("host_ip") == "127.0.0.1",
          "orchestrator : port publie hors de 127.0.0.1")

# Cartes agents : nom et URL de chaque agent dans AGENTS.
agents_cfg = str(env.get("AGENTS", ""))
for label, url in (
    ("Qualité", "http://agent-quality:8090/.well-known/agent-card.json"),
    ("Voix du client", "http://agent-voice:8091/.well-known/agent-card.json"),
    ("Livraison", "http://agent-delivery:8092/.well-known/agent-card.json"),
):
    check((label + "=" + url) in agents_cfg.split(","),
          "orchestrator : AGENTS doit contenir la carte " + label)

# A8 f : composants autorisés = exactement le catalogue Genesis J3, jamais Column ni Text.
with open("contracts/a2ui/genesis/v1/catalog.json", encoding="utf-8") as fh:
    catalog_components = json.load(fh)["components"]
raw_components = str(env.get("A2UI_COMPONENTS", ""))
default_components = raw_components
if default_components.startswith("${A2UI_COMPONENTS:-") and default_components.endswith("}"):
    default_components = default_components[len("${A2UI_COMPONENTS:-"):-1]
listed = [c.strip() for c in default_components.split(",") if c.strip()]
check(listed == catalog_components,
      "A2UI_COMPONENTS (defaut) doit etre exactement la liste components du catalogue genesis/v1")
check("Column" not in listed and "Text" not in listed,
      "A2UI_COMPONENTS ne doit contenir ni Column ni Text")
check(bool(env.get("A2UI_ALLOWED_PROPS")), "orchestrator : A2UI_ALLOWED_PROPS requis")
check(bool(env.get("A2UI_BINDING_PROPS")), "orchestrator : A2UI_BINDING_PROPS requis")

check("sk-" not in json.dumps(cfg), "une valeur contient sk- (secret possible)")

if errors:
    for e in errors:
        print("ECHEC : " + e, file=sys.stderr)
    sys.exit(1)
print("check-compose : OK")
'
