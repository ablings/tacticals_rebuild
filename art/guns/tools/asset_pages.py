"""One vault Asset Library page per gun (no game names): 02 Modeling/Asset Library/Weapon/Articulated Lowpoly <Kind>.md"""
import json, os, shutil
R = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
V = os.path.expanduser(r"~\Documents\ObsidianVault\wiki\02 Modeling\Asset Library\Weapon")
IMG = os.path.expanduser(r"~\Documents\ObsidianVault\wiki\02 Modeling\Asset Library\Weapon\img")
KIND = {"Pistol": "Service Pistol", "SilencedPistol": "Suppressed Pistol", "DualPistols": "Compensated Compact Pistol",
        "Revolver": "Swing-Out Revolver", "MiniUzi": "Open-Bolt Machine Pistol", "AutoRifle": "Gas Carbine",
        "SemiAuto": "Marksman Rifle", "Sniper": "Chassis Bolt-Action Rifle", "PumpShotgun": "Tactical Pump Shotgun",
        "Knife": "Field Knife", "Katana": "Katana", "Bat": "Baseball Bat", "RiotShield": "Riot Shield", "Fists": "Hand Wraps",
        "Frag": "Egg Frag Grenade", "Smoke": "Can Smoke Grenade", "Flash": "Slotted Flashbang", "StickyGrenade": "Sticky Ball Grenade",
        "Landmine": "Pressure Plate Mine", "Medkit": "Hard-Case Medkit"}
