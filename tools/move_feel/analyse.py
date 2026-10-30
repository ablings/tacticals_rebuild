"""Foot drift per step from tools/move_feel/lib.lua record() dumps.
python -I tools/move_feel/analyse.py <dump.json> [...]   -> per label: steps, drift per step (studs, + = carried forward = clip too
slow), body travel per step, slip = drift / body travel, suggested Authored scale (multiply the clip's authored speed by it)."""
import json, sys, math

def contacts(rows, xi, yi, zi):
    hs = sorted(r[yi] - r[6] for r in rows)
    lo = hs[max(0, len(hs) // 20)]
    out, cur = [], []
    for r in rows:
        if r[13] == 0 and r[yi] - r[6] < lo + 0.03:
            cur.append(r)
        else:
            if len(cur) >= 3: out.append(cur)
            cur = []
    if len(cur) >= 3: out.append(cur)
    return out

def analyse(label, rows):
    rows = [r for r in rows if math.hypot(r[4], r[5]) > 1]
    if len(rows) < 10: return f"{label}: too few frames"
    steps = []
    for xi, yi, zi in ((7, 8, 9), (10, 11, 12)):
        for c in contacts(rows, xi, yi, zi):
            a, b = c[0], c[-1]
            vx = sum(r[4] for r in c); vz = sum(r[5] for r in c)
            n = math.hypot(vx, vz) or 1
            dx, dz = vx / n, vz / n
            drift = (b[xi] - a[xi]) * dx + (b[zi] - a[zi]) * dz
            body = (b[1] - a[1]) * dx + (b[3] - a[3]) * dz
            if body > 0.2: steps.append((drift, body))
    if not steps: return f"{label}: no steps"
    d = sum(s[0] for s in steps) / len(steps); bt = sum(s[1] for s in steps) / len(steps)
    sl = d / bt
    sp = sum(math.hypot(r[4], r[5]) for r in rows) / len(rows)
    # playback too slow by sl: the clip should run 1 / (1 - sl) faster -> authored speed x (1 - sl)
    return f"{label}: speed {sp:.1f}, steps {len(steps)}, drift/step {d:+.3f}, body/step {bt:.2f}, slip {sl:+.3f}, authored x{1 - sl:.2f}"

for f in sys.argv[1:]:
    for e in json.load(open(f, encoding="utf-8")):
        print(analyse(e["label"], e["rows"]))
