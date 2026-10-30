"""Write art/anim/guns/DONE.md from the manifests, check results and (optional) art/guns/mesh_ids.json."""
import json, os
R = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
G = "Pistol SilencedPistol DualPistols Revolver MiniUzi AutoRifle SemiAuto Sniper PumpShotgun".split()
ids_path = os.path.join(R, "art", "guns", "mesh_ids.json")
ids = json.load(open(ids_path)) if os.path.exists(ids_path) else {}
grades_path = os.path.join(R, "art", "guns", "grades.json")
grades = json.load(open(grades_path)) if os.path.exists(grades_path) else {}
L = ["# Guns: remodel status (modeler)", "",
     "Flat low-poly (RIVALS weapon method: profile extrusions, 8-sided cylinders, inset slots, one mesh per colour per moving",
     "part) with real-world proportions from a Codex side-view reference per gun, and many more moving parts, each its own",
     "mesh with its pivot on its real hinge / slide axis.", "",
     "## How to use",
     "- Blender: `art/anim/guns/<Gun>.blend`. Collection `Gun_<Gun>` = armature `GunRig_<Gun>` (root bone `Handle` at the grip",
     "  centre, one bone per moving part at its pivot, named after the part) with every mesh bone-parented, plus attachment empties.",
     "  The armature hangs from `RightGripAttachment`, an empty on bone `Hand.R` of an appended copy of the Starter Blocky rig",
     "  (1 stud below the arm centre, rotated -90 deg about X like Roblox's RightGripAttachment; rest pose = muzzle down).",
     "- `art/anim/guns/<Gun>.fbx`: armature + meshes + empties at the origin (for animation tools).",
     "- `art/guns/fbx/<Gun>_roblox.fbx`: meshes only, at rest in Handle space, + 10-stud ScaleCube and an L Marker (delete after import).",
     "- `art/guns/manifest/<Gun>.json`: per part: parent, Motor6D name, pivot, bbox centre, size, colour, material, WrapChannel, motion.",
     "- Frame (Roblox, Handle space): x right, y up, z back, muzzle toward -z. Handle = invisible 0.2 x 0.6 x 0.3 Part at the grip",
     "  centre, `Tool.Grip` = identity (as the old tools). Every mesh hangs off Handle (or its parent part) by a **Motor6D named",
     "  after the part** (Part0 = parent part, Part1 = the part, C0/C1 at the pivot, no rotation: joint axes = gun axes).",
     "- WrapChannel: `A` = body surfaces, `B` = details, `skip` = glass (set WrapSkip). Material SmoothPlastic, Glass for lenses.",
     "- Rebuild one gun: `blender -b --factory-startup --python art/guns/tools/build_gun.py -- <Gun>` (spec in tools/specs/).", "",
     "## Studio import / upload (not done yet)",
     "- Meshes are **not uploaded yet**: Creator Hub only takes images/audio/video, and AssetService:CreateAssetAsync answers",
     "  \"not available yet\" in Studio (tested 2026-10-30). Upload = Studio Import 3D of `art/guns/fbx/<Gun>_roblox.fbx`",
     "  (Creator = gunsy funsy, Insert Using Scene Position), which needs a session with computer use (clicks in the dialog).",
     "- After import: measure ScaleCube (B1), check Marker orientation (B2), delete both, then build the Tool from the manifest:",
     "  invisible Handle at the origin, each MeshPart placed at its bbox_centre, Motor6D named after the part at its pivot,",
     "  colour/material/WrapChannel from the manifest, attachments from the manifest (Muzzle keeps the old flash children).", "",
     "## Guns"]
for g in G:
    m = json.load(open(os.path.join(R, "art", "guns", "manifest", g + ".json")))
    c = json.load(open(os.path.join(R, "art", "guns", "renders", g, "check.json")))
    mv = [p for p in m["parts"] if p["motion"] != "static"]
    L += ["", f"### {g}", f"- Size L x H x W: {m['overall_size_LxHxW']} studs; {m['total_tris']} tris; {len(m['parts'])} meshes, {len(mv)} moving.",
          f"- Script check: {c['summary'].split(': ', 1)[1]}.",
          f"- Grade: {grades.get(g, 'pending (HQ grader)')}.",
          f"- Mesh ids: {('see table' if g in ids else 'pending upload')}.", "",
          "| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |", "|---|---|---|---|---|---|---|"]
    for p in m["parts"]:
        mid = ids.get(g, {}).get(p["name"], "")
        L.append(f"| {p['name']} | {p['parent']} | {tuple(p['pivot'])} | {p['motion']} | {p['tris']} | {p['wrap']} | {mid} |")
    L += ["", "Attachments: " + "; ".join(f"`{k}` on {v['part']} at {tuple(v['position_handle_space'])}" for k, v in m["attachments"].items())]
open(os.path.join(R, "art", "anim", "guns", "DONE.md"), "w", encoding="utf-8").write("\n".join(L) + "\n")
print("DONE.md written")
