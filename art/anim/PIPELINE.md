# Blender -> Roblox animation pipeline (Tacticals)

Written by the weapons animator, 2026-10-30, for every animator on Tacticals. Proven end to end on one clip first
(see "Proof" at the bottom); every later clip goes the same way.

## The rig
- Source: Edward's starter rig `OneDrive/Documents/Blender/Roblox Starter Rigs/Rigs/Starter_Blocky_Rig.blend`. **Never edit
  the original**: the working copy is `art/anim/rig/Starter_Blocky_Rig.blend` (textures beside it).
- The copy is a bendy blocky rig (one skinned torso, arms, legs) with R15-named deform bones: `Lowertorso`, `Uppertorso`,
  `Head`, `Upperarm/Lowerarm/Hand.R/L`, `Upperleg/Lowerleg/Foot.R/L`. 1 Blender unit = 1 stud; the character faces +Y
  (Roblox -Z), its right is +X.
- **Pivots:** the starter rig's arm bones sit in the middle of the arm (x = 1.5) while R15's shoulders pivot at the inner top
  edge of the arm; legs and neck differ a little too. `rbxanim.setup_rig()` moves every deform bone onto the R15 Motor6D
  pivots read from Studio (`art/anim/weapons/blender/r15.json`, made by `art/anim/weapons/studio/read_r15.lua` on a default
  R15 built with `Players:CreateHumanoidModelFromDescription`). The skin follows (rest-relative deform), so what you see in
  Blender rotates about the same points as in Roblox.
- `setup_rig()` also replaces the starter rig's control bones with a small clean set:
  `Gun` (the held item, chest space; the gun hand follows it by IK at the real Tool grip), `IK_Hand.R/L` (blend between
  `<side>_Gun` and `<side>_Free` with the custom property `free`), `Pole_Arm.R/L`, `IK_Foot.R/L` + `Pole_Leg.R/L` (feet
  planted), and one bone per moving gun part (Slide, Mag, Bolt, ...) under `Gun`.

## Authoring
- Clips are Python in `art/anim/weapons/blender/clips/<set>.py` using `rbxanim.Clip` (Roblox conventions: studs, degrees,
  X right, Y up, -Z forward). Keys go on Blender f-curves; Bezier with auto-clamped handles (ease in/out, no overshoot) by
  default, per-key interpolation for contacts (e.g. `interp="EXPO", easing="EASE_IN"` into a hit, `"LINEAR"` for the
  1-frame shot kick). Loops get a Cycles modifier and identical first/last keys.
- Build: `blender -b art/anim/rig/Starter_Blocky_Rig.blend --python art/anim/weapons/blender/make.py -- <set> [clips]`.
  It saves `art/anim/weapons/blender/sets/<set>.blend` (the rig + one action per clip: open it to look at or tweak the
  curves) and writes `out/anim_weapons/json/<Clip>.json` + `<Clip>Left.json`.

## Export (what makes it exact)
- `rbxanim.export_clip()` evaluates the rig at 60 fps and computes each R15 joint's Motor6D `Transform` from the posed parts:
  `T = C0^-1 * Part0(t)^-1 * Part1(t) * C1`. Only the Root joint (LowerTorso) keeps a translation; the others are rotation
  only, so the clip fits real avatars of any proportions.
- Keys are reduced to the fewest frames that stay within 0.12 deg / 0.004 studs of the 60 fps curve, then written with
  Linear easing (the Blender curve is already baked into the key spacing). Markers get their own key.
- `...Left` = the mirror (x -> -x, Left <-> Right joints). The gun parts (Slide, Mag...) keep their own motion; the Handle
  pose sits under LeftHand in the mirror (the game moves the grip to the left hand: WeaponUtil.SetGunHand).

## Into Studio
- `art/anim/weapons/studio/build_clips.lua` with the JSON prepended as `local CLIPS_JSON = [==[...]==]` builds the
  KeyframeSequences into `ReplicatedStorage.Repository.AnimationSources` (same names the code loads). A clip whose
  `SourceHash` changed loses its old `PublishedId` (it needs a new upload).
- No FBX and no Animation Editor import step: the JSON route is deterministic and keeps the exact 60 fps curves. (The
  Animation Editor's FBX import works too, but it needs clicks, re-keys every frame and can't carry markers.)
- Publishing: right-click the KeyframeSequence > Save to Roblox, Creator **gunsy funsy** (the dropdown starts on "Me" every
  time), then `PublishedId = "rbxassetid://<id>"` on the source (`art/anim/weapons/install_sources.lua`).

## Proof
(filled in below once the first clip has made the full trip)
