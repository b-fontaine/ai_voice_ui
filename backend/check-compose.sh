#!/usr/bin/env bash
# Contrôle statique de docker-compose.yaml (pdr-0029, pdr-0031, pdr-0041).
# Lit uniquement `docker compose config --no-env-resolution --format json` (jamais la
# sortie résolue, jamais `.env`) ; fonctionne sans `.env`. N'affiche aucune valeur de configuration.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# Le profil bench (composer-bench) est contrôlé comme le reste.
COMPOSE_PROFILES=bench docker compose config --no-env-resolution --format json | python3 -I -c '
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
    # R1 : le Dockerfile des agents impose ARG AGENT (sans défaut) ; le compose doit le fournir.
    build_args = (agent.get("build") or {}).get("args") or {}
    check(build_args.get("AGENT") == name[len("agent-"):],
          name + " : build.args.AGENT doit valoir " + name[len("agent-"):])
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
    catalog = json.load(fh)
catalog_components = catalog["components"]  # liste blanche J3, pas catalogComponents (étagère de l app)
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


def default_of(name):
    raw = str(env.get(name, ""))
    prefix = "${" + name + ":-"
    if raw.startswith(prefix) and raw.endswith("}"):
        raw = raw[len(prefix):-1]
    return {x.strip() for x in raw.split(",") if x.strip()}


# R5 (c) : propriétés admises et propriétés liées = unions déclarées par le catalogue (égalité d ensembles).
definitions = catalog.get("definitions", {})
catalog_props = set()
catalog_binding = set()
for definition in definitions.values():
    catalog_props.update(definition.get("properties", []))
    catalog_binding.update((definition.get("binding") or {}).keys())
check(default_of("A2UI_ALLOWED_PROPS") == catalog_props,
      "A2UI_ALLOWED_PROPS (defaut) doit egaler l union des properties du catalogue genesis/v1")
check(default_of("A2UI_BINDING_PROPS") == catalog_binding,
      "A2UI_BINDING_PROPS (defaut) doit egaler l union des cles binding du catalogue genesis/v1")

# R4 : sous-chemins inscriptibles de updateDataModel = ceux du catalogue (chemin:type, égalité d ensembles).
catalog_writable = set()
for definition in definitions.values():
    for path, typ in ((definition.get("dataModel") or {}).get("writableSubPaths") or {}).items():
        catalog_writable.add(path + ":" + typ)
check(default_of("A2UI_WRITABLE_SUBPATHS") == catalog_writable,
      "A2UI_WRITABLE_SUBPATHS (defaut) doit egaler les writableSubPaths du catalogue genesis/v1")
for name in agent_names:
    check("A2UI_WRITABLE_SUBPATHS" not in (services[name].get("environment") or {}),
          name + " : A2UI_WRITABLE_SUBPATHS ne concerne que l orchestrateur")

# pdr-0074 (012) : passerelle LLM interne. Seul l orchestrateur porte la cle et sort ;
# les agents l appellent par son IP fixe sur le reseau agents.
import re


def default_value(raw):
    raw = str(raw)
    m = re.fullmatch(r"\$\{[A-Za-z0-9_]+:?-(.*)\}", raw, re.S)
    return m.group(1) if m else raw


def seconds(raw, label):
    m = re.fullmatch(r"(\d+(?:\.\d+)?)(ms|s|m)", default_value(raw).strip())
    if not m:
        errors.append(label + " : duree invalide")
        return None
    return float(m.group(1)) * {"ms": 0.001, "s": 1, "m": 60}[m.group(2)]


gw_addr = default_value(env.get("LLM_GATEWAY_ADDR", ""))
check(bool(gw_addr), "orchestrator : LLM_GATEWAY_ADDR requis")
gw_host, _, gw_port = gw_addr.rpartition(":")
check(gw_host not in ("", "0.0.0.0", "::"), "orchestrator : LLM_GATEWAY_ADDR doit etre l IP fixe sur agents, jamais 0.0.0.0")
orch_agents_ip = ((orch.get("networks") or {}).get("agents") or {}).get("ipv4_address")
check(orch_agents_ip == gw_host, "orchestrator : LLM_GATEWAY_ADDR doit etre son ipv4_address sur le reseau agents")
subnets = [c.get("subnet") for c in (((networks.get("agents") or {}).get("ipam") or {}).get("config") or [])]
check(bool(subnets), "le reseau agents doit declarer un sous-reseau (ipam) fixe")
for port in orch.get("ports") or []:
    check(str(port.get("target")) != gw_port and str(port.get("published")) != gw_port,
          "orchestrator : le port de la passerelle LLM ne doit jamais etre publie")
