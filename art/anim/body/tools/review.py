"""review.py <out.png> <spec>... : spec = clip[+layer...]@where@times@views[@avatar[@gun[@hand]]] ; stacks the sheets."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from mcpsess import Session
from shoot import shoot, ROOT
from PIL import Image
s = Session(open(os.path.join(ROOT, "out/anim_body/studio_id.txt")).read().strip())
outs = []
for i, spec in enumerate(sys.argv[2:]):
    p = spec.split("@") + [None] * 6
    parts = p[0].split("+")
    times = [float(x) for x in p[2].split(",")]
    views = p[3].split(",")
    o = os.path.join(ROOT, "out/anim_body/shots/_rev%d.png" % i)
    outs.append(shoot(s, o, parts[0], times, views, p[4] or "AvatarA", p[5] or "Pistol", p[6] or "R", p[1],
                      "+".join(parts[1:]) or None, title=p[0] + " @" + p[1], size=200, dist=0.75))
s.close()
ims = [Image.open(o) for o in outs]
W = max(i.width for i in ims); H = sum(i.height for i in ims)
sh = Image.new("RGB", (W, H)); y = 0
for i in ims: sh.paste(i, (0, y)); y += i.height
sh.save(sys.argv[1]); print(sys.argv[1], sh.size)