KNOBS = {
 "Pistol": [("Slide cuts", "5 slanted rear", "0-6, front and/or rear, vertical or slanted"), ("Grip", "raked, inset panels", "rake 0-20 deg, finger grooves, flared well"), ("Frame colour", "near-black", "any furniture colour vs a dark slide")],
 "SilencedPistol": [("Suppressor", "12-sided can, 2 grooves", "8-16 sides, 0-4 grooves, offset (piggyback) can"), ("Sights", "tall suppressor sights", "standard / optic plate"), ("Mag", "extended pad", "flush")],
 "DualPistols": [("Comp", "2 top ports + side windows", "1-3 ports, round or slot"), ("Slide colour", "light two-tone", "matching frame"), ("Trigger", "flat skeleton", "curved solid")],
 "Revolver": [("Barrel", "4 in. full underlug", "snub to 6 in., half lug"), ("Cylinder", "6 flutes", "5-8 chambers, unfluted"), ("Grip", "finger-groove wood", "smooth target, rubber")],
 "MiniUzi": [("Stock", "folding wire, 2 rails a side", "none, collapsing tube, side folder"), ("Top cover", "3 slots a side", "1-5 slots, smooth"), ("Mag", "long stick", "short stick, extended")],
 "AutoRifle": [("Handguard", "octagon, 3 slot rows", "round, 1-4 rows, quad rail"), ("Optic", "red-dot tube", "box sight, irons only"), ("Stock", "skeleton collapsible", "fixed, tube only")],
 "SemiAuto": [("Scope", "4x on 2 rings", "1-6x, LPVO, red-dot"), ("Stock", "skeleton + cheek riser", "fixed rifle stock"), ("Brake", "2 ports", "1-4 ports, flash hider")],
 "Sniper": [("Chassis", "slotted U-channel", "wood stock, thumbhole"), ("Scope", "long + flip caps", "short fixed power"), ("Bipod", "two folding legs", "none, monopod")],
 "PumpShotgun": [("Pump", "8 grooves", "smooth, shorter"), ("Saddle", "4 shells left side", "none, 6-shell"), ("Stock", "pistol-grip synthetic", "straight stock, folding")],
 "Knife": [("Blade", "clip point + grind line", "drop point, tanto, serrated spine"), ("Grip", "finger grooves", "straight, cord wrap"), ("Guard", "single finger guard", "double, none")],
 "Katana": [("Curve", "0.13 sori", "0-0.2"), ("Wrap", "7 diamond windows", "5-10, solid wrap"), ("Guard", "round", "square, cut-out pattern")],
 "Bat": [("Profile", "classic taper", "drop-end, softball"), ("Tape", "black sleeve", "spiral bands, none"), ("Band", "burned band", "none, 2 bands")],
 "RiotShield": [("Outline", "chamfered rectangle", "round top, full-length window"), ("Curve", "sagitta 0.15", "flat - 0.3"), ("Light", "top-right torch", "none, two lights")],
 "Fists": [("Wrap", "3 groove bands", "1-5 bands, smooth glove"), ("Pad", "knuckle pad + strap", "studded, none")],
 "Frag": [("Body", "tall egg", "ball, ribbed pineapple (cut grid)"), ("Band", "one cream band", "none, two bands")],
 "Smoke": [("Holes", "2 rows of 6 side holes", "top-face holes, slots"), ("Band", "cream band", "colour-coded cap")],
 "Flash": [("Ports", "3 rows of 4 slots", "round holes, 2 rows"), ("Body", "slim can", "hex body")],
 "StickyGrenade": [("Cover", "adhesive band + backing tab", "full sticky shell"), ("Body", "ball", "puck")],
 "Landmine": [("Plate", "small raised plate", "flush plate, prongs"), ("Controls", "rotary switch + pin", "toggle switch")],
 "Medkit": [("Case", "flat-lid hard case", "soft pouch with zip"), ("Contents", "injector + bandage", "pill tube, splint")],
}
os.makedirs(IMG, exist_ok=True)
for g, kind in KIND.items():
    m = json.load(open(f"{R}/art/guns/manifest/{g}.json"))
    c = json.load(open(f"{R}/art/guns/renders/{g}/check.json"))
    slug = kind.replace(" ", "_").lower()
    for n in ("side", "exploded"):
        shutil.copy(f"{R}/art/guns/renders/{g}/{n}.png", f"{IMG}/al_art_{slug}_{n}.png")
    mv = [p for p in m["parts"] if p["motion"] != "static"]
    L = ["---", "kind: weapon", "style: flat-lowpoly (articulated)", f"name: {kind}", f"tris: {m['total_tris']}",
         f"size_studs: {m['overall_size_LxHxW'][0]} L x {m['overall_size_LxHxW'][1]} H x {m['overall_size_LxHxW'][2]} W",
         f"splits: {len(m['parts'])} meshes / {len(mv)} moving parts", "materials: SmoothPlastic flat colours, Glass for lenses",
         "collision: none (held tool)", "source_log: \"built 2026-10-30 from a generated side-view reference (own design)\"", "---",
         f"# Articulated Lowpoly {kind}", "", f"![[al_art_{slug}_side.png]]", f"![[al_art_{slug}_exploded.png]]",
         "*Top: side view. Bottom: every moving part pulled out along its motion.*", "",
         "## Look",
         "Flat low-poly from a generated orthographic side view with real proportions: profile extrusions, 8-sided cylinders,",
         "slots and ports cut as holes (the inset method), one mesh per colour per moving part. Unlike the base flat-lowpoly",
         "entries it splits **every real moving part** (triggers, levers, latches, covers, bolts, rounds) with its pivot on",
         "the real hinge or slide axis, so close animation reads like the real mechanism.", "",
         f"## Parts ({m['total_tris']} tris, script check: {c['summary'].split(': ', 1)[1]})",
         "Frame: x right, y up, z back (muzzle toward -z), origin = grip centre (the tool grip).", "",
         "| Part | Parent | Pivot | Motion | Tris |", "|---|---|---|---|---|"]
    for p in m["parts"]:
        L.append(f"| {p['name']} | {p['parent']} | {tuple(p['pivot'])} | {p['motion']} | {p['tris']} |")
    L += ["", "## Construction recipe",
          "1. Grid the reference in studs (overall length = the game's length for the class) and read every outline point off it.",
          "2. Each static body piece = one side-profile prism (or a front-section prism for receivers and fore-ends); holes",
          "   (guards, ports, slots, skeleton stocks) are boolean cuts of a prism; hollow handguards/channels are cut so slots",
          "   go through and the barrel shows inside.",
          "3. Round parts are lathes (stations + radii; radius 0 closes to a point), 8-sided, 10-12 for scopes and cans.",
          "4. Moving parts: own mesh, origin on the pivot; hidden tabs inside the body link neighbours the way the real",
          "   mechanism does (trigger bar, sear, hand/pawl, bolt-catch tab, charging-handle key), which also makes neighbouring",
          "   parts truly overlap instead of nearly touching.",
          "5. Build with resolve_coplanar, normal_update, then BEAUTY triangulation; armature with one bone per moving part.", "",
          "## Originality knobs", "| Knob | Base | Range |", "|---|---|---|"]
    for k in KNOBS.get(g) or KNOBS.get(kind):
        L.append(f"| {k[0]} | {k[1]} | {k[2]} |")
    L += ["", "## Proof check", f"{c['summary']}; warnings are flush-face notes on stepped surfaces inside other parts.", "",
          "## Siblings", "[[Flat Lowpoly Handgun]] · [[Flat Lowpoly Assault Rifle]] · [[Flat Lowpoly Revolver]] · [[Flat Lowpoly Pump Shotgun]] · [[Flat Lowpoly Bolt-Action Sniper]] · [[Flat Lowpoly Machine Pistol]]", ""]
    open(f"{V}/Articulated Lowpoly {kind}.md", "w", encoding="utf-8").write("\n".join(L))
    print("page", kind)
