"""Offline dry run of fix/ui_survey_r2.lua: apply its anchor edits to a place's dumped sources (rbxl_read + dump_src index)
and report per script: applied / already in / anchor missing / doubled. Read-only.
Usage: python tools/ui_survey_r2_offline.py <src dir with _index.json>"""
import importlib.util, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1]; sys.argv = sys.argv[:1]  # the builder reads argv[1] as its base commit
spec = importlib.util.spec_from_file_location("b", os.path.join(ROOT, "tools", "ui_survey_r2_build.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
idx = json.load(open(os.path.join(SRC, "_index.json"), encoding="utf-8"))
by = {}
for e in idx:
    by.setdefault(e["path"], e)
bad = 0
for rel, paths in m.TARGETS.items():
    old = m.git_show(m.BASE, rel)
    new = m.norm(open(os.path.join(m.UI, rel), encoding="utf-8").read())
    hs = m.hunks(old, new)
    for p in paths:
        e = by.get("game." + p) or by.get(p) or next((v for k, v in by.items() if k.endswith(p)), None)
        if not e:
            print(f"  (absent) {p}")
            continue
        src = m.norm(open(os.path.join(os.path.dirname(os.path.abspath(SRC)), e["file"]), encoding="utf-8").read())
        done = skip = 0; prob = None
        for i, (o, n) in enumerate(hs, 1):
            c = src.count(o)
            if c > 1: prob = f"edit {i} anchor x{c}"; break
            if c == 1: src = src.replace(o, n); done += 1
            elif n in src: skip += 1
            else: prob = f"edit {i} anchor missing: {o[:80]!r}"; break
        if prob: bad += 1
        print(("PROBLEM " if prob else "ok      ") + f"{p.split('.')[-1]:<26} {done} applied / {skip} in" + (f"  {prob}" if prob else ""))
print("problems:", bad)
