"""gen_done.py: writes art/anim/weapons/DONE.md from out/anim_weapons/json/*.json + art/anim/weapons/published.json."""
import json, os, glob
H = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(H, "..", "..", "..", "out", "anim_weapons", "json")
pubf = os.path.join(H, "published.json")
pub = json.load(open(pubf)) if os.path.exists(pubf) else {}
SETS = [("Pistol (Pistol, Suppressed; Dual Pistols for now)", "Pistol"), ("Revolver", "Revolver"), ("SMG (Mini Uzi)", "SMG"),
        ("Rifle (Auto Rifle, Semi-Auto)", "Rifle"), ("Shotgun (Pump Shotgun)", "Shotgun"), ("Sniper", "Sniper"),
        ("Melee", ("Melee", "QuickMeleeBash")), ("Bat", "Bat"), ("Katana", "Katana"), ("Riot Shield", "RiotShield"),
        ("Gadgets", ("Smoke", "Frag", "Flash", "Landmine", "Medkit"))]
clips = {os.path.basename(p)[:-5]: json.load(open(p)) for p in glob.glob(os.path.join(D, "*.json"))}
out = ["# Weapon, melee and gadget animations: DONE (weapons animator, 2026-10-30)", "",
       "Final gameplay clips authored in Blender on Edward's Starter Blocky rig (R15 pivots), gun parts keyed in the same action",
       "on the remodelled guns (art/anim/guns, Motor6D per part). Pipeline: `art/anim/PIPELINE.md`. Sources:",
       "`art/anim/weapons/blender/clips/*.py` -> `blender/sets/*.blend`. Install into a place copy: run",
       "`art/anim/weapons/install_sources.lua` (all clips, markers, PublishedId). Captures: `captures/anim/weapons/`.",
       "Grade: by HQ's fresh grader after this task (the task did not self-grade: HQ rule).", ""]
for title, pref in SETS:
    prefs = pref if isinstance(pref, tuple) else (pref,)
    names = sorted(n for n in clips if n.startswith(prefs))
    if not names:
        continue
    out += ["## " + title, "", "| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |", "|---|---|---|---|---|---|---|"]
    for n in names:
        c = clips[n]
        body = {"HumanoidRootPart", "Handle", "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
                "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
                "RightLowerLeg", "RightFoot"}
        parts = sorted(set(c["tree"]) - body)
        out.append("| %s | %.3f | %s | %s | %s | %s | %s |" % (n, c["length"], "yes" if c["loop"] else "no", c["priority"],
                   ", ".join("%s %.3f" % (m["name"], m["t"]) for m in c["markers"]) or "-", ", ".join(parts) or "-",
                   pub.get(n, "ready to publish")))
    out.append("")
open(os.path.join(H, "DONE.md"), "w", encoding="utf-8").write("\n".join(out) + "\n" + open(os.path.join(H, "DONE_notes.md"), encoding="utf-8").read())
print("DONE.md", len(clips), "clips,", len(pub), "published")
