#!/usr/bin/env python3
"""Tableau de bord local de la boucle de développement (lecture seule, stdlib uniquement).

Usage :
    python3 -I tools/loop/dashboard.py [--port 8765] [--worktree CHEMIN]
puis ouvrir http://127.0.0.1:8765 (rafraîchissement automatique).

Lit, sans rien modifier : specs/progress.md, specs/NNN-*/status.md,
product/roadmap/open-questions.md, .omc/state/loop/ (quota, portes, superviseur,
battement, captures), git, tmux et /proc (scripts de boucle en cours). N'écoute que sur 127.0.0.1.
"""
import argparse
import glob
import html
import json
import os
import re
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
LOOP_SCRIPTS = ("gate", "publish", "app-smoke")
SCRIPT_RE = re.compile(r"(?:^|/)tools/loop/(gate|publish|app-smoke)\.sh$")
SHELLS = {"bash", "sh", "dash"}


def sh(cmd, cwd=None, timeout=10, env=None):
    """(code, sortie). La sortie d'erreur est rendue si la sortie standard est vide."""
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)
        return r.returncode, (r.stdout.strip() or r.stderr.strip())
    except subprocess.TimeoutExpired:
        return 124, f"délai dépassé ({timeout} s)"
    except OSError as exc:
        return 127, str(exc)


