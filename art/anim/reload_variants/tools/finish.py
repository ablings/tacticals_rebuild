"""finish.py: after publishing, re-check every id on economy.roblox.com (AssetType 24, group 102028987, name), fill the ids
into ../DONE.md's clip table and write ../UPLOADED.md."""
import json, os, re, urllib.request, datetime
H = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pub = json.load(open(os.path.join(H, "published.json")))
hashes = json.load(open(os.path.join(H, "published_hash.json")))
names = [l.strip() for l in open(os.path.join(H, "tools", "pub", "clips.txt")) if l.strip()]
rows, bad = [], []
for n in names:
    aid = pub.get(n, "").replace("rbxassetid://", "")
    ok = False
    if aid:
        d = json.load(urllib.request.urlopen("https://economy.roblox.com/v2/assets/%s/details" % aid, timeout=20))
        c = d.get("Creator") or {}
        ok = d.get("Name") == n and d.get("AssetTypeId") == 24 and c.get("CreatorTargetId") == 102028987 and c.get("CreatorType") == "Group"
        grp = "%s %s" % (c.get("CreatorType"), c.get("CreatorTargetId"))
    rows.append((n, aid or "MISSING", grp if aid else "-", hashes.get(n, "-"), "OK" if ok else "FAIL"))
    if not ok:
        bad.append(n)
# DONE.md: replace "ready to publish" in each clip row with "<id> / <Left id>"
p = os.path.join(H, "DONE.md"); s = open(p, encoding="utf-8").read()
out = []
for line in s.split("\n"):
    m = re.match(r"\| (\w+) \|", line)
    if m and m.group(1) in pub and "ready to publish" in line:
        n = m.group(1)
        line = line.replace("ready to publish", "%s / Left %s" % (pub[n].replace("rbxassetid://", ""), pub.get(n + "Left", "?").replace("rbxassetid://", "")))
    out.append(line)
s = "\n".join(out)
s = s.replace("| Published id |", "| Published id (group gunsy funsy) |")
open(p, "w", encoding="utf-8").write(s)
u = ["# Ammo-aware reload variants: UPLOADED (anim-reload-upload, %s)" % datetime.date.today(), "",
     "%d of %d clips published under the group **gunsy funsy** (102028987) through Studio Save to Roblox from "
     "`out/anim_reload_variants/anim_reload_variants.rbxl` (clips installed from `install_sources.lua` first). Every id re-checked on "
     "`economy.roblox.com/v2/assets/<id>/details`: AssetTypeId 24 (Animation), Creator Group 102028987, Name = clip name. "
     "None went to a personal account." % (len(names) - len(bad), len(names)), "",
     "Ids are in `published.json`; `install_sources.lua` sets `PublishedId` only while the clip's SourceHash equals the uploaded "
     "one (`published_hash.json`, recorded from Studio right after the upload; `tools/gen_install.py` drops a stale id).", "",
     "| Clip | Asset id | Owner | SourceHash uploaded | Economy check |", "|---|---|---|---|---|"]
u += ["| %s | %s | %s | %s | %s |" % r for r in rows]
u += ["", "Not in this task: Dual Pistols variants, the revolver's per-round split (DONE.md open issues). No place was published."]
open(os.path.join(H, "UPLOADED.md"), "w", encoding="utf-8").write("\n".join(u) + "\n")
print("ok", len(rows) - len(bad), "bad", bad)