for name in agent_names:
    for port in services[name].get("ports") or []:
        check(str(port.get("target")) != gw_port, name + " : port de la passerelle LLM publie")

allowed = {x.strip() for x in default_value(env.get("LLM_GATEWAY_ALLOWED_SOURCES", "")).split(",") if x.strip()}
gw_timeout = seconds(env.get("COMPOSER_TIMEOUT", ""), "orchestrator : COMPOSER_TIMEOUT") if env.get("COMPOSER_TIMEOUT") else None
check(gw_timeout is not None, "orchestrator : COMPOSER_TIMEOUT requis")
agent_timeout_cap = seconds(env.get("AGENT_TIMEOUT", ""), "orchestrator : AGENT_TIMEOUT")
wired = []
for name in agent_names:
    agent_env = services[name].get("environment") or {}
    for key in agent_env:
        check(not key.startswith("OPENAI_") and key != "COMPOSER_MODEL",
              name + " : " + key + " ne doit pas etre fourni a un agent")
    url = default_value(agent_env.get("COMPOSER_LLM_URL", ""))
    if not url:
        continue
    wired.append(name)
    ip = ((services[name].get("networks") or {}).get("agents") or {}).get("ipv4_address")
    check(bool(ip), name + " : ipv4_address fixe requis sur agents (sources autorisees de la passerelle)")
    check(ip in allowed, name + " : son IP doit figurer dans LLM_GATEWAY_ALLOWED_SOURCES")
    check(url.startswith("http://" + gw_host + ":" + gw_port + "/"),
          name + " : COMPOSER_LLM_URL doit viser la passerelle de l orchestrateur sur agents")
    t = seconds(agent_env.get("COMPOSER_TIMEOUT", ""), name + " : COMPOSER_TIMEOUT") if agent_env.get("COMPOSER_TIMEOUT") else None
    check(t is not None, name + " : COMPOSER_TIMEOUT requis avec COMPOSER_LLM_URL")
    if t is not None and gw_timeout is not None:
        check(t >= gw_timeout + 0.5, name + " : COMPOSER_TIMEOUT doit depasser celui de la passerelle d au moins 500 ms")
    if t is not None and agent_timeout_cap is not None:
        check(t < agent_timeout_cap, name + " : COMPOSER_TIMEOUT doit rester sous AGENT_TIMEOUT (le repli doit tenir)")
source_names = agent_names + (["composer-bench"] if "composer-bench" in services else [])
for ip in allowed:
    check(any(((services[n].get("networks") or {}).get("agents") or {}).get("ipv4_address") == ip for n in source_names),
          "LLM_GATEWAY_ALLOWED_SOURCES : " + ip + " n est l IP d aucun agent ni du banc")
bench = services.get("composer-bench")
if bench is not None:
    check(not bench.get("ports"), "composer-bench ne doit publier aucun port")
    check("env_file" not in bench, "composer-bench ne doit pas recevoir env_file")
    check(set((bench.get("networks") or {}).keys()) == {"agents"}, "composer-bench doit etre uniquement sur le reseau agents")
    bench_env = bench.get("environment") or {}
    for key in bench_env:
        check(not key.startswith("OPENAI_") and key != "COMPOSER_MODEL", "composer-bench : " + key + " ne doit pas lui etre fourni")
    check(default_value(bench_env.get("COMPOSER_LLM_URL", "")).startswith("http://" + gw_host + ":" + gw_port + "/"),
          "composer-bench : COMPOSER_LLM_URL doit viser la passerelle de l orchestrateur sur agents")
    check(((bench.get("networks") or {}).get("agents") or {}).get("ipv4_address") in allowed,
          "composer-bench : son IP doit figurer dans LLM_GATEWAY_ALLOWED_SOURCES")
burst = default_value(env.get("COMPOSER_RATE_BURST", "0"))
check(burst.isdigit() and int(burst) >= max(1, len(wired)), "orchestrator : COMPOSER_RATE_BURST doit couvrir les agents branches")

check("sk-" not in json.dumps(cfg), "une valeur contient sk- (secret possible)")

if errors:
    for e in errors:
        print("ECHEC : " + e, file=sys.stderr)
    sys.exit(1)
print("check-compose : OK")
'
