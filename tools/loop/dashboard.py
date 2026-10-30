#!/usr/bin/env python3
"""Tableau de bord local de la boucle de développement (lecture seule, stdlib uniquement).

Usage :
    python3 -I tools/loop/dashboard.py [--port 8765] [--worktree CHEMIN]
puis ouvrir http://127.0.0.1:8765 (rafraîchissement automatique).

Lit, sans rien modifier : specs/progress.md, specs/NNN-*/status.md,
product/roadmap/open-questions.md, .omc/state/loop/ (quota, portes, superviseur,
battement, captures), git et tmux. N'écoute que sur 127.0.0.1.
"""
import argparse
import glob
import html
import json
import os
import re
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))


def sh(cmd, cwd=None, timeout=10):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, str(exc)


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
    repo = os.path.dirname(common) if common else REPO
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


def state(wt):
    st = os.path.join(wt, ".omc", "state", "loop")
    now = int(time.time())
    out = {"now": now, "worktree": wt, "exists": os.path.isdir(wt)}
    if not out["exists"]:
        return out

    progress = read(os.path.join(wt, "specs", "progress.md"))
    feats = md_table(progress, "Fonctionnalités")
    out["features"] = [dict(zip(["id", "name", "backlog", "milestone", "step", "updated"], r)) for r in feats]
    out["journal"] = [dict(zip(["date", "event"], r)) for r in md_table(progress, "Journal")[:8]]

    current = None
    for f in sorted(glob.glob(os.path.join(wt, "specs", "[0-9][0-9][0-9]-*", "status.md"))):
        txt = read(f)
        step = field(txt, "Étape")
        if step and not step.startswith(("Terminée", "Définir |")):
            current = (f, txt, step)
    if current:
        f, txt, step = current
        journal = md_table(txt, "Journal")
        out["current"] = {
            "id": os.path.basename(os.path.dirname(f)),
            "step": step,
            "attempts": field(txt, "Tentatives"),
            "task": field(txt, "Tâche en cours"),
            "last": [dict(zip(["date", "step", "done", "proof"], r)) for r in journal[-4:]][::-1],
        }

    oq = read(os.path.join(wt, "product", "roadmap", "open-questions.md"))
    opened = []
    for line in oq.splitlines():
        if re.match(r"^\| Q-\d+", line):
            c = md_cells(line)
            status = c[-1] if c else ""
            if status.startswith("Ouverte"):
                opened.append({"id": c[0], "question": c[1], "due": c[-2] if len(c) > 2 else "", "reco": c[-4] if len(c) > 4 else ""})
    out["questions"] = opened

    q = {}
    try:
        q = json.loads(read(os.path.join(st, "quota.json"), "{}")).get("rate_limits", {})
    except ValueError:
        pass
    _, qc = sh([os.path.join(wt, "tools", "loop", "quota-check.sh")])
    _, budget = sh([os.path.join(wt, "tools", "loop", "openai-budget.sh"), "total"])
    out["quota"] = {"five_hour": q.get("five_hour", {}), "seven_day": q.get("seven_day", {}), "check": qc, "budget": budget}

    gates = []
    for line in read(os.path.join(st, "gates.tsv")).splitlines()[-12:]:
        p = line.split("\t")
        if len(p) >= 5:
            gates.append({"at": p[0][11:16], "sha": p[1][:7], "clean": p[2], "mode": p[3], "result": p[4]})
    out["gates"] = gates[::-1]
    out["supervisor"] = [l for l in read(os.path.join(st, "supervisor.log")).splitlines() if "superviseur" in l][-8:][::-1]

    def num(name):
        try:
            return int(read(os.path.join(st, name)).strip())
        except ValueError:
            return None

    hb = num("heartbeat")
    session = env_value("LOOP_TMUX_SESSION", "genesis-loop")
    rc_loop, _ = sh(["tmux", "has-session", "-t", session])
    rc_sup, _ = sh(["tmux", "has-session", "-t", "genesis-supervisor"])
    _, pane = sh(["tmux", "capture-pane", "-p", "-t", session])
    pane_lines = [l for l in pane.splitlines() if l.strip() and not set(l.strip()) <= set("─")]
    paused = num("paused_until")
    out["health"] = {
        "loop": rc_loop == 0,
        "supervisor": rc_sup == 0,
        "heartbeat_s": (now - hb) if hb else None,
        "paused_until": paused if paused and paused > now else None,
        "stop": os.path.exists(os.path.join(st, "STOP")),
        "fresh": os.path.exists(os.path.join(st, "fresh_session")),
        "dialog": bool(re.search(r"enter to confirm|do you want|allow external", pane, re.I)),
        "pane": pane_lines[-14:],
    }

    _, branch = sh(["git", "branch", "--show-current"], cwd=wt)
    _, log = sh(["git", "log", "--all", "-12", "--format=%h\t%ad\t%s", "--date=format:%d/%m %H:%M"], cwd=wt)
    _, origin = sh(["git", "log", "-1", "--format=%h %ad", "--date=format:%d/%m %H:%M", "origin/main"], cwd=wt)
    out["git"] = {"branch": branch, "origin_main": origin,
                  "log": [dict(zip(["sha", "at", "msg"], l.split("\t"))) for l in log.splitlines() if l]}

    snaps = sorted(glob.glob(os.path.join(st, "snapshots", "*.png")), key=os.path.getmtime)
    out["snapshot"] = {"name": os.path.basename(snaps[-1]), "at": int(os.path.getmtime(snaps[-1]))} if snaps else None
    return out


