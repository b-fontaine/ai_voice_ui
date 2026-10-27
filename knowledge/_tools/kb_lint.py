#!/usr/bin/env python3
"""Lint de la base de connaissances knowledge/ (stdlib uniquement, sans PyYAML).

Usage :
    python3 -I knowledge/_tools/kb_lint.py               # vérifie, code retour 1 si erreur
    python3 -I knowledge/_tools/kb_lint.py --write-tags  # régénère tags.yaml puis vérifie

Vérifie : frontmatter présent et complet, ids uniques et préfixés selon le domaine,
links et [[...]] résolus, index.yaml de domaine <-> fichiers, index racine
(domaines, entrypoints, tasks), tags.yaml à jour, notes < 80 lignes.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REQUIRED = ("id", "title", "tags", "status", "updated", "sources", "links")
STATUSES = {"verified", "sourced", "opinion"}
MAX_LINES = 80
SOFT_LINES = 60
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
WIKI_RE = re.compile(r"\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]")
ENTRY_RE = re.compile(r"^\s*-\s*\{\s*id:\s*([^,}\s]+)\s*,\s*path:\s*([^,}\s]+)")

errors, warnings = [], []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def rel(p):
    return os.path.relpath(p, ROOT)


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


def walk_md(base):
    for d, ds, fs in os.walk(base):
        ds[:] = sorted(x for x in ds if not x.startswith((".", "_")))
        for f in sorted(fs):
            if f.endswith(".md") and not f.startswith("_"):
                yield os.path.join(d, f)


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
            fm[key] = lst if lst is not None else ([] if val == "" else val)
        elif key and re.match(r"^\s+-\s+", line):
            if not isinstance(fm.get(key), list):
                fm[key] = []
            fm[key].append(re.sub(r"^\s+-\s+", "", line).strip().strip('"'))
    if "__end__" not in fm:
        return None, lines
    return fm, lines


def load_root_index():
    path = os.path.join(ROOT, "index.yaml")
    if not os.path.isfile(path):
        err("index.yaml racine absent")
        return [], [], []
    domains, entry_ids, task_ids, section, cur = [], [], [], None, None
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if re.match(r"^\S", line) and not line.startswith("#"):
                section = line.split(":", 1)[0].strip()
                continue
            s = line.strip()
            if section == "domains":
                m = re.match(r"^-\s*name:\s*(\S+)", s)
                if m:
                    cur = {"name": m.group(1), "line": n}
                    domains.append(cur)
                    continue
                m = re.match(r"^(index|prefixes|keywords|description):\s*(.*)$", s)
                if m and cur is not None:
                    v = m.group(2)
                    cur[m.group(1)] = flow_list(v) if m.group(1) in ("prefixes", "keywords") else v.strip('"')
            elif section == "entrypoints":
                m = re.match(r"^-\s*\{\s*id:\s*([^,}\s]+)", s)
                if m:
                    entry_ids.append((m.group(1), n))
            elif section == "tasks":
                m = re.match(r"^notes:\s*(\[.*\])\s*$", s)
                if m:
                    for x in flow_list(m.group(1)):
                        task_ids.append((x, n))
    return domains, entry_ids, task_ids


def check_domain_index(index_path, notes_by_path):
    base = os.path.dirname(index_path)
    expected = {p for p in notes_by_path if p.startswith(base + os.sep)}
    seen = {}
    with open(index_path, encoding="utf-8") as fh:
        text = fh.read()
    if not re.search(r"^domain:\s*\S", text, re.M):
        err(f"{rel(index_path)} : clé 'domain' absente")
    if not re.search(r"^notes:\s*$", text, re.M):
        err(f"{rel(index_path)} : clé 'notes' absente")
    m = re.search(r"^subindexes:\s*(\[.*\])\s*$", text, re.M)
    for sub in (flow_list(m.group(1)) if m else []):
        sp = os.path.join(base, sub)
        if not os.path.isfile(sp):
            err(f"{rel(index_path)} : sous-index introuvable {sub}")
    for n, line in enumerate(text.split("\n"), 1):
        m = ENTRY_RE.match(line)
        if not m:
            if re.match(r"^\s*-\s*\{", line):
                err(f"{rel(index_path)}:{n} : entrée illisible (attendu {{id: .., path: .., ...}})")
            continue
        nid, p = m.group(1), os.path.normpath(os.path.join(base, m.group(2)))
        if p in seen:
            err(f"{rel(index_path)}:{n} : chemin listé deux fois {m.group(2)}")
        seen[p] = nid
        if not os.path.isfile(p):
            err(f"{rel(index_path)}:{n} : fichier inexistant {m.group(2)}")
        elif p not in notes_by_path:
            err(f"{rel(index_path)}:{n} : {m.group(2)} n'a pas de frontmatter valide")
        elif notes_by_path[p] != nid:
            err(f"{rel(index_path)}:{n} : id {nid} != id du fichier {notes_by_path[p]}")
        if 'summary:' not in line:
            warn(f"{rel(index_path)}:{n} : summary absent pour {nid}")
    for p in sorted(expected - set(seen)):
        err(f"{rel(index_path)} : note non indexée {os.path.relpath(p, base)}")


def compute_tags(notes):
    tags = {}
    for nid, fm in sorted(notes.items()):
        for t in fm.get("tags") or []:
            tags.setdefault(t, [])
            if nid not in tags[t]:
                tags[t].append(nid)
    return dict(sorted(tags.items(), key=lambda kv: kv[0].lower()))


def yaml_key(k):
    return k if re.match(r"^[A-Za-z0-9_][A-Za-z0-9_.\-]*$", k) else '"' + k.replace('"', '\\"') + '"'


def render_tags(tags):
    out = ["# Généré par _tools/kb_lint.py --write-tags. Ne pas éditer à la main.",
           "# tag -> ids des notes qui le portent."]
    for t, ids in tags.items():
        out.append(f"{yaml_key(t)}: [{', '.join(ids)}]")
    return "\n".join(out) + "\n"


def parse_tags_file(path):
    res = {}
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            m = re.match(r'^("(?:[^"\\]|\\.)*"|[^:]+):\s*(\[.*\])\s*$', line.rstrip("\n"))
            if not m:
                err(f"tags.yaml:{n} : ligne illisible")
                continue
            res[m.group(1).strip('"')] = flow_list(m.group(2))
    return res


def main():
    write_tags = "--write-tags" in sys.argv[1:]
    domains, entry_ids, task_ids = load_root_index()
    prefix_of = {d["name"]: d.get("prefixes") or [] for d in domains}

    notes, notes_by_path, id_paths = {}, {}, {}
    for path in walk_md(ROOT):
        r = rel(path)
        if os.sep not in r:
            continue  # fichiers .md à la racine (hors notes)
        fm, lines = parse_frontmatter(path)
        n_lines = len(lines) - (1 if lines and lines[-1] == "" else 0)
        if n_lines >= MAX_LINES:
            err(f"{r} : {n_lines} lignes (max {MAX_LINES - 1})")
        elif n_lines > SOFT_LINES:
            warn(f"{r} : {n_lines} lignes (> {SOFT_LINES}, conventions)")
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
        if fm.get("status") not in STATUSES:
            err(f"{r} : status invalide {fm.get('status')!r}")
        if isinstance(fm.get("updated"), str) and not DATE_RE.match(fm["updated"]):
            err(f"{r} : updated n'est pas une date AAAA-MM-JJ")
        for k in ("tags", "links", "sources"):
            if k in fm and not isinstance(fm[k], list):
                err(f"{r} : '{k}' doit être une liste")
        domain = r.split(os.sep)[0]
        if domain not in prefix_of:
            err(f"{r} : domaine '{domain}' absent de index.yaml racine")
        elif prefix_of[domain] and not any(nid.startswith(p) for p in prefix_of[domain]):
            err(f"{r} : id {nid} sans préfixe du domaine {prefix_of[domain]}")
        fm["__body__"] = "\n".join(lines[fm["__end__"] + 1:])
        fm["__path__"] = r
        notes[nid] = fm
        notes_by_path[path] = nid

    for nid, paths in id_paths.items():
        if len(paths) > 1:
            err(f"id dupliqué {nid} : {', '.join(paths)}")

    for nid, fm in notes.items():
        r = fm["__path__"]
        links = fm.get("links") if isinstance(fm.get("links"), list) else []
        for l in links:
            if l not in notes:
                err(f"{r} : links -> id inexistant {l}")
            elif l == nid:
                warn(f"{r} : lien vers soi-même")
        if len(set(links)) != len(links):
            warn(f"{r} : links contient des doublons")
        for w in WIKI_RE.findall(fm["__body__"]):
            if w.strip() not in notes:
                err(f"{r} : [[{w}]] -> id inexistant")

    # index de domaine
    index_files = []
    for d, ds, fs in os.walk(ROOT):
        ds[:] = sorted(x for x in ds if not x.startswith((".", "_")))
        if d != ROOT and "index.yaml" in fs:
            index_files.append(os.path.join(d, "index.yaml"))
    for ip in sorted(index_files):
        check_domain_index(ip, notes_by_path)

    # index racine
    names = set()
    for d in domains:
        names.add(d["name"])
        ip = d.get("index")
        if not ip or not os.path.isfile(os.path.join(ROOT, ip)):
            err(f"index.yaml:{d['line']} : index du domaine {d['name']} introuvable ({ip})")
        if not d.get("keywords"):
            err(f"index.yaml:{d['line']} : keywords absents pour {d['name']}")
        if not d.get("description"):
            err(f"index.yaml:{d['line']} : description absente pour {d['name']}")
    for sub in sorted(os.listdir(ROOT)):
        full = os.path.join(ROOT, sub)
        if os.path.isdir(full) and not sub.startswith((".", "_")) and any(walk_md(full)) and sub not in names:
            err(f"index.yaml : dossier {sub}/ non déclaré dans domains")
    if not 5 <= len(entry_ids) <= 15:
        err(f"index.yaml : {len(entry_ids)} entrypoints (attendu 5 à 15)")
    for nid, n in entry_ids + task_ids:
        if nid not in notes:
            err(f"index.yaml:{n} : id inexistant {nid}")
    if not task_ids:
        err("index.yaml : section tasks vide")

    # tags.yaml
    tags = compute_tags(notes)
    tp = os.path.join(ROOT, "tags.yaml")
    if write_tags:
        with open(tp, "w", encoding="utf-8") as fh:
            fh.write(render_tags(tags))
    if not os.path.isfile(tp):
        err("tags.yaml absent (lancer avec --write-tags)")
    else:
        current = parse_tags_file(tp)
        if current != tags:
            diff = sorted(k for k in set(current) | set(tags) if current.get(k) != tags.get(k))
            err(f"tags.yaml désynchronisé ({len(diff)} tags, ex. {', '.join(diff[:5])}) : lancer --write-tags")

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"kb_lint : {len(notes)} notes, {len(index_files)} index de domaine, {len(tags)} tags, "
          f"{len(errors)} erreur(s), {len(warnings)} avertissement(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
