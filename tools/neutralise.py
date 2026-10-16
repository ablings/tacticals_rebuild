"""Suggest part colours that render neutral (slightly warm) from part_pixels.py outputs.
Usage: python tools/neutralise.py px1.txt [px2.txt ...] ; prints name old -> new (render-weighted ratio per channel)."""
import re, sys
acc = {}
for f in sys.argv[1:]:
    for line in open(f, encoding="utf-8"):
        m = re.match(r"(\S+)\s+n\s*(\d+) render\s+([\d.]+),\s*([\d.]+),\s*([\d.]+)\s+part (\d+),(\d+),(\d+)", line)
        if not m: continue
        name, n = m.group(1), int(m.group(2))
        r = [float(m.group(i)) for i in (3, 4, 5)]; c = [float(m.group(i)) for i in (6, 7, 8)]
        a = acc.setdefault(name, [0, [0, 0, 0], c])
        a[0] += n
        for k in range(3): a[1][k] += r[k] * n
WARM = (1.03, 1.0, 0.96)
for name, (n, rs, c) in sorted(acc.items()):
    r = [v / n for v in rs]
    L = sum(r) / 3
    new = [max(0, min(255, round(c[k] * (L * WARM[k]) / max(r[k], 1)))) for k in range(3)]
    print(f"{name:32s} n{n:4d} render {r[0]:.0f},{r[1]:.0f},{r[2]:.0f} part {c[0]:.0f},{c[1]:.0f},{c[2]:.0f} -> {new[0]},{new[1]},{new[2]}")