PAGE = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Boucle Genesis</title>
<style>
:root{--bg:#f6f7fb;--card:#fff;--fg:#1b1d29;--muted:#636a80;--line:#e3e6ef;--ok:#1a7f4b;--okbg:#e3f6ec;--warn:#9a6200;--warnbg:#fff3d6;--bad:#b42318;--badbg:#fde8e7;--acc:#5b3fd6;--accbg:#ece8ff}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#0c0d14;--card:#161827;--fg:#e8e9f2;--muted:#9aa0b8;--line:#272a3d;--ok:#5fd39a;--okbg:#123326;--warn:#f2c46b;--warnbg:#3a2c0c;--bad:#ff8a80;--badbg:#3d1716;--acc:#a996ff;--accbg:#262046}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
header{display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:space-between;padding:16px;border-bottom:1px solid var(--line)}
h1{font-size:18px;margin:0}h2{font-size:13px;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin:0 0 10px}
main{display:grid;gap:16px;padding:16px;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));max-width:1500px;margin:auto}
section{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px;min-width:0}
.wide{grid-column:1/-1}.pill{display:inline-block;padding:2px 9px;border-radius:999px;font-size:12px;font-weight:600}
.ok{color:var(--ok);background:var(--okbg)}.warn{color:var(--warn);background:var(--warnbg)}.bad{color:var(--bad);background:var(--badbg)}.acc{color:var(--acc);background:var(--accbg)}
table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:6px 6px;border-top:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:500;border-top:0}
.muted{color:var(--muted)}td.mono{white-space:nowrap}.mono{font-family:ui-monospace,Menlo,monospace;font-size:12px}.kv{display:grid;grid-template-columns:auto 1fr;gap:4px 12px}
.bar{height:8px;background:var(--line);border-radius:4px;overflow:hidden;margin:4px 0 10px}.bar>i{display:block;height:100%;background:var(--acc)}
pre{white-space:pre-wrap;word-break:break-word;margin:0;max-height:260px;overflow:auto;background:var(--bg);padding:10px;border-radius:8px}
img{max-width:100%;border-radius:8px;border:1px solid var(--line)}.scroll{overflow-x:auto}
@media (max-width:600px){main{padding:16px 16px;grid-template-columns:1fr}}
</style></head><body>
<header><h1>Boucle Genesis Canvas</h1><div id="top" class="muted">chargement…</div></header>
<main id="m"></main>
<script>
const e=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const pill=(t,c)=>`<span class="pill ${c}">${e(t)}</span>`;
const ago=s=>s==null?'—':s<90?`${s} s`:s<5400?`${Math.round(s/60)} min`:`${(s/3600).toFixed(1)} h`;
const hm=t=>new Date(t*1000).toLocaleString('fr-FR',{weekday:'short',hour:'2-digit',minute:'2-digit'});
function stepPill(s){s=s||'';if(s.startsWith('Terminée'))return pill(s.split('(')[0],'ok');if(s.startsWith('Bloquée'))return pill(s,'bad');return pill(s.split('(')[0],'acc')}
function quota(name,q){const u=q.used_percentage??null;return `<div>${name} · <b>${u==null?'?':Math.round(u)+' %'}</b> <span class="muted">${q.resets_at?'remise à zéro '+hm(q.resets_at):''}</span></div><div class="bar"><i style="width:${u||0}%"></i></div>`}
async function load(){
 let d;try{d=await (await fetch('/api/state',{cache:'no-store'})).json()}catch(x){document.getElementById('top').textContent='serveur injoignable';return}
 if(!d.exists){document.getElementById('m').innerHTML=`<section class="wide">Worktree introuvable : ${e(d.worktree)}</section>`;return}
 const h=d.health;let state=h.dialog?pill('bloquée : boîte de dialogue à valider (tmux attach -t genesis-loop)','bad'):h.stop?pill('STOP posé','bad'):h.paused_until?pill('pause quota jusqu’à '+hm(h.paused_until),'warn'):h.fresh?pill('nouvelle conversation imminente','acc'):!h.loop?pill('boucle arrêtée','bad'):(h.heartbeat_s!=null&&h.heartbeat_s>1800)?pill('inactive depuis '+ago(h.heartbeat_s),'warn'):pill('en marche','ok');
 document.getElementById('top').innerHTML=`${state} ${h.supervisor?pill('superviseur actif','ok'):pill('superviseur arrêté','bad')} <span class="muted">· mis à jour ${new Date(d.now*1000).toLocaleTimeString('fr-FR')}</span>`;
 const c=d.current;let html='';
 html+=`<section><h2>Maintenant</h2>${c?`<div style="font-size:16px;font-weight:600">${e(c.id)}</div><div style="margin:6px 0">${stepPill(c.step)} <span class="muted">tentatives ${e(c.attempts)}</span></div><div class="kv"><span class="muted">Tâche</span><span>${e(c.task||'—')}</span><span class="muted">Branche</span><span class="mono">${e(d.git.branch)}</span><span class="muted">Activité</span><span>il y a ${ago(h.heartbeat_s)}</span></div>${c.last.map(r=>`<p class="muted" style="margin:8px 0 0"><b>${e(r.step)}</b> — ${e((r.done||'').slice(0,260))}</p>`).join('')}`:'<p class="muted">Aucune fonctionnalité en cours (entre deux fonctionnalités ou en attente).</p>'}</section>`;
 html+=`<section><h2>Quota et budget</h2>${quota('Fenêtre 5 h',d.quota.five_hour)}${quota('Semaine',d.quota.seven_day)}<div class="kv"><span class="muted">Contrôle</span><span class="mono">${e(d.quota.check)}</span><span class="muted">OpenAI</span><span>${e(d.quota.budget)}</span><span class="muted">origin/main</span><span class="mono">${e(d.git.origin_main)}</span></div></section>`;
 html+=`<section class="wide scroll"><h2>Fonctionnalités</h2><table><tr><th>NNN</th><th>Fonctionnalité</th><th>Jalon</th><th>Étape</th></tr>${(d.features||[]).map(f=>`<tr><td class="mono">${e(f.id)}</td><td>${e(f.name)}</td><td>${e(f.milestone)}</td><td>${stepPill(f.step)}</td></tr>`).join('')}</table></section>`;
 html+=`<section><h2>Questions pour toi (${d.questions.length})</h2>${d.questions.length?`<table>${d.questions.map(q=>`<tr><td class="mono">${e(q.id)}</td><td>${e(q.question)}<div class="muted">${e(q.due)}</div></td></tr>`).join('')}</table>`:'<p class="muted">Aucune.</p>'}</section>`;
 html+=`<section><h2>Portes qualité</h2><table><tr><th>Heure</th><th>Mode</th><th>Commit</th><th>Résultat</th></tr>${d.gates.map(g=>`<tr><td>${e(g.at)}</td><td class="mono">${e(g.mode)}</td><td class="mono">${e(g.sha)}${g.clean==='yes'?'':' *'}</td><td>${pill(g.result,g.result==='VERT'?'ok':'bad')}</td></tr>`).join('')}</table><p class="muted">* arbre non propre (porte de tâche)</p></section>`;
 html+=`<section><h2>Journal de la boucle</h2>${(d.journal||[]).map(j=>`<p style="margin:0 0 8px"><span class="muted">${e(j.date)}</span> ${e((j.event||'').replace(/\\*\\*/g,'').slice(0,320))}</p>`).join('')}</section>`;
 html+=`<section><h2>Commits récents</h2><table>${d.git.log.map(l=>`<tr><td class="mono">${e(l.sha)}</td><td class="muted">${e(l.at)}</td><td>${e(l.msg)}</td></tr>`).join('')}</table></section>`;
 html+=`<section><h2>Dernière capture</h2>${d.snapshot?`<a href="/snapshot" target="_blank"><img src="/snapshot?t=${d.snapshot.at}" alt="Dernière capture de l’app"></a><p class="muted">${e(d.snapshot.name)}</p>`:'<p class="muted">Aucune capture.</p>'}</section>`;
 html+=`<section><h2>Superviseur</h2>${d.supervisor.length?`<pre class="mono">${e(d.supervisor.join('\\n'))}</pre>`:'<p class="muted">Rien à signaler.</p>'}</section>`;
 html+=`<section class="wide"><h2>Écran de la session</h2><pre class="mono">${e(h.pane.join('\\n'))}</pre></section>`;
 document.getElementById('m').innerHTML=html;
}
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
            self._send(200, json.dumps(state(self.worktree), ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
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