def env_value(key, default):
    try:
        with open(os.path.join(HERE, "loop.env"), encoding="utf-8") as f:
            for line in f:
                m = re.match(rf"^{key}=([^\s#]+)", line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return default


def default_worktree():
    _, common = sh(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=REPO)
    repo = os.path.dirname(common) if common.startswith("/") else REPO
    return os.path.join(os.path.dirname(repo), env_value("LOOP_WORKTREE_NAME", "ai_voice_ui-loop"))


def read(path, default=""):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return default


def md_cells(line):
    """Cellules d'une ligne de tableau markdown, en respectant les « \\| »."""
    parts = re.split(r"(?<!\\)\|", line.strip())
    return [p.strip().replace("\\|", "|") for p in parts[1:-1]]


def md_table(text, heading):
    """Lignes (hors en-tête et séparateur) du premier tableau après « ## heading »."""
    m = re.search(rf"^## {re.escape(heading)}\s*$", text, re.M)
    if not m:
        return []
    rows = []
    for line in text[m.end():].splitlines():
        if line.startswith("## "):
            break
        if line.startswith("|") and not re.match(r"^\|[\s\-|:]+\|$", line):
            rows.append(md_cells(line))
    return rows[1:] if rows else []


def field(text, name):
    m = re.search(rf"\*\*{re.escape(name)}\*\*\s*:\s*(.+)", text)
    return m.group(1).strip() if m else ""


def num_or_none(v):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None


# ---------------------------------------------------------------- quota
# Dernière valeur valide vue par ce serveur, par fenêtre : sert quand quota.json disparaît,
# devient invalide ou perd une fenêtre (par exemple juste après une remise à zéro).
_LAST = {"five_hour": None, "seven_day": None, "check": None}
_LOCK = threading.Lock()


def pane_quota(pane):
    """Repli : pourcentages lus dans la barre d'état visible du terminal tmux (« 5h:[…]2% », « wk:[…]1% »)."""
    found = {}
    for key, pat in (("five_hour", r"\b5h:\S*?(\d{1,3})\s?%"), ("seven_day", r"\b(?:wk|7j):\S*?(\d{1,3})\s?%")):
        m = None
        for m in re.finditer(pat, pane):
            pass
        if m:
            found[key] = int(m.group(1))
    return found


def quota_state(wt, st, now, pane):
    path = os.path.join(st, "quota.json")
    stale_s = int(env_value("LOOP_QUOTA_STALE_S", "3600") or 3600)
    file_note = ""
    data = {}
    try:
        mtime = int(os.path.getmtime(path))
    except OSError:
        mtime = None
        file_note = "quota.json absent"
    if mtime is not None:
        try:
            data = json.loads(read(path, "{}") or "{}")
            if not isinstance(data, dict):
                data, file_note = {}, "quota.json invalide"
        except ValueError:
            data, file_note = {}, "quota.json illisible (écriture en cours ?)"
    rl = data.get("rate_limits") if isinstance(data.get("rate_limits"), dict) else {}
    if mtime is not None and not rl and not file_note:
        file_note = "quota.json sans rate_limits"
    seen = num_or_none(data.get("seen_at")) or mtime
    changed = num_or_none(data.get("changed_at"))
    pq = pane_quota(pane or "")

    windows = {}
    with _LOCK:
        for key in ("five_hour", "seven_day"):
            w = rl.get(key) if isinstance(rl.get(key), dict) else {}
            used = num_or_none(w.get("used_percentage"))
            entry = None
            if used is not None:
                entry = {"used": used, "resets_at": num_or_none(w.get("resets_at")), "seen_at": seen,
                         "changed_at": changed, "source": "quota.json"}
                _LAST[key] = dict(entry)
            elif _LAST[key]:
                entry = dict(_LAST[key], source="dernière valeur connue (" + (file_note or "fenêtre absente de quota.json") + ")")
            if key in pq and (entry is None or (entry.get("seen_at") or 0) < now - stale_s
                              or (entry.get("resets_at") or now + 1) <= now):
                # La barre d'état affichée est plus récente que la donnée enregistrée (ancienne ou
                # antérieure à une remise à zéro de la fenêtre).
                # Une remise à zéro déjà passée ne vaut pas pour cette valeur fraîche.
                prev_reset = (entry or {}).get("resets_at")
                entry = {"used": pq[key], "resets_at": prev_reset if prev_reset and prev_reset > now else None, "seen_at": now,
                         "changed_at": None, "source": "barre d'état du terminal de boucle"}
            if entry:
                r = entry.get("resets_at")
                entry["expired"] = bool(r and r <= now)
                entry["stale"] = bool(entry.get("seen_at") and now - entry["seen_at"] > stale_s)
                entry["age_s"] = (now - entry["seen_at"]) if entry.get("seen_at") else None
            windows[key] = entry or {"unknown": True, "reason": file_note or "fenêtre absente de quota.json"}

        # Contrôle : le script du worktree de boucle, à défaut celui de ce dépôt pointé sur le même état.
        script = os.path.join(wt, "tools", "loop", "quota-check.sh")
        env = None
        if not os.path.isfile(script):
            script = os.path.join(HERE, "quota-check.sh")
            env = dict(os.environ, LOOP_STATE_DIR=st)
        rc, qc = sh(["bash", script], cwd=wt, timeout=20, env=env)
        first = qc.split(None, 1)[0] if qc else ""
        if first in ("OK", "PAUSE", "UNKNOWN"):
            kind = first
        else:
            kind = "ERREUR"
        check = {"kind": kind, "text": qc or "(aucune sortie)", "rc": rc, "at": now}
        if kind == "PAUSE":
            m = re.match(r"PAUSE (\d+)", qc)
            check["resume_at"] = int(m.group(1)) if m else None
        if kind == "ERREUR" and _LAST["check"]:
            check["previous"] = _LAST["check"]
        if kind != "ERREUR":
            _LAST["check"] = {k: v for k, v in check.items() if k != "previous"}

    rc_b, budget = sh(["bash", os.path.join(wt, "tools", "loop", "openai-budget.sh"), "total"], cwd=wt)
    return {"five_hour": windows["five_hour"], "seven_day": windows["seven_day"], "file": file_note,
            "file_seen_at": seen, "check": check, "budget": budget if rc_b == 0 else f"inconnu ({budget})",
            "stale_s": stale_s}


# ---------------------------------------------------------------- scripts en cours
def running_scripts(wt):
    """Scripts de boucle réellement EXÉCUTÉS (argv[0] = script, ou interpréteur bash/sh + script),
    dans le worktree de boucle. Une ligne de commande qui ne fait que citer le chemin ne compte pas."""
    found = set()
    try:
        pids = [p for p in os.listdir("/proc") if p.isdigit()]
    except OSError:
        return []
    real_wt = os.path.realpath(wt)
    for pid in pids:
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                argv = [a.decode("utf-8", "replace") for a in f.read().split(b"\0") if a]
        except OSError:
            continue
        if not argv:
            continue
        script = None
        if SCRIPT_RE.search(argv[0]):
            script = argv[0]
        elif os.path.basename(argv[0]) in SHELLS:
            for a in argv[1:]:
                if a == "-c" or a.startswith("-") and "c" in a[1:] and not a.startswith("--"):
                    break  # « bash -c 'texte' » : chaîne de commande, pas un script
                if a.startswith("-"):
                    continue
                script = a if SCRIPT_RE.search(a) else None
                break
        if not script:
            continue
        m = SCRIPT_RE.search(script)
        if not os.path.isabs(script):
            try:
                script = os.path.join(os.readlink(f"/proc/{pid}/cwd"), script)
            except OSError:
                found.add(m.group(1))
                continue
        rp = os.path.realpath(script)
        if rp == real_wt or rp.startswith(real_wt + os.sep):
            found.add(m.group(1))
    return sorted(found)


# ---------------------------------------------------------------- état
def guarded(out, key, fn, default=None):
    """Une section en échec n'empêche pas les autres : l'erreur est rendue dans out['errors']."""
    try:
        out[key] = fn()
    except Exception as exc:  # noqa: BLE001 - tableau de bord : on affiche plutôt que planter
        out[key] = default
        out.setdefault("errors", []).append(f"{key} : {type(exc).__name__}: {exc}")


def state(wt):
    st = os.path.join(wt, ".omc", "state", "loop")
    now = int(time.time())
    out = {"now": now, "worktree": wt, "exists": os.path.isdir(wt)}
    if not out["exists"]:
        return out

    progress = read(os.path.join(wt, "specs", "progress.md"))
    guarded(out, "features", lambda: [dict(zip(["id", "name", "backlog", "milestone", "step", "updated"], r))
                                      for r in md_table(progress, "Fonctionnalités")], [])
    guarded(out, "journal", lambda: [dict(zip(["date", "event"], r)) for r in md_table(progress, "Journal")[:8]], [])

    def current():
        cur = None
        for f in sorted(glob.glob(os.path.join(wt, "specs", "[0-9][0-9][0-9]-*", "status.md"))):
            txt = read(f)
            step = field(txt, "Étape")
            if step and not step.startswith(("Terminée", "Définir |")):
                cur = (f, txt, step)
        if not cur:
            return None
        f, txt, step = cur
        journal = md_table(txt, "Journal")
        return {
            "id": os.path.basename(os.path.dirname(f)),
            "step": step,
            "attempts": field(txt, "Tentatives"),
            "task": field(txt, "Tâche en cours"),
            "last": [dict(zip(["date", "step", "done", "proof"], r)) for r in journal[-4:]][::-1],
        }
    guarded(out, "current", current)

    def questions():
        opened = []
        for line in read(os.path.join(wt, "product", "roadmap", "open-questions.md")).splitlines():
            if re.match(r"^\| Q-\d+", line):
                c = md_cells(line)
                status = c[-1] if c else ""
                if status.startswith("Ouverte"):
                    opened.append({"id": c[0], "question": c[1] if len(c) > 1 else "",
                                   "due": c[-2] if len(c) > 2 else "", "reco": c[-4] if len(c) > 4 else ""})
        return opened
    guarded(out, "questions", questions, [])

    def gates():
        rows = []
        for line in read(os.path.join(st, "gates.tsv")).splitlines()[-12:]:
            p = line.split("\t")
            if len(p) >= 5:
                rows.append({"at": p[0][11:16], "day": p[0][5:10], "sha": p[1][:7], "clean": p[2], "mode": p[3], "result": p[4]})
        return rows[::-1]
    guarded(out, "gates", gates, [])
    guarded(out, "supervisor", lambda: [l for l in read(os.path.join(st, "supervisor.log")).splitlines()
                                        if "superviseur" in l][-8:][::-1], [])

    def num(name):
        try:
            return int(read(os.path.join(st, name)).strip())
        except ValueError:
            return None

    session = env_value("LOOP_TMUX_SESSION", "genesis-loop")
    pane = ""

    def health():
        nonlocal pane
        hb = num("heartbeat")
        rc_loop, _ = sh(["tmux", "has-session", "-t", session])
        rc_sup, _ = sh(["tmux", "has-session", "-t", "genesis-supervisor"])
        rc_pane, p = sh(["tmux", "capture-pane", "-p", "-t", session])
        pane = p if rc_pane == 0 else ""
        lines = [l.rstrip() for l in pane.splitlines() if l.strip() and not set(l.strip()) <= set("─")]
        paused = num("paused_until")
        return {
            "loop": rc_loop == 0,
            "supervisor": rc_sup == 0,
            "session": session,
            "heartbeat_s": (now - hb) if hb else None,
            "paused_until": paused if paused and paused > now else None,
            "stop": os.path.exists(os.path.join(st, "STOP")),
            "fresh": os.path.exists(os.path.join(st, "fresh_session")),
            "dialog": bool(re.search(r"enter to confirm|do you want|allow external", pane, re.I)),
            "pane": lines[-60:],
        }
    guarded(out, "health", health, {"loop": False, "supervisor": False, "session": session, "heartbeat_s": None,
                                     "paused_until": None, "stop": False, "fresh": False, "dialog": False, "pane": []})
    guarded(out, "quota", lambda: quota_state(wt, st, now, pane), None)

    def git():
        _, branch = sh(["git", "branch", "--show-current"], cwd=wt)
        _, log = sh(["git", "log", "--all", "-12", "--format=%h\t%ad\t%s", "--date=format:%d/%m %H:%M"], cwd=wt)
        rc_o, origin = sh(["git", "log", "-1", "--format=%h %ad", "--date=format:%d/%m %H:%M", "origin/main"], cwd=wt)
        return {"branch": branch, "origin_main": origin if rc_o == 0 else "",
                "log": [dict(zip(["sha", "at", "msg"], l.split("\t"))) for l in log.splitlines() if l.count("\t") >= 2]}
    guarded(out, "git", git, {"branch": "", "origin_main": "", "log": []})

    # Travaux en cours (porte, publication, capture) et état de publication de la dernière fonctionnalité.
    guarded(out, "running", lambda: running_scripts(wt), [])

    def last_feature():
        feats = out.get("features") or []
        if not feats:
            return None
        last = feats[-1]
        step = last.get("step") or ""
        rc_anc, _ = sh(["git", "merge-base", "--is-ancestor", env_value("LOOP_BRANCH", "loop"), "origin/main"], cwd=wt)
        if "publish" in out.get("running", []):
            pub = "publication en cours"
        elif step.startswith("À faire"):
            pub = "pas encore commencée"
        elif rc_anc == 0:
            pub = "publiée sur main"
        else:
            pub = "fusionnée dans loop, pas encore publiée"
        return {"id": last.get("id"), "name": last.get("name"), "step": step, "publication": pub}
    guarded(out, "last_feature", last_feature)

    def snapshot():
        snaps = sorted(glob.glob(os.path.join(st, "snapshots", "*.png")), key=os.path.getmtime)
        return {"name": os.path.basename(snaps[-1]), "at": int(os.path.getmtime(snaps[-1])), "count": len(snaps)} if snaps else None
    guarded(out, "snapshot", snapshot)
    return out


PAGE = r"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Boucle Genesis</title>
<style>
:root{--bg:#f6f7fb;--card:#fff;--fg:#1b1d29;--muted:#636a80;--line:#e3e6ef;--ok:#1a7f4b;--okbg:#e3f6ec;--warn:#9a6200;--warnbg:#fff3d6;--bad:#b42318;--badbg:#fde8e7;--acc:#5b3fd6;--accbg:#ece8ff;--todo:#636a80;--todobg:#eef0f5;--term:#0f1018;--termfg:#d7d9e6}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#0c0d14;--card:#161827;--fg:#e8e9f2;--muted:#9aa0b8;--line:#272a3d;--ok:#5fd39a;--okbg:#123326;--warn:#f2c46b;--warnbg:#3a2c0c;--bad:#ff8a80;--badbg:#3d1716;--acc:#a996ff;--accbg:#262046;--todo:#9aa0b8;--todobg:#1e2033;--term:#08090f;--termfg:#d7d9e6}}
:root[data-theme=dark]{--bg:#0c0d14;--card:#161827;--fg:#e8e9f2;--muted:#9aa0b8;--line:#272a3d;--ok:#5fd39a;--okbg:#123326;--warn:#f2c46b;--warnbg:#3a2c0c;--bad:#ff8a80;--badbg:#3d1716;--acc:#a996ff;--accbg:#262046;--todo:#9aa0b8;--todobg:#1e2033;--term:#08090f;--termfg:#d7d9e6}
*{box-sizing:border-box}html,body{overflow-x:hidden}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
header{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;justify-content:space-between;padding:12px 16px;border-bottom:1px solid var(--line)}
header .pills{display:flex;flex-wrap:wrap;gap:6px;align-items:center;min-width:0}
h1{font-size:18px;margin:0}h2{font-size:12px;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin:0 0 10px;display:flex;gap:8px;align-items:baseline;justify-content:space-between}
h2 small{text-transform:none;letter-spacing:0;font-weight:400}
.wrap{padding:16px;display:grid;gap:16px;width:100%}
.grid{display:grid;gap:16px;min-width:0}
.top{grid-template-columns:1fr}
@media (min-width:900px){.top{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media (min-width:1600px){.top{grid-template-columns:minmax(0,.9fr) minmax(0,.9fr) minmax(0,1.3fr) minmax(0,1.1fr)}}
.rest{grid-template-columns:repeat(auto-fit,minmax(min(100%,420px),1fr));align-items:start}
.tiles{display:grid;gap:10px;grid-template-columns:repeat(auto-fill,minmax(min(100%,230px),1fr))}
section{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px;min-width:0}
.pill{display:inline-block;padding:2px 9px;border-radius:999px;font-size:12px;font-weight:600;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;vertical-align:middle}
.ok{color:var(--ok);background:var(--okbg)}.warn{color:var(--warn);background:var(--warnbg)}.bad{color:var(--bad);background:var(--badbg)}.acc{color:var(--acc);background:var(--accbg)}.todo{color:var(--todo);background:var(--todobg)}
table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:6px;border-top:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:500;border-top:0}
.muted{color:var(--muted)}td.mono{white-space:nowrap}.mono{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px}
.kv{display:grid;grid-template-columns:auto minmax(0,1fr);gap:4px 12px;overflow-wrap:anywhere}
.bar{height:8px;background:var(--line);border-radius:4px;overflow:hidden;margin:4px 0 2px}.bar>i{display:block;height:100%;background:var(--acc)}
.bar.warn>i{background:var(--warn)}.bar.bad>i{background:var(--bad)}.bar.old>i{opacity:.45}
.q{margin-bottom:12px}.q .meta{font-size:12px}
pre{white-space:pre-wrap;word-break:break-word;margin:0;max-height:260px;overflow:auto;background:var(--bg);padding:10px;border-radius:8px}
pre.term{white-space:pre;word-break:normal;background:var(--term);color:var(--termfg);max-height:340px;min-height:160px;font-size:11.5px;line-height:1.35}
.scroll{overflow-x:auto;max-width:100%}
.snap{display:block;cursor:zoom-in;border:0;padding:0;background:none;width:100%}
.snap img{display:block;width:100%;max-height:340px;object-fit:contain;border-radius:8px;border:1px solid var(--line);background:var(--bg)}
.tile{border:1px solid var(--line);border-left:4px solid var(--todo);border-radius:10px;padding:10px 12px;background:var(--card);min-width:0;display:flex;flex-direction:column;gap:4px}
.tile.ok{border-left-color:var(--ok)}.tile.warn{border-left-color:var(--warn)}.tile.bad{border-left-color:var(--bad)}.tile.acc{border-left-color:var(--acc)}
.tile.ok,.tile.warn,.tile.bad,.tile.acc,.tile.todo{background:var(--card);color:var(--fg)}
.tile.cur{outline:2px solid var(--acc);outline-offset:1px;background:var(--accbg)}
.tile .hd{display:flex;justify-content:space-between;gap:8px;align-items:baseline}
.tile .id{font:600 15px/1.2 ui-monospace,Menlo,Consolas,monospace}
.tile .nm{font-weight:600;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;min-height:2.9em}
.tile .st{font-size:12px;color:var(--muted);overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical}
.legend{display:flex;flex-wrap:wrap;gap:6px}
.err{color:var(--bad)}
dialog{border:0;padding:0;background:transparent;max-width:96vw;max-height:96vh}
dialog::backdrop{background:rgba(0,0,0,.75)}
dialog img{display:block;max-width:96vw;max-height:90vh;object-fit:contain;border-radius:8px;cursor:zoom-out}
dialog p{color:#e8e9f2;margin:6px 0 0;text-align:center;font-size:13px}
</style></head><body>
<header><h1>Boucle Genesis Canvas</h1><div id="top" class="pills muted">chargement…</div></header>
<div class="wrap">
 <div class="grid top">
  <section id="s-now"><h2>Maintenant</h2><div class="b"></div></section>
  <section id="s-quota"><h2>Quota et budget</h2><div class="b"></div></section>
  <section id="s-pane"><h2>Écran de la session <small class="muted" id="pane-h"></small></h2><pre class="term mono" id="pane"></pre></section>
  <section id="s-snap"><h2>Dernière capture <small class="muted" id="snap-h"></small></h2>
   <button class="snap" id="snap-btn" type="button" title="Ouvrir en grand" hidden><img id="snap-img" alt="Dernière capture de l’app"></button>
   <p class="muted" id="snap-meta" style="margin:6px 0 0">Aucune capture.</p></section>
 </div>
 <section id="s-feat"><h2>Fonctionnalités <small class="muted" id="feat-h"></small></h2><div class="tiles b"></div></section>
 <div class="grid rest">
  <section id="s-q"><h2>Questions pour toi</h2><div class="b"></div></section>
  <section id="s-gates"><h2>Portes qualité</h2><div class="b"></div></section>
  <section id="s-journal"><h2>Journal de la boucle</h2><div class="b"></div></section>
  <section id="s-git"><h2>Commits récents</h2><div class="b"></div></section>
  <section id="s-sup"><h2>Superviseur</h2><div class="b"></div></section>
 </div>
</div>
<dialog id="dlg"><img id="dlg-img" alt="Dernière capture de l’app, en grand"><p id="dlg-cap"></p></dialog>
<script>
const $=id=>document.getElementById(id);
const e=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const pill=(t,c,title)=>`<span class="pill ${c}"${title?` title="${e(title)}"`:''}>${e(t)}</span>`;
const ago=s=>s==null?'—':s<90?`${s} s`:s<5400?`${Math.round(s/60)} min`:s<172800?`${(s/3600).toFixed(1).replace('.',',')} h`:`${Math.round(s/86400)} j`;
const hm=t=>new Date(t*1000).toLocaleString('fr-FR',{weekday:'short',hour:'2-digit',minute:'2-digit'});
const dhm=t=>new Date(t*1000).toLocaleString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
function stepClass(s){s=s||'';if(s.startsWith('Terminée ⚠'))return 'warn';if(s.startsWith('Terminée'))return 'ok';if(s.startsWith('Bloquée'))return 'bad';if(s.startsWith('À faire'))return 'todo';return 'acc'}
function stepShort(s){s=s||'';return s.split(/\s*[(:]/)[0].replace(/,\s*publiée.*$/,'').trim()||s}
function stepPill(s){return pill(stepShort(s),stepClass(s),s)}
// Remplace le contenu seulement s'il a changé : pas de clignotement, défilement conservé.
function put(el,h){if(el&&el.__h!==h){el.__h=h;el.innerHTML=h}}
function safe(sec,fn){const b=$(sec).querySelector('.b');try{put(b,fn())}catch(x){put(b,`<p class="err">Affichage impossible : ${e(x.message)}</p>`);console.warn(sec,x)}}
function win(name,w,now){
 if(!w||w.unknown)return `<div class="q"><div>${name} · ${pill('inconnu','warn')}</div><div class="meta muted">${e(w&&w.reason||'aucune donnée')}</div></div>`;
 const u=w.used,cls=w.expired?'old':u>=90?'bad':u>=70?'warn':'';
 const reset=w.resets_at?(w.expired?`fenêtre remise à zéro ${hm(w.resets_at)} : valeur d’avant`:`remise à zéro ${w.resets_at-now>86400?dhm(w.resets_at):hm(w.resets_at)} (dans ${ago(w.resets_at-now)})`):'';
 const flags=(w.expired?' '+pill('périmée','warn'):'')+(w.stale&&!w.expired?' '+pill('ancienne','warn'):'');
 return `<div class="q"><div>${name} · <b>${Math.round(u)} %</b>${flags}</div><div class="bar ${cls}"><i style="width:${Math.max(0,Math.min(100,u))}%"></i></div><div class="meta muted">${reset?e(reset)+' · ':''}vu il y a ${ago(w.age_s)}${w.changed_at&&w.changed_at!==w.seen_at?` · changé il y a ${ago(now-w.changed_at)}`:''} · ${e(w.source)}</div></div>`}
function checkHtml(c,now){
 if(!c)return pill('inconnu','warn');
 const cls={OK:'ok',PAUSE:'warn',UNKNOWN:'warn',ERREUR:'bad'}[c.kind]||'warn';
 let h=`${pill(c.kind==='UNKNOWN'?'INCONNU':c.kind,cls)} <span class="mono">${e(c.kind==='ERREUR'?c.text:c.text.replace(/^\S+\s*/,''))}</span>`;
 if(c.resume_at)h+=`<div class="muted">reprise prévue ${dhm(c.resume_at)}</div>`;
 if(c.kind==='ERREUR')h+=`<div class="muted">code ${e(c.rc)}</div>`;
 if(c.previous)h+=`<div class="muted">dernier contrôle valide (il y a ${ago(now-c.previous.at)}) : <span class="mono">${e(c.previous.text)}</span></div>`;
 return h}
let lastSnap=null;
async function load(){
 let d;try{const r=await fetch('/api/state',{cache:'no-store'});d=await r.json()}catch(x){$('top').innerHTML=pill('serveur injoignable','bad')+` <span class="muted">· nouvel essai dans 20 s</span>`;return}
 if(!d.exists){$('top').innerHTML=pill('worktree introuvable : '+d.worktree,'bad');return}
 const now=d.now,h=d.health||{},run=d.running||[],git=d.git||{},errs=d.errors||[];
 try{
  let s=run.includes('publish')?pill('publication en cours','acc'):run.includes('app-smoke')?pill('capture de l’app en cours','acc'):run.includes('gate')?pill('porte qualité en cours','acc'):'';
  s=h.dialog?pill('bloquée : boîte de dialogue à valider (tmux attach -t '+(h.session||'genesis-loop')+')','bad'):h.stop?pill('STOP posé','bad'):h.paused_until?pill('pause quota jusqu’à '+hm(h.paused_until),'warn'):h.fresh?pill('nouvelle conversation imminente','acc'):!h.loop?pill('boucle arrêtée','bad'):(h.heartbeat_s!=null&&h.heartbeat_s>1800)?pill('inactive depuis '+ago(h.heartbeat_s),'warn'):(s||pill('en marche','ok'));
  put($('top'),`${s} ${h.supervisor?pill('superviseur actif','ok'):pill('superviseur arrêté','bad')}${errs.length?' '+pill(errs.length+' erreur(s) de lecture','bad',errs.join('\n')):''} <span class="muted">· mis à jour ${new Date(now*1000).toLocaleTimeString('fr-FR')}</span>`);
 }catch(x){console.warn(x)}
 safe('s-now',()=>{const c=d.current;
  if(c)return `<div style="font-size:16px;font-weight:600">${e(c.id)}</div><div style="margin:6px 0">${stepPill(c.step)} <span class="muted">tentatives ${e(c.attempts)}</span></div><div class="kv"><span class="muted">Tâche</span><span>${e(c.task||'—')}</span><span class="muted">Branche</span><span class="mono">${e(git.branch)}</span><span class="muted">Activité</span><span>il y a ${ago(h.heartbeat_s)}</span>${run.length?`<span class="muted">En cours</span><span>${e(run.join(', '))}</span>`:''}</div>${(c.last||[]).map(r=>`<p class="muted" style="margin:8px 0 0"><b>${e(r.step)}</b> — ${e((r.done||'').slice(0,260))}</p>`).join('')}`;
  const l=d.last_feature;if(!l)return '<p class="muted">Aucune fonctionnalité.</p>';
  const next=(l.step||'').startsWith('À faire');
  return `<p class="muted" style="margin:0 0 6px">Entre deux fonctionnalités.</p><div style="font-size:16px;font-weight:600">${next?'Prochaine':'Dernière'} : ${e(l.id)}</div><div class="muted">${e(l.name)}</div><div style="margin:6px 0">${stepPill(l.step)} ${pill(l.publication,l.publication.startsWith('publiée')?'ok':l.publication.startsWith('pas encore')?'todo':'acc')}</div><div class="kv"><span class="muted">Branche</span><span class="mono">${e(git.branch)}</span><span class="muted">Activité</span><span>il y a ${ago(h.heartbeat_s)}</span></div>${h.fresh?'<p class="muted">Prochaine étape : le superviseur relance la boucle dans une conversation neuve (≤ 5 min).</p>':''}${run.length?`<p class="muted">En cours : ${e(run.join(', '))}</p>`:''}`});
 safe('s-quota',()=>{const q=d.quota;if(!q)return '<p class="err">Quota illisible (voir les erreurs de lecture en haut).</p>';
  return `${win('Fenêtre 5 h',q.five_hour,now)}${win('Semaine',q.seven_day,now)}<div class="kv"><span class="muted">Contrôle</span><span>${checkHtml(q.check,now)}</span><span class="muted">OpenAI</span><span>${e(q.budget)}</span><span class="muted">origin/main</span><span class="mono">${e(git.origin_main||'—')}</span>${q.file?`<span class="muted">Fichier</span><span class="warn" style="background:none">${e(q.file)}</span>`:''}</div>`});
 try{const p=$('pane'),atEnd=p.scrollHeight-p.scrollTop-p.clientHeight<24;const t=(h.pane||[]).join('\n')||'(terminal de boucle indisponible)';if(p.textContent!==t){p.textContent=t;if(atEnd||!p.__init){p.scrollTop=p.scrollHeight;p.__init=1}}
  $('pane-h').textContent='tmux '+(h.session||'')+(h.loop?'':' · arrêtée')}catch(x){console.warn(x)}
 try{const sn=d.snapshot;if(sn){const key=sn.name+'@'+sn.at;if(key!==lastSnap){lastSnap=key;
    // Un seul téléchargement (réponse no-store), image remplacée une fois décodée : pas de clignotement.
    fetch('/snapshot?t='+encodeURIComponent(key),{cache:'no-store'}).then(r=>r.ok?r.blob():Promise.reject(r.status)).then(b=>{const u=URL.createObjectURL(b),im=new Image();im.onload=()=>{const old=$('snap-img').src;$('snap-img').src=u;$('snap-btn').hidden=false;if(old.startsWith('blob:')&&$('dlg-img').src!==old)URL.revokeObjectURL(old)};im.src=u}).catch(x=>{lastSnap=null;console.warn('capture',x)})}
   $('snap-meta').textContent=`${sn.name} · ${dhm(sn.at)} (il y a ${ago(now-sn.at)})`;$('snap-h').textContent=sn.count?sn.count+' au total':''}
  else{$('snap-btn').hidden=true;$('snap-meta').textContent='Aucune capture.';lastSnap=null}}catch(x){console.warn(x)}
 safe('s-feat',()=>{const fs=(d.features||[]).slice(),cur=d.current?String(d.current.id).slice(0,3):null;
  const rank=f=>f.id===cur||stepClass(f.step)==='acc'?0:stepClass(f.step)==='bad'?1:stepClass(f.step)==='todo'?2:3;
  fs.sort((a,b)=>rank(a)-rank(b)||String(b.id).localeCompare(String(a.id)));
  const n={ok:0,warn:0,bad:0,acc:0,todo:0};fs.forEach(f=>n[stepClass(f.step)]++);
  $('feat-h').textContent=`${fs.length} · ${n.acc} en cours · ${n.todo} à faire · ${n.ok+n.warn} terminées (${n.warn} avec réserve) · ${n.bad} bloquée(s)`;
  return fs.map(f=>{const c=stepClass(f.step),isCur=f.id===cur;return `<div class="tile ${c}${isCur?' cur':''}" title="${e((f.id??'')+' — '+(f.name??'')+'\n\n'+(f.step??'')+(f.backlog?'\n\nBacklog : '+f.backlog:'')+(f.updated?'\nMis à jour : '+f.updated:''))}"><div class="hd"><span class="id">${e(f.id)}</span><span class="muted" style="font-size:12px">${e(f.milestone)}${isCur?' · en cours':''}</span></div><div class="nm">${e(f.name)}</div><div>${pill(stepShort(f.step),c)}</div><div class="st">${e(f.step)}</div></div>`}).join('')||'<p class="muted">Aucune fonctionnalité.</p>'});
 safe('s-q',()=>{const qs=d.questions||[];$('s-q').querySelector('h2').firstChild.textContent=`Questions pour toi (${qs.length}) `;return qs.length?`<div class="scroll"><table>${qs.map(q=>`<tr><td class="mono">${e(q.id)}</td><td>${e(q.question)}<div class="muted">${e(q.due)}</div></td></tr>`).join('')}</table></div>`:'<p class="muted">Aucune.</p>'});
 safe('s-gates',()=>{const g=d.gates||[];return g.length?`<div class="scroll"><table><tr><th>Heure</th><th>Mode</th><th>Commit</th><th>Résultat</th></tr>${g.map(g=>`<tr><td title="${e(g.day)}">${e(g.at)}</td><td class="mono">${e(g.mode)}</td><td class="mono">${e(g.sha)}${g.clean==='yes'?'':' *'}</td><td>${pill(g.result,g.result==='VERT'?'ok':'bad')}</td></tr>`).join('')}</table></div><p class="muted">* arbre non propre (porte de tâche)</p>`:'<p class="muted">Aucune porte enregistrée.</p>'});
 safe('s-journal',()=>(d.journal||[]).map(j=>`<p style="margin:0 0 8px"><span class="muted">${e(j.date)}</span> ${e((j.event||'').replace(/\*\*/g,'').slice(0,320))}</p>`).join('')||'<p class="muted">Journal vide.</p>');
 safe('s-git',()=>`<div class="kv" style="margin-bottom:8px"><span class="muted">Branche</span><span class="mono">${e(git.branch||'—')}</span><span class="muted">origin/main</span><span class="mono">${e(git.origin_main||'—')}</span></div><div class="scroll"><table>${(git.log||[]).map(l=>`<tr><td class="mono">${e(l.sha)}</td><td class="mono muted">${e(l.at)}</td><td>${e(l.msg)}</td></tr>`).join('')}</table></div>`);
 safe('s-sup',()=>{const s=d.supervisor||[];return (s.length?`<pre class="mono">${e(s.join('\n'))}</pre>`:'<p class="muted">Rien à signaler.</p>')+(errs.length?`<p class="err" style="margin-top:8px">Erreurs de lecture du tableau de bord :<br>${errs.map(e).join('<br>')}</p>`:'')});
}
$('snap-btn').addEventListener('click',()=>{$('dlg-img').src=$('snap-img').src;$('dlg-cap').textContent=$('snap-meta').textContent;$('dlg').showModal()});
$('dlg').addEventListener('click',()=>$('dlg').close());
load();setInterval(load,20000);
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    worktree = ""

    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/":
            self._send(200, PAGE.encode("utf-8"), "text/html; charset=utf-8")
        elif path == "/api/state":
            try:
                body = state(self.worktree)
            except Exception as exc:  # noqa: BLE001 - toujours répondre du JSON
                body = {"now": int(time.time()), "worktree": self.worktree, "exists": True,
                        "errors": [f"état : {type(exc).__name__}: {exc}"]}
            self._send(200, json.dumps(body, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
        elif path == "/snapshot":
            snaps = sorted(glob.glob(os.path.join(self.worktree, ".omc", "state", "loop", "snapshots", "*.png")), key=os.path.getmtime)
            if snaps:
                with open(snaps[-1], "rb") as f:
                    self._send(200, f.read(), "image/png")
            else:
                self._send(404, b"aucune capture", "text/plain; charset=utf-8")
        else:
            self._send(404, html.escape("introuvable").encode("utf-8"), "text/plain; charset=utf-8")

    def log_message(self, *args):
        pass


def main():
    ap = argparse.ArgumentParser(description="Tableau de bord local de la boucle")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--worktree", default=default_worktree())
    args = ap.parse_args()
    Handler.worktree = os.path.abspath(args.worktree)
    srv = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Tableau de bord : http://127.0.0.1:{args.port}  (worktree : {Handler.worktree}) · Ctrl-C pour arrêter")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
