#!/usr/bin/env python3
"""Lint de la documentation produit product/ (stdlib uniquement, sans PyYAML).

Usage :
    python3 -I product/_tools/product_lint.py

Vérifie : frontmatter complet (id, title, area, status, updated, sources, links, tags),
ids uniques et préfixés selon le dossier, area/status/updated valides, champs des
décisions pdr-* (decision_status, decided_on, decided_by, scope, supersedes,
superseded_by),
numérotation sans trou ni doublon (next_id au format pdr-NNNN), decision_status de
decisions/index.yaml identique à celui du fichier, questions « Avant Jn » de
roadmap/open-questions.md citées dans la colonne « Dépend de » du jalon Jn, links résolus vers un id product ou un
id de note knowledge/, en-têtes « # id: » des .feature, index.yaml de zone <-> fichiers
réels, product/index.yaml (zones, meta, entrypoints, tasks), liens markdown relatifs,
taille des documents (avertissement > 150 lignes, erreur > 250).
Code retour 1 si au moins une erreur.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # product/
REPO = os.path.dirname(ROOT)
KNOWLEDGE = os.path.join(REPO, "knowledge")

REQUIRED = ("id", "title", "area", "status", "updated", "sources", "links", "tags")
AREAS = {"functional", "roadmap", "architecture", "decisions", "meta"}
STATUSES = {"draft", "validated", "proposed", "superseded"}
ZONES = {  # dossier -> (préfixe d'id, area attendue)
    "functional": ("p-fn-", "functional"),
    "architecture": ("p-ar-", "architecture"),
    "roadmap": ("p-rm-", "roadmap"),
    "decisions": ("pdr-", "decisions"),
}
META_DIRS = ("", "sources")  # racine de product/ et sources/ : préfixe p-, area meta
ZONE_PREFIXES = tuple(p for p, _ in ZONES.values())
PDR_FIELDS = ("decision_status", "decided_on", "decided_by", "scope", "supersedes", "superseded_by")
PDR_SCOPES = {"fonctionnel", "technique", "mixte"}
DECISION_STATUS = {  # decision_status -> status(es) de frontmatter acceptés
    "proposée": {"proposed"},
    "acceptée": {"validated"},
    "remplacée": {"superseded"},  # forme complète : « remplacée par pdr-NNNN-<slug> »
    "abandonnée": {"superseded"},
}
SOFT_LINES, MAX_LINES = 150, 250
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PDR_RE = re.compile(r"^pdr-(\d{4})-[a-z0-9]+(?:-[a-z0-9]+)*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ENTRY_RE = re.compile(r"^\s*-\s*\{\s*id:\s*([^,}\s]+)\s*(?:,\s*path:\s*([^,}\s]+))?")
MDLINK_RE = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
FEATURE_ID_RE = re.compile(r"^#\s*id:\s*(\S+)\s*$")
REQ_TAG_RE = re.compile(r"@((?:FR|NFR)-\d+)\b")

errors, warnings = [], []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def rel(p):
    return os.path.relpath(p, REPO)


def flow_list(s):
    s = s.strip()
    if not (s.startswith("[") and s.endswith("]")):
        return None
    out = []
    for x in s[1:-1].split(","):
        x = x.strip().strip('"').strip("'")
        if x:
            out.append(x)
    return out


def scalar(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v


def parse_frontmatter(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    if not lines or lines[0].strip() != "---":
        return None, lines
    fm, key = {}, None
    for i, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            fm["__end__"] = i
            break
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*?)\s*$", line)
        if m:
            key, val = m.group(1), m.group(2)
            if "#" in val and not val.startswith(("'", '"')):
                val = re.sub(r"\s+#.*$", "", val)
            lst = flow_list(val)
            fm[key] = lst if lst is not None else ([] if val == "" else scalar(val))
        elif key and re.match(r"^\s+-\s+", line):
            if not isinstance(fm.get(key), list):
                fm[key] = []
            fm[key].append(re.sub(r"^\s+-\s+", "", line).strip().strip('"'))
    if "__end__" not in fm:
        return None, lines
    return fm, lines


def count_lines(lines):
    return len(lines) - (1 if lines and lines[-1] == "" else 0)


def check_size(r, lines):
    n = count_lines(lines)
    if n > MAX_LINES:
        err(f"{r} : {n} lignes (max {MAX_LINES})")
    elif n > SOFT_LINES:
        warn(f"{r} : {n} lignes (> {SOFT_LINES}, conventions)")


def walk_docs():
    """Documents de product/ : .md (hors _template.md) et .feature ; ignore . et _ (dossiers)."""
    for d, ds, fs in os.walk(ROOT):
        ds[:] = sorted(x for x in ds if not x.startswith((".", "_")))
        r = os.path.relpath(d, ROOT)
        r = "" if r == "." else r
        for f in sorted(fs):
            if f == "_template.md":
                continue
            if r.split(os.sep)[0] == "sources" and f != "README.md":
                continue  # sources/ : seuls README.md est documenté, le reste est matière brute
            if f.endswith((".md", ".feature")):
                yield os.path.join(d, f), r


def zone_of(r):
    top = r.split(os.sep)[0] if r else ""
    return top


def knowledge_ids():
    ids = set()
    if not os.path.isdir(KNOWLEDGE):
        warn("knowledge/ introuvable : les links vers la base de connaissances ne sont pas vérifiés")
        return None
    for d, ds, fs in os.walk(KNOWLEDGE):
        ds[:] = sorted(x for x in ds if not x.startswith((".", "_")))
        for f in fs:
            if not f.endswith(".md"):
                continue
            try:
                with open(os.path.join(d, f), encoding="utf-8") as fh:
                    head = fh.read(4000).split("\n")
            except OSError:
                continue
            if not head or head[0].strip() != "---":
                continue
            for line in head[1:]:
                if line.strip() == "---":
                    break
                m = re.match(r"^id:\s*(\S+)", line)
                if m:
                    ids.add(m.group(1).strip("'\""))
                    break
    return ids


def strip_code(text):
    text = re.sub(r"^(```|~~~).*?^\1\s*$", "", text, flags=re.M | re.S)
    return re.sub(r"`[^`\n]*`", "", text)


def check_md_links(path, body):
    r = rel(path)
    base = os.path.dirname(path)
    for target in MDLINK_RE.findall(strip_code(body)):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
            continue  # url absolue, mailto:, ancre locale
        t = target.split("#", 1)[0].split("?", 1)[0]
        if not t:
            continue
        dest = os.path.normpath(os.path.join(base, t))
        if not os.path.exists(dest):
            err(f"{r} : lien markdown cassé -> {target}")


def read_lines(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().split("\n")


def section_entries(lines):
    """Renvoie {section_de_premier_niveau: [(n, ligne), ...]} pour un YAML simple."""
    out, section = {}, None
    for n, line in enumerate(lines, 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if re.match(r"^[A-Za-z_]", line):
            section = line.split(":", 1)[0].strip()
            out.setdefault(section, [])
            out[section].append((n, line))
            continue
        if section:
            out[section].append((n, line))
    return out


def top_value(lines, key):
    for line in lines:
        m = re.match(rf"^{re.escape(key)}:\s*(.*?)\s*$", line)
        if m:
            return scalar(m.group(1))
    return None


def check_zone_index(zone, docs_by_path, all_ids, k_ids):
    zdir = os.path.join(ROOT, zone)
    ip = os.path.join(zdir, "index.yaml")
    r_ip = rel(ip)
    expected = {p for p, (_, z) in docs_by_path.items() if z == zone}
    if not os.path.isfile(ip):
        err(f"{r_ip} absent")
        return None
    lines = read_lines(ip)
    secs = section_entries(lines)
    if top_value(lines, "domain") != zone:
        err(f"{r_ip} : 'domain: {zone}' attendu")
    if not top_value(lines, "description"):
        err(f"{r_ip} : description absente")
    if "docs" not in secs:
        err(f"{r_ip} : clé 'docs' absente")
    seen = {}
    for n, line in secs.get("docs", [])[1:]:
        m = ENTRY_RE.match(line)
        if not m or not m.group(2):
            if re.match(r"^\s*-\s*", line):
                err(f"{r_ip}:{n} : entrée illisible (attendu {{id: .., path: .., summary: .., tags: [..]}})")
            continue
        did, p = m.group(1), os.path.normpath(os.path.join(zdir, m.group(2)))
        if p in seen:
            err(f"{r_ip}:{n} : chemin listé deux fois {m.group(2)}")
        seen[p] = did
        if not os.path.isfile(p):
            err(f"{r_ip}:{n} : fichier inexistant {m.group(2)}")
        elif p not in docs_by_path:
            err(f"{r_ip}:{n} : {m.group(2)} sans id valide (frontmatter ou « # id: »)")
        elif docs_by_path[p][0] != did:
            err(f"{r_ip}:{n} : id {did} != id du fichier {docs_by_path[p][0]}")
        if "summary:" not in line:
            warn(f"{r_ip}:{n} : summary absent pour {did}")
    for p in sorted(expected - set(seen)):
        err(f"{r_ip} : document non indexé {os.path.relpath(p, zdir)}")
    # decisions : section inherited -> ADR de knowledge/
    for n, line in secs.get("inherited", [])[1:]:
        m = ENTRY_RE.match(line)
        if not m:
            if re.match(r"^\s*-\s*", line):
                err(f"{r_ip}:{n} : entrée inherited illisible")
            continue
        if k_ids is not None and m.group(1) not in k_ids:
            err(f"{r_ip}:{n} : inherited -> id knowledge inexistant {m.group(1)}")
        if m.group(2) and not os.path.isfile(os.path.normpath(os.path.join(zdir, m.group(2)))):
            err(f"{r_ip}:{n} : inherited -> fichier inexistant {m.group(2)}")
    return lines


def check_decisions(docs, index_lines):
    pdrs = {nid: fm for nid, fm in docs.items() if nid.startswith("pdr-")}
    nums = {}
    for nid, fm in pdrs.items():
        r = fm["__rel__"]
        m = PDR_RE.match(nid)
        if not m:
            err(f"{r} : id de décision invalide {nid} (attendu pdr-NNNN-<slug>)")
            continue
        stem = os.path.splitext(os.path.basename(fm["__path__"]))[0]
        if stem != nid:
            err(f"{r} : le nom de fichier doit être {nid}.md")
        nums.setdefault(int(m.group(1)), []).append(nid)
        for k in PDR_FIELDS:
            if k not in fm:
                err(f"{r} : champ de décision '{k}' absent")
        raw = fm.get("decision_status")
        raw = raw if isinstance(raw, str) else ""
        m_rep = re.match(r"^remplacée par\s+(pdr-\S+)$", raw)
        ds = "remplacée" if m_rep else raw
        if ds not in DECISION_STATUS or ds == "remplacée" and not m_rep:
            err(f"{r} : decision_status invalide {raw!r} "
                f"(attendu proposée | acceptée | remplacée par pdr-NNNN-<slug> | abandonnée)")
        elif fm.get("status") not in DECISION_STATUS[ds]:
            err(f"{r} : decision_status « {raw} » incohérent avec status {fm.get('status')!r} "
                f"(attendu {', '.join(sorted(DECISION_STATUS[ds]))})")
        if "decided_on" in fm and not (isinstance(fm["decided_on"], str) and DATE_RE.match(fm["decided_on"])):
            err(f"{r} : decided_on n'est pas une date AAAA-MM-JJ")
        if "decided_by" in fm and not (isinstance(fm["decided_by"], str) and fm["decided_by"].strip()):
            err(f"{r} : decided_by vide (toujours indiquer qui décide ou doit décider)")
        if "scope" in fm and fm["scope"] not in PDR_SCOPES:
            err(f"{r} : scope invalide {fm['scope']!r} (attendu {' | '.join(sorted(PDR_SCOPES))})")
        sup = fm.get("supersedes")
        if "supersedes" in fm and not isinstance(sup, list):
            err(f"{r} : 'supersedes' doit être une liste")
            sup = []
        sby = fm.get("superseded_by")
        sby = [] if sby in (None, "", "null", "~") else (sby if isinstance(sby, list) else [sby])
        fm["__sby__"], fm["__sup__"] = sby, sup or []
        for x in fm["__sup__"] + sby:
            if x not in pdrs:
                err(f"{r} : supersedes/superseded_by -> décision inexistante {x}")
        if ds == "remplacée":
            if not sby:
                err(f"{r} : décision remplacée sans superseded_by")
            elif m_rep and m_rep.group(1) not in sby:
                err(f"{r} : « {raw} » != superseded_by {sby}")
        elif sby:
            err(f"{r} : superseded_by renseigné mais decision_status « {raw} »")
    for nid, fm in pdrs.items():
        for x in fm.get("__sby__", []):
            if x in pdrs and nid not in pdrs[x].get("__sup__", pdrs[x].get("supersedes") or []):
                warn(f"{fm['__rel__']} : {x} ne déclare pas supersedes: [{nid}]")
    for n, ids in sorted(nums.items()):
        if len(ids) > 1:
            err(f"numéro de décision {n:04d} utilisé plusieurs fois : {', '.join(ids)}")
    if nums:
        top = max(nums)
        missing = [f"{i:04d}" for i in range(1, top + 1) if i not in nums]
        if missing:
            err(f"numérotation pdr avec trou(s) : {', '.join(missing)}")
    else:
        top = 0
    if index_lines is not None:
        nv = top_value(index_lines, "next_id")
        m = re.match(r"^pdr-(\d{4})$", nv or "")
        if not m:
            err(f"product/decisions/index.yaml : next_id absent ou mal formé ({nv!r}, attendu pdr-NNNN)")
        elif int(m.group(1)) != top + 1:
            err(f"product/decisions/index.yaml : next_id {nv} incohérent (attendu pdr-{top + 1:04d})")


def check_decision_index_status(docs, index_lines):
    """decision_status de chaque entrée de decisions/index.yaml == celui du fichier."""
    if index_lines is None:
        return
    for n, line in enumerate(index_lines, 1):
        m = ENTRY_RE.match(line)
        if not m or not m.group(1).startswith("pdr-"):
            continue
        nid = m.group(1)
        ms = re.search(r"decision_status:\s*([^}]+?)\s*\}\s*$", line)
        if not ms:
            err(f"product/decisions/index.yaml:{n} : decision_status absent pour {nid}")
            continue
        iv = ms.group(1).strip().strip('"').strip("'")
        fv = docs.get(nid, {}).get("decision_status")
        if nid in docs and iv != fv:
            err(f"product/decisions/index.yaml:{n} : decision_status « {iv} » != fichier « {fv} » ({nid})")


def check_roadmap_dependencies():
    """Chaque Q-xx « Avant Jn » du registre figure dans la colonne « Dépend de » du jalon Jn."""
    oq = os.path.join(ROOT, "roadmap", "open-questions.md")
    rm = os.path.join(ROOT, "roadmap", "roadmap.md")
    if not (os.path.isfile(oq) and os.path.isfile(rm)):
        return
    due = {}
    for line in read_lines(oq):
        m = re.match(r"^\|\s*(Q-\d+)\b", line)
        if not m:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        mj = re.search(r"\bAvant\s+(J\d)\b", cells[-2])
        if mj:
            due.setdefault(mj.group(1), []).append(m.group(1))
    header, deps = None, {}
    for line in read_lines(rm):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None and "Dépend de" in cells:
            header = cells.index("Dépend de")
            continue
        mj = re.match(r"^\*\*(J\d)\*\*", cells[0]) if cells else None
        if header is not None and mj and len(cells) > header:
            deps[mj.group(1)] = set(re.findall(r"\bQ-\d+\b", cells[header]))
    if header is None:
        err("product/roadmap/roadmap.md : colonne « Dépend de » introuvable")
        return
    for j, qs in sorted(due.items()):
        if j not in deps:
            err(f"product/roadmap/roadmap.md : jalon {j} absent alors que des questions ont l'échéance « Avant {j} »")
            continue
        missing = [q for q in qs if q not in deps[j]]
        if missing:
            err(f"product/roadmap/roadmap.md : {j} « Dépend de » ne cite pas {', '.join(missing)} (échéance « Avant {j} »)")


def check_root_index(docs, docs_by_path, k_ids):
    ip = os.path.join(ROOT, "index.yaml")
    if not os.path.isfile(ip):
        err("product/index.yaml absent")
        return
    lines = read_lines(ip)
    secs = section_entries(lines)
    for key in ("zones", "tasks"):
        if key not in secs:
            err(f"product/index.yaml : section '{key}' absente")
    zones, cur = [], None
    for n, line in secs.get("zones", [])[1:]:
        s = line.strip()
        m = re.match(r"^-\s*name:\s*(\S+)", s)
        if m:
            cur = {"name": m.group(1), "line": n}
            zones.append(cur)
            continue
        m = re.match(r"^(index|prefix|keywords|description):\s*(.*)$", s)
        if m and cur is not None:
            v = m.group(2)
            cur[m.group(1)] = flow_list(v) if m.group(1) == "keywords" else scalar(v)
    names = set()
    for z in zones:
        names.add(z["name"])
        if z["name"] not in ZONES:
            err(f"product/index.yaml:{z['line']} : zone inconnue {z['name']}")
            continue
        want = f"{z['name']}/index.yaml"
        if os.path.normpath(z.get("index") or "") != os.path.normpath(want):
            err(f"product/index.yaml:{z['line']} : index de {z['name']} attendu {want} (lu {z.get('index')!r})")
        if z.get("prefix") and z["prefix"] != ZONES[z["name"]][0]:
            err(f"product/index.yaml:{z['line']} : prefix {z['prefix']} != {ZONES[z['name']][0]}")
        if not z.get("keywords"):
            err(f"product/index.yaml:{z['line']} : keywords absents pour {z['name']}")
        if not z.get("description"):
            err(f"product/index.yaml:{z['line']} : description absente pour {z['name']}")
    for zone in sorted(ZONES):
        if os.path.isdir(os.path.join(ROOT, zone)) and zone not in names:
            err(f"product/index.yaml : zone {zone}/ non déclarée dans zones")
    # meta : documents de la racine et de sources/
    meta_seen = set()
    for n, line in secs.get("meta", [])[1:]:
        m = ENTRY_RE.match(line)
        if not m:
            continue
        mid = m.group(1)
        meta_seen.add(mid)
        if mid not in docs:
            err(f"product/index.yaml:{n} : meta -> id inexistant {mid}")
        if m.group(2) and not os.path.isfile(os.path.join(ROOT, m.group(2))):
            err(f"product/index.yaml:{n} : meta -> fichier inexistant {m.group(2)}")
    for p, (did, z) in sorted(docs_by_path.items()):
        if z in META_DIRS and did not in meta_seen:
            err(f"product/index.yaml : document meta non indexé {os.path.relpath(p, ROOT)} ({did}) dans 'meta'")
    # entrypoints et tasks : ids product ou knowledge
    known = set(docs) | (k_ids or set())
    for n, line in secs.get("entrypoints", [])[1:]:
        m = ENTRY_RE.match(line)
        if m and m.group(1) not in docs:
            err(f"product/index.yaml:{n} : entrypoint -> id inexistant {m.group(1)}")
    n_tasks = 0
    for n, line in secs.get("tasks", [])[1:]:
        m = re.match(r"^\s*(?:-\s*)?(docs|knowledge):\s*(\[.*\])\s*$", line)
        if not m:
            continue
        n_tasks += 1
        for x in flow_list(m.group(2)) or []:
            if x not in (docs if m.group(1) == "docs" else known):
                err(f"product/index.yaml:{n} : tasks -> id inexistant {x}")
    if "tasks" in secs and not n_tasks:
        err("product/index.yaml : section tasks vide (attendu des lignes docs: [..])")


def main():
    k_ids = knowledge_ids()
    docs, docs_by_path, id_paths = {}, {}, {}
    for path, r_dir in walk_docs():
        r = rel(path)
        zone = zone_of(r_dir)
        lines = read_lines(path)
        check_size(r, lines)
        if path.endswith(".feature"):
            fid = None
            for line in lines[:5]:
                m = FEATURE_ID_RE.match(line.strip())
                if m:
                    fid = m.group(1)
                    break
            if not fid:
                err(f"{r} : en-tête « # id: <id> » absent des 5 premières lignes")
                continue
            if not ID_RE.match(fid):
                err(f"{r} : id invalide {fid!r}")
                continue
            if zone in ZONES and not fid.startswith(ZONES[zone][0]):
                err(f"{r} : id {fid} sans préfixe {ZONES[zone][0]}")
            id_paths.setdefault(fid, []).append(r)
            docs[fid] = {"__rel__": r, "__path__": path, "__feature__": True, "__text__": "\n".join(lines)}
            docs_by_path[path] = (fid, zone)
            continue
        fm, lines = parse_frontmatter(path)
        if fm is None:
            err(f"{r} : frontmatter YAML absent ou non fermé")
            continue
        for k in REQUIRED:
            if k not in fm:
                err(f"{r} : champ '{k}' absent du frontmatter")
        nid = fm.get("id")
        if not isinstance(nid, str) or not ID_RE.match(nid):
            err(f"{r} : id invalide {nid!r}")
            continue
        id_paths.setdefault(nid, []).append(r)
        if zone in ZONES:
            prefix, area = ZONES[zone]
            if not nid.startswith(prefix):
                err(f"{r} : id {nid} sans préfixe {prefix} (dossier {zone}/)")
        elif zone in META_DIRS:
            area = "meta"
            if not nid.startswith("p-") or nid.startswith(ZONE_PREFIXES):
                err(f"{r} : id {nid} : préfixe p- attendu (hors p-fn-/p-ar-/p-rm-) pour un document meta")
        else:
            area = None
            err(f"{r} : dossier {zone}/ inconnu (zones : {', '.join(sorted(ZONES))}, sources)")
        if fm.get("area") not in AREAS:
            err(f"{r} : area invalide {fm.get('area')!r}")
        elif area and fm["area"] != area:
            err(f"{r} : area {fm['area']} != {area} attendue pour ce dossier")
        if fm.get("status") not in STATUSES:
            err(f"{r} : status invalide {fm.get('status')!r}")
        if "updated" in fm and not (isinstance(fm["updated"], str) and DATE_RE.match(fm["updated"])):
            err(f"{r} : updated n'est pas une date AAAA-MM-JJ")
        for k in ("tags", "links", "sources"):
            if k in fm and not isinstance(fm[k], list):
                err(f"{r} : '{k}' doit être une liste")
        if not fm.get("title"):
            err(f"{r} : title vide")
        fm["__rel__"], fm["__path__"] = r, path
        fm["__body__"] = "\n".join(lines[fm["__end__"] + 1:])
        docs[nid] = fm
        docs_by_path[path] = (nid, zone)

    for nid, paths in id_paths.items():
        if len(paths) > 1:
            err(f"id dupliqué {nid} : {', '.join(paths)}")
    if k_ids:
        for nid in sorted(set(docs) & k_ids):
            err(f"id {nid} présent à la fois dans product/ et knowledge/")

    known = set(docs) | (k_ids or set())
    for nid, fm in docs.items():
        if fm.get("__feature__"):
            continue
        r = fm["__rel__"]
        links = fm.get("links") if isinstance(fm.get("links"), list) else []
        for l in links:
            if k_ids is None and not l.startswith(("p-", "pdr-")):
                continue
            if l not in known:
                err(f"{r} : links -> id inexistant {l}")
            elif l == nid:
                warn(f"{r} : lien vers soi-même")
        if len(set(links)) != len(links):
            warn(f"{r} : links contient des doublons")
        check_md_links(fm["__path__"], fm["__body__"])

    # exigences citées par les .feature et questions ouvertes citées
    req_text = ""
    for p in ("functional/requirements.md", "functional/nfr.md"):
        fp = os.path.join(ROOT, p)
        if os.path.isfile(fp):
            req_text += "\n".join(read_lines(fp))
    oq_path = os.path.join(ROOT, "roadmap", "open-questions.md")
    oq_text = "\n".join(read_lines(oq_path)) if os.path.isfile(oq_path) else None
    for nid, fm in docs.items():
        if fm.get("__feature__"):
            if req_text:
                for t in sorted(set(REQ_TAG_RE.findall(fm["__text__"]))):
                    if not re.search(rf"\b{re.escape(t)}\b", req_text):
                        warn(f"{fm['__rel__']} : tag @{t} absent de requirements.md / nfr.md")
            continue
        if oq_text is not None and fm["__path__"] != oq_path:
            for q in sorted(set(re.findall(r"\bQ-\d{2,}\b", fm["__body__"]))):
                if not re.search(rf"\b{q}\b", oq_text):
                    warn(f"{fm['__rel__']} : {q} absente de roadmap/open-questions.md")

    zone_lines = {}
    for zone in sorted(ZONES):
        if os.path.isdir(os.path.join(ROOT, zone)):
            zone_lines[zone] = check_zone_index(zone, docs_by_path, set(docs), k_ids)
    check_decisions(docs, zone_lines.get("decisions"))
    check_decision_index_status(docs, zone_lines.get("decisions"))
    check_roadmap_dependencies()
    check_root_index(docs, docs_by_path, k_ids)

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"product_lint : {len(docs)} documents, {len(zone_lines)} zone(s), "
          f"{len(errors)} erreur(s), {len(warnings)} avertissement(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
