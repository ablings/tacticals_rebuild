# Guns, melee and gadgets: remodel status (modeler)

Flat low-poly (RIVALS weapon method: profile extrusions, 8-sided cylinders, inset slots, one mesh per colour per moving
part) with real-world proportions from a Codex side-view reference per gun, and many more moving parts, each its own
mesh with its pivot on its real hinge / slide axis.

## How to use
- Blender: `art/anim/guns/<Gun>.blend`. Collection `Gun_<Gun>` = armature `GunRig_<Gun>` (root bone `Handle` at the grip
  centre, one bone per moving part at its pivot, named after the part) with every mesh bone-parented, plus attachment empties.
  The armature hangs from `RightGripAttachment`, an empty on bone `Hand.R` of an appended copy of the Starter Blocky rig
  (1 stud below the arm centre, rotated -90 deg about X like Roblox's RightGripAttachment; rest pose = muzzle down).
- `art/anim/guns/<Gun>.fbx`: armature + meshes + empties at the origin (for animation tools).
- `art/guns/fbx/<Gun>_roblox.fbx`: meshes only, at rest in Handle space, + 10-stud ScaleCube and an L Marker (delete after import).
- `art/guns/manifest/<Gun>.json`: per part: parent, Motor6D name, pivot, bbox centre, size, colour, material, WrapChannel, motion.
- Frame (Roblox, Handle space): x right, y up, z back, muzzle toward -z. Handle = invisible 0.2 x 0.6 x 0.3 Part at the grip
  centre, `Tool.Grip` = identity (as the old tools). Every mesh hangs off Handle (or its parent part) by a **Motor6D named
  after the part** (Part0 = parent part, Part1 = the part, C0/C1 at the pivot, no rotation: joint axes = gun axes).
- WrapChannel: `A` = body surfaces, `B` = details, `skip` = glass (set WrapSkip). Material SmoothPlastic, Glass for lenses.
- Rebuild one gun: `blender -b --factory-startup --python art/guns/tools/build_gun.py -- <Gun>` (spec in tools/specs/).

## Studio import / upload (done 2026-10-30)
- **All 9 guns and the 11 melee/gadget items are uploaded** under the group gunsy funsy (102028987): 192 meshes (guns 132, melee/gadgets 60), every id
  checked on economy.roblox.com/v2/assets/<id>/details. Ids are in each table's Mesh id column and as `mesh_id` per part in
  `art/guns/manifest/<Gun>.json`. Method: Studio Import Queue (Home > Import, several FBX at once), Creator dropdown = gunsy funsy
  on every row, scratch place `out/gun_upload/upload.rbxl` (notes: `out/gun_upload/NOTES.md`).
- **Import facts for the Tool builder** (checked on all 192 parts against the manifests, error <= 0.0001 stud):
  the FBX imports at 100x (ScaleCube = 1000 studs, centimetres): set each MeshPart.Size = manifest `size`;
  the imported mesh data is turned 180 deg about Y against the manifest frame (Orientation reads 0, 0, 0, yet x and z come out
  negated): place each MeshPart at `CFrame.new(bbox_centre) * CFrame.Angles(0, math.pi, 0)` relative to Handle.
- If a gun's `_roblox.fbx` changes, re-upload it and replace its ids.
- After import: measure ScaleCube (B1), check Marker orientation (B2), delete both, then build the Tool from the manifest:
  invisible Handle at the origin, each MeshPart placed at its bbox_centre, Motor6D named after the part at its pivot,
  colour/material/WrapChannel from the manifest, attachments from the manifest (Muzzle keeps the old flash children).

## Melee and gadget notes
- Same rig and files as the guns (`art/anim/guns/<Item>.blend/.fbx`, manifest, Roblox FBX). Melee blade/barrel points along -z
  (Roblox) like a gun muzzle; grenades stand upright in the hand (body centre = grip).
- `visible_at_rest: false` parts (Knife Sheath, Katana Saya) start with Transparency 1; show them for draw / sheath clips.
- Fists: no Handle mesh. RightWrap sits on the right grip point; LeftWrap is the same 3 studs left and, in Blender, follows
  `Hand.L` (Child Of). In Roblox weld each wrap to its arm's grip point (R6: 1 stud below the arm centre, -90 deg about X).
- Neon parts (RiotShield LightLens, Landmine Indicator) are their own mesh so code can switch them on and off.
- Gadgets were plain Parts made in code before (HolsterManager); these are the model replacements at the same sizes.


## Guns

### Pistol
- Size L x H x W: [1.16, 0.79, 0.195] studs; 790 tris; 8 meshes, 6 moving.
- Script check: 8 objects, 790 tris, 0 FAIL, 15 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 8 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.0875, -0.34) | static | 192 | A | 127219226101170 |
| Slide | Handle | (0.0, 0.46, -0.37) | translate +z (back) up to 0.30: blowback, rack, lock open | 312 | A | 78772267867369 |
| Barrel | Handle | (0.0, 0.4375, -0.595) | static | 104 | B | 137908624415585 |
| Mag | Handle | (0.0, 0.215, -0.05) | translate down the grip axis (-y, +0.23 z per stud): drop out / insert | 24 | B | 117025178990291 |
| MagRelease | Handle | (-0.08, 0.17, -0.175) | translate +x 0.03 (pressed in) | 12 | B | 125828175241170 |
| SlideStop | Handle | (-0.08, 0.316, -0.335) | rotate about x, lever tip up 12 deg (slide lock) | 52 | B | 138740655520734 |
| Trigger | Handle | (0.0, 0.255, -0.31) | rotate about x, bottom back 15 deg (pull) | 48 | B | 94370299389768 |
| Round | Mag | (0.0, 0.215, -0.035) | rides in the mag top at rest; animate to ShellEject on fire / show in the hand on reload | 46 | B | 107204104408148 |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -0.945); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Slide at (0.07, 0.51, -0.375); `Mag` on Mag at (0.0, -0.22, 0.05); `SlideGrab` on Slide at (0.0, 0.44, -0.01)

### SilencedPistol
- Size L x H x W: [1.9, 0.905, 0.195] studs; 1258 tris; 9 meshes, 7 moving.
- Script check: 9 objects, 1258 tris, 0 FAIL, 18 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 9 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.1135, -0.365) | static | 204 | A | 105424696629904 |
| Slide | Handle | (0.0, 0.46, -0.4) | translate +z (back) up to 0.30: blowback, rack, lock open | 432 | A | 107779239952173 |
| Barrel | Handle | (0.0, 0.4258, -0.6225) | static | 104 | B | 95287981894716 |
| Suppressor | Barrel | (0.0, 0.46, -1.01) | static (screw on/off: rotate about z, translate -z) | 336 | B | 109447055151622 |
| Mag | Handle | (0.0, 0.221, -0.065) | translate down the grip axis: drop out / insert | 24 | B | 121718675597046 |
| MagRelease | Handle | (-0.08, 0.206, -0.18) | translate +x 0.03 (pressed in) | 12 | B | 106828620432178 |
| SlideStop | Handle | (-0.08, 0.331, -0.355) | rotate about x, lever tip up 12 deg | 52 | B | 96173671318887 |
| Trigger | Handle | (0.0, 0.276, -0.33) | rotate about x, bottom back 15 deg | 48 | B | 86010249801221 |
| Round | Mag | (0.0, 0.221, -0.045) | rides in the mag top; animate to ShellEject | 46 | B | 131976951642861 |

Attachments: `Muzzle` on Suppressor at (0.0, 0.46, -1.68); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Slide at (0.07, 0.536, -0.32); `Mag` on Mag at (0.0, -0.294, 0.06); `SlideGrab` on Slide at (0.0, 0.456, 0.03)

### DualPistols
- Size L x H x W: [1.05, 0.757, 1.277] studs; 2084 tris; 18 meshes, 13 moving.
- Script check: 18 objects, 2084 tris, 0 FAIL, 40 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 18 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.1431, -0.2537) | static | 204 | A | 126747868250938 |
| Slide | Frame | (0.0, 0.4603, -0.315) | translate +z (back) up to 0.28 | 400 | A | 109648080915259 |
| Barrel | Frame | (0.0, 0.442, -0.4288) | static | 104 | B | 95178986734490 |
| Comp | Barrel | (0.0, 0.4493, -0.7656) | static | 132 | B | 136987688408234 |
| Mag | Frame | (0.0, 0.1846, -0.0613) | translate down the grip axis | 24 | B | 71509709177529 |
| MagRelease | Frame | (-0.07, 0.224, -0.1575) | translate +x 0.03 (pressed in) | 12 | B | 127540936491785 |
| SlideStop | Frame | (-0.07, 0.364, -0.3325) | rotate about x, lever tail up 12 deg | 56 | B | 123020168286505 |
| Trigger | Frame | (0.0, 0.3159, -0.28) | rotate about x, bottom back 12 deg | 64 | B | 80559040409334 |
| Round | Mag | (0.0, 0.1846, -0.0525) | rides in the mag top; animate to ShellEject | 46 | B | 113681995238724 |
| LeftFrame | Handle | (-1.1, 0.0, -0.0) | whole left pistol: animate / weld to the left hand (pivot = its grip centre) | 204 | A | 104930746309365 |
| LeftSlide | LeftFrame | (-1.1, 0.4603, -0.315) | translate +z (back) up to 0.28 | 400 | A | 118016878049892 |
| LeftBarrel | LeftFrame | (-1.1, 0.442, -0.4288) | static | 104 | B | 98718354258064 |
| LeftComp | LeftBarrel | (-1.1, 0.4493, -0.7656) | static | 132 | B | 137072923087967 |
| LeftMag | LeftFrame | (-1.1, 0.1846, -0.0613) | translate down the grip axis | 24 | B | 118939856070480 |
| LeftMagRelease | LeftFrame | (-1.17, 0.224, -0.1575) | translate +x 0.03 (pressed in) | 12 | B | 139672894464460 |
| LeftSlideStop | LeftFrame | (-1.17, 0.364, -0.3325) | rotate about x, lever tail up 12 deg | 56 | B | 101699003351737 |
| LeftTrigger | LeftFrame | (-1.1, 0.3159, -0.28) | rotate about x, bottom back 12 deg | 64 | B | 85189807211719 |
| LeftRound | LeftMag | (-1.1, 0.1846, -0.0525) | rides in the mag top; animate to ShellEject | 46 | B | 89180321622115 |

Attachments: `Muzzle` on Comp at (0.0, 0.4603, -0.84); `LeftMuzzle` on LeftComp at (-1.1, 0.4603, -0.84); `Grip` on Handle at (0.0, 0.0, -0.0); `LeftGrip` on LeftFrame at (-1.1, 0.0, -0.0); `ShellEject` on Slide at (0.0613, 0.5346, -0.2713); `LeftShellEject` on LeftSlide at (-1.0387, 0.5346, -0.2713); `Mag` on Mag at (0.0, -0.1741, 0.0437); `LeftMag` on LeftMag at (-1.1, -0.1741, 0.0437)

### Revolver
- Size L x H x W: [1.475, 0.878, 0.28] studs; 1420 tris; 10 meshes, 7 moving.
- Script check: 10 objects, 1420 tris, 0 FAIL, 25 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 10 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.1475, -0.355) | static | 146 | A | 124793181910851 |
| Barrel | Handle | (0.0, 0.4265, -0.9625) | static | 116 | A | 137523643657669 |
| Grip | Handle | (0.0, 0.0125, -0.05) | static | 128 | A | 122969305956644 |
| Crane | Handle | (-0.04, 0.265, -0.68) | rotate about z (the bore axis direction) up to 95 deg: swings the cylinder out to the left | 40 | B | 92403739716786 |
| Cylinder | Crane | (0.0, 0.37, -0.49) | rotate about its own axis (z) 60 deg per shot; spin when swung out | 370 | B | 99528801193432 |
| EjectorRod | Cylinder | (0.0, 0.37, -0.36) | translate +z (back) 0.2: pushes the extractor star and the rounds out | 100 | B | 90460085133578 |
| Rounds | EjectorRod | (0.0, 0.37, -0.47) | group of 6 in the chambers: out with the extractor, new set in (speed loader) | 372 | B | 81276054690769 |
| Hammer | Handle | (0.0, 0.32, -0.18) | rotate about x: cock back 35 deg, fall forward on fire | 40 | B | 81487095739494 |
| Trigger | Handle | (0.0, 0.18, -0.4) | rotate about x, bottom back 20 deg (double action) | 56 | B | 102937569117175 |
| CylinderLatch | Handle | (-0.09, 0.32, -0.245) | translate -z (forward) 0.04 to release the cylinder | 52 | B | 124769507571226 |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -1.315); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Cylinder at (-0.25, 0.37, -0.36); `Mag` on Rounds at (0.0, 0.37, -0.34)

### MiniUzi
- Size L x H x W: [2.08, 1.245, 0.23] studs; 878 tris; 10 meshes, 7 moving.
- Script check: 10 objects, 878 tris, 0 FAIL, 19 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 10 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Receiver | Handle | (0.0, 0.47, -0.18) | static | 192 | A | 135271044873779 |
| LowerFrame | Handle | (0.0, 0.115, -0.14) | static | 100 | A | 117488124601130 |
| Barrel | Handle | (0.0, 0.5179, -0.855) | static | 148 | B | 71202189194908 |
| Mag | Handle | (0.0, 0.31, -0.01) | translate -y (straight down out of the grip) | 24 | B | 124585330965644 |
| CockingKnob | Handle | (0.0, 0.57, -0.23) | translate +z (back) 0.35 along the top slot, snap forward | 64 | B | 87815030542798 |
| Trigger | Handle | (0.0, 0.3, -0.23) | rotate about x, bottom back 15 deg | 36 | B | 105440383952332 |
| Selector | Handle | (-0.1, 0.34, -0.24) | rotate about x 30 deg (safe / semi / auto) | 40 | B | 111653861220990 |
| GripSafety | Handle | (0.0, 0.27, 0.095) | rotate about x, bottom in 8 deg when gripped | 12 | B | 74306002756281 |
| Stock | Handle | (0.0, 0.41, 0.315) | rotate about x ~185 deg to fold under the receiver | 216 | B | 90610743392820 |
| Round | Mag | (0.0, 0.29, 0.02) | rides in the mag top; animate to ShellEject | 46 | B | 132856756911456 |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -1.01); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Receiver at (0.11, 0.43, -0.37); `Mag` on Mag at (0.0, -0.51, -0.01); `StockButt` on Stock at (0.0, 0.32, 1.05)

### AutoRifle
- Size L x H x W: [4.2, 1.72, 0.31] studs; 1708 tris; 19 meshes, 10 moving.
- Script check: 19 objects, 1708 tris, 0 FAIL, 38 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 19 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Upper | Handle | (0.0175, 0.4775, -1.18) | static | 84 | A | 117385245446688 |
| Lower | Handle | (0.0, 0.14, -0.465) | static | 68 | A | 120477386637444 |
| Grip | Handle | (0.0, -0.125, 0.04) | static | 64 | B | 129698243302690 |
| Handguard | Handle | (0.0, 0.45, -1.75) | static | 614 | A | 133762735156602 |
| Barrel | Handle | (0.0, 0.45, -1.95) | static | 140 | B | 108364654159899 |
| BufferTube | Handle | (0.0, 0.425, 0.4) | static | 56 | B | 100038210247680 |
| Stock | Handle | (0.0, 0.425, 0.7) | translate along the buffer tube +z 0.25 (collapse / extend) | 48 | A | 120312203273600 |
| ButtPad | Stock | (0.0, 0.195, 1.25) | static | 12 | B | 93248832620519 |
| Optic | Handle | (0.0152, 0.8, -0.61) | static | 184 | B | 136156624673862 |
| OpticLens | Optic | (0.0, 0.84, -0.77) | static | 36 | skip | 80506467854127 |
| Mag | Handle | (0.0, 0.235, -0.8) | drop out down/forward along its curve; new mag rocked in about x at the well | 44 | B | 103069771903063 |
| ChargingHandle | Handle | (0.0, 0.585, 0.16) | translate +z 0.45 (pull back), release forward | 36 | B | 126044133519712 |
| BoltCarrier | Handle | (0.0, 0.46, -0.4) | translate +z 0.45 per shot (shows through the open port) | 52 | B | 131796782184153 |
| DustCover | Handle | (0.135, 0.345, -0.615) | rotate about z (the barrel axis) 100 deg down: springs open on the first shot / charge | 24 | B | 100489970974455 |
| Trigger | Handle | (0.0, 0.205, -0.35) | rotate about x, bottom back 12 deg | 40 | B | 135468727136592 |
| Selector | Handle | (0.0, 0.255, -0.17) | rotate about x 45/90 deg (safe / semi / auto) | 64 | B | 122247329170281 |
| MagRelease | Handle | (0.13, 0.255, -0.545) | translate -x 0.03 (pressed) | 28 | B | 111421079423934 |
| BoltCatch | Handle | (-0.12, 0.255, -0.9) | rotate about x 10 deg (paddle up locks the bolt back) | 52 | B | 88931704313345 |
| Round | Mag | (0.0, 0.325, -0.8) | rides in the mag top; animate to ShellEject | 62 | B | 93219279928063 |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -2.9); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Upper at (0.16, 0.455, -0.62); `Mag` on Mag at (0.0, -0.715, -0.9); `Handguard` on Handguard at (0.0, 0.315, -1.7); `AimPoint` on Optic at (0.0, 0.84, -0.45)

### SemiAuto
- Size L x H x W: [4.9, 1.48, 0.31] studs; 2566 tris; 22 meshes, 11 moving.
- Script check: 22 objects, 2566 tris, 0 FAIL, 53 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 22 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Upper | Handle | (0.0, 0.51, -1.455) | static | 72 | A | 119822706188319 |
| Lower | Handle | (0.0, 0.215, -0.51) | static | 64 | A | 118558542322941 |
| Grip | Handle | (0.0, 0.015, 0.025) | static | 80 | B | 104911700993309 |
| Handguard | Handle | (0.0, 0.46, -2.085) | static | 992 | A | 121606606068278 |
| Barrel | Handle | (0.0, 0.46, -2.255) | static | 194 | B | 125578904653912 |
| BufferTube | Handle | (0.0, 0.45, 0.41) | static | 56 | B | 77597452872597 |
| Stock | Handle | (0.0, 0.45, 0.72) | translate along the buffer tube +z 0.2 (length of pull) | 70 | A | 74812070752042 |
| ButtPad | Stock | (0.0, 0.175, 1.37) | static | 12 | B | 96929622091791 |
| CheekRiser | Stock | (0.0, 0.55, 0.82) | translate +y 0.1 (adjust) | 68 | A | 96420653957505 |
| Scope | Handle | (0.005, 0.94, -0.74) | static | 380 | B | 85126481165890 |
| ScopeRings | Handle | (0.0, 0.8012, -0.825) | static | 112 | B | 115993810997626 |
| ScopeLensFront | Scope | (0.0, 0.94, -1.63) | static | 44 | skip | 136647731657384 |
| ScopeLensRear | Scope | (0.0, 0.94, 0.16) | static | 44 | skip | 128273680565221 |
| Mag | Handle | (0.0, 0.42, -0.83) | translate -y (straight down), new mag pushed up | 28 | B | 90286005839710 |
| ChargingHandle | Handle | (-0.13, 0.51, -0.48) | rotate the lever out about z 70 deg, translate +z 0.4 (pull), return | 36 | B | 138394485737048 |
| BoltCarrier | Handle | (0.0, 0.46, -0.58) | translate +z 0.45 per shot | 40 | B | 134107539642351 |
| DustCover | Handle | (0.135, 0.41, -0.795) | rotate about z 100 deg down: springs open on the first shot | 24 | B | 74827739334634 |
| Trigger | Handle | (0.0, 0.36, -0.38) | rotate about x, bottom back 10 deg (match trigger) | 44 | B | 95842474990182 |
| Selector | Handle | (0.0, 0.3, -0.21) | rotate about x 90 deg (safe / fire) | 64 | B | 77629277824446 |
| MagRelease | Handle | (0.13, 0.3, -0.66) | translate -x 0.03 (pressed) | 28 | B | 81406313514410 |
| BoltCatch | Handle | (-0.12, 0.32, -0.9) | rotate about x 10 deg | 52 | B | 135794344882796 |
| Round | Mag | (0.0, 0.38, -0.86) | rides in the mag top; animate to ShellEject | 62 | B | 138275379829997 |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -3.48); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Upper at (0.16, 0.45, -0.86); `Mag` on Mag at (0.0, -0.38, -0.83); `Handguard` on Handguard at (0.0, 0.32, -1.98); `AimPoint` on Scope at (0.0, 0.94, 0.18)

### Sniper
- Size L x H x W: [6.2, 1.647, 0.36] studs; 1996 tris; 22 meshes, 11 moving.
- Script check: 22 objects, 1996 tris, 0 FAIL, 25 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 22 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Chassis | Handle | (0.0, 0.19, -1.435) | static | 360 | A | 94117445305183 |
| Stock | Handle | (0.0, 0.07, 0.78) | static | 68 | A | 95556194132474 |
| ButtPad | Handle | (0.0, 0.07, 1.425) | static | 12 | B | 138507043521047 |
| CheekPiece | Stock | (0.0, 0.41, 0.7) | translate +y 0.1 (adjust) | 68 | B | 112192300559074 |
| Grip | Handle | (0.0, -0.145, -0.005) | static | 68 | B | 111898141006954 |
| Receiver | Handle | (0.0, 0.49, -0.96) | static | 88 | A | 83978522441898 |
| Barrel | Handle | (0.0, 0.46, -3.045) | static | 138 | B | 89880050540178 |
| Scope | Handle | (0.0076, 0.8726, -1.23) | static | 380 | B | 97902988534988 |
| ScopeRings | Handle | (0.0, 0.7686, -1.065) | static | 112 | B | 126447011124474 |
| ScopeLensFront | Scope | (0.0, 0.85, -2.505) | static | 44 | skip | 74351465344035 |
| ScopeLensRear | Scope | (0.0, 0.85, 0.05) | static | 44 | skip | 76058495077078 |
| ScopeCapRear | Scope | (0.0, 0.975, 0.08) | rotate about x: open 50 deg up-forward (rest) / closed over the eyepiece (-130 deg) | 72 | B | 97892261979501 |
| ScopeCapFront | Scope | (0.0, 1.0, -2.54) | rotate about x: open 120 deg (rest) / closed over the objective | 72 | B | 124770015300348 |
| Bolt | Handle | (0.0, 0.46, -0.52) | rotate about z 70 deg (lift), translate +z 0.55 (back), reverse | 56 | B | 136607683603605 |
| BoltHandle | Bolt | (0.0, 0.46, -0.52) | rides the bolt (same pivot); lift + pull | 108 | B | 133892630006145 |
| Mag | Handle | (0.0, 0.21, -0.97) | translate -y (straight down) | 24 | B | 117614578363839 |
| MagRelease | Handle | (0.0, 0.11, -0.7) | rotate about x, bottom forward 15 deg (paddle) | 12 | B | 123124100157515 |
| Trigger | Handle | (0.0, 0.17, -0.46) | rotate about x, bottom back 8 deg | 28 | B | 108244069885406 |
| BipodMount | Handle | (0.0, 0.11, -2.6) | static | 12 | B | 108130643530667 |
| BipodLegL | Handle | (-0.028, 0.145, -2.62) | rotate about x 90 deg down (deploy) and splay 15 deg out | 84 | B | 140161907798301 |
| BipodLegR | Handle | (0.028, 0.145, -2.62) | rotate about x 90 deg down (deploy) and splay 15 deg out | 84 | B | 112583716974774 |
| Round | Mag | (0.0, 0.17, -0.97) | rides in the mag top; shown in the port on the bolt cycle | 62 | B | 133129438702722 |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -4.72); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Receiver at (0.12, 0.47, -0.99); `Mag` on Mag at (0.0, -0.26, -0.97); `BoltKnob` on BoltHandle at (0.15, 0.22, -0.5); `AimPoint` on Scope at (0.0, 0.85, 0.08); `ScopeGlare` on Scope at (0.0, 0.85, -2.52)

### PumpShotgun
- Size L x H x W: [3.7, 0.8, 0.307] studs; 1152 tris; 14 meshes, 6 moving.
- Script check: 14 objects, 1152 tris, 0 FAIL, 27 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 14 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Receiver | Handle | (0.0, 0.2525, -0.74) | static | 160 | A | 75754136151381 |
| Stock | Handle | (0.0, 0.04, 0.2) | static | 96 | A | 71706756590775 |
| ButtPad | Stock | (0.0, -0.015, 0.8) | static | 12 | B | 84260305785290 |
| Barrel | Handle | (0.0, 0.254, -1.99) | static | 104 | B | 117130909499387 |
| MagTube | Handle | (0.0, 0.165, -1.93) | static | 64 | B | 81541019617699 |
| Pump | Handle | (0.0, 0.165, -1.88) | translate +z 0.35 (rack back) and return | 308 | A | 104197151642948 |
| Lifter | Handle | (0.0, 0.12, -0.66) | rotate about x: front end up 15 deg to lift a shell to the chamber | 12 | B | 85979066234609 |
| Trigger | Handle | (0.0, 0.14, -0.48) | rotate about x, bottom back 12 deg | 60 | B | 70690026432025 |
| Safety | Handle | (0.0, 0.18, -0.72) | translate x 0.03 (cross-bolt safe / fire) | 28 | B | 83545871615256 |
| SideSaddle | Handle | (-0.125, 0.2475, -0.5) | static | 12 | B | 90991529874602 |
| SaddleShells | SideSaddle | (-0.14, 0.2625, -0.5) | static (hand pulls one for a reload) | 112 | B | 119837291079443 |
| SaddleHeads | SideSaddle | (-0.14, 0.1625, -0.5) | static | 112 | B | 80074792654179 |
| LoadShell | Handle | (0.0, 0.16, -0.99) | the shell the hand carries: rest on the lifter in the loading port; animate from the saddle into the loading port | 44 | B | 92869047172461 |
| LoadShellHead | LoadShell | (0.0, 0.16, -0.8525) | static | 28 | B | 74984813149007 |

Attachments: `Muzzle` on Barrel at (0.0, 0.305, -2.84); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Receiver at (0.13, 0.3, -0.92); `Mag` on Receiver at (0.0, 0.1, -0.88); `Pump` on Pump at (0.0, 0.06, -1.88)

## Melee

### Knife
- Size L x H x W: [1.95, 0.25, 0.16] studs; 218 tris; 5 meshes, 1 moving.
- Script check: 5 objects, 218 tris, 0 FAIL, 7 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 5 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Grip | Handle | (0.0, -0.0075, 0.02) | static | 118 | A | 137679589885785 |
| Blade | Handle | (0.0, -0.02, -0.845) | static | 48 | A | 111824052179505 |
| Guard | Handle | (0.0, -0.02, -0.4175) | static | 12 | B | 78593531517149 |
| Pommel | Handle | (0.0, 0.0, 0.46) | static | 12 | B | 120447759922088 |
| Sheath | Handle | (0.0, 0.0, -0.42) | hidden at rest; for draw / holster: slides off along +z (-f) from the blade | 28 | B | 120645036920227 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `Tip` on Blade at (0.0, 0.0, -1.37); `EdgeMid` on Blade at (0.0, -0.1, -0.87); `Lanyard` on Grip at (0.0, 0.0, 0.36)

### Katana
- Size L x H x W: [4.08, 0.365, 0.309] studs; 580 tris; 7 meshes, 1 moving.
- Script check: 7 objects, 580 tris, 0 FAIL, 16 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 7 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Tsuka | Handle | (0.0, 0.0, -0.065) | static | 12 | B | 89647319080878 |
| Wrap | Handle | (0.0, 0.0, -0.0725) | static | 264 | A | 96989652673049 |
| Kashira | Handle | (0.0, 0.0, 0.445) | static | 12 | B | 122054948463173 |
| Tsuba | Handle | (0.0, 0.0, -0.545) | static | 44 | B | 132876601609667 |
| Habaki | Handle | (0.0, -0.0025, -0.615) | static | 12 | B | 115518144667897 |
| Blade | Handle | (0.0, 0.0552, -1.8) | static | 156 | A | 105849292075703 |
| Saya | Handle | (0.0, 0.0, -0.55) | hidden at rest; for draw / sheath: slides along the blade curve (translate -z, follow the sori) | 80 | B | 108835780085004 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `Tip` on Blade at (0.0, 0.13, -3.55); `EdgeMid` on Blade at (0.0, -0.0252, -2.05); `Trail0` on Blade at (0.0, 0.0, -0.75); `Trail1` on Blade at (0.0, 0.13, -3.45)

### Bat
- Size L x H x W: [2.9, 0.258, 0.258] studs; 336 tris; 3 meshes, 0 moving.
- Script check: 3 objects, 336 tris, 0 FAIL, 1 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 3 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Bat | Handle | (0.0, 0.0, -0.9) | static | 240 | A | 119296360920517 |
| GripTape | Handle | (0.0, 0.0, -0.065) | static | 48 | B | 98151046054872 |
| Band | Handle | (0.0, 0.0, -1.685) | static | 48 | B | 88580720857117 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `Tip` on Bat at (0.0, 0.0, -2.35); `SweetSpot` on Bat at (0.0, 0.0, -1.9); `Trail0` on Bat at (0.0, 0.0, -0.95)

### RiotShield
- Size L x H x W: [0.748, 3.727, 2.327] studs; 692 tris; 6 meshes, 0 moving.
- Script check: 6 objects, 692 tris, 0 FAIL, 6 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 6 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Shield | Handle | (0.0, -0.1, -0.435) | static | 184 | A | 113628790910041 |
| Rim | Handle | (0.0, -0.1, -0.4334) | static | 320 | B | 90803774702893 |
| Window | Handle | (0.0, 1.275, -0.4813) | static | 68 | skip | 91292931001213 |
| Grip | Handle | (0.0, 0.0, -0.22) | static | 52 | B | 103820350344812 |
| Light | Handle | (0.93, 1.4854, -0.5378) | static | 40 | B | 125800445133273 |
| LightLens | Light | (0.93, 1.5, -0.6853) | static | 28 | skip | 85076532967844 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `Bash` on Shield at (0.0, 0.0, -0.55); `LightBeam` on LightLens at (0.93, 1.5, -0.7028)

### Fists
- Size L x H x W: [0.59, 1.145, 4.11] studs; 600 tris; 4 meshes, 1 moving.
- Script check: 4 objects, 600 tris, 0 FAIL, 4 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 4 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| RightWrap | Handle | (0.0, 0.0, 0.26) | static | 276 | A | 101865705339989 |
| RightPad | RightWrap | (0.0, 0.0175, 0.28) | static | 24 | B | 123724094830409 |
| LeftWrap | Handle | (-3.0, 0.0, -0.0) | follows the left hand (weld to the left arm's grip point) | 276 | A | 72741555659813 |
| LeftPad | LeftWrap | (-3.0, 0.0175, 0.28) | static | 24 | B | 139383211054396 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `RightKnuckles` on RightPad at (0.0, 0.6, 0.15); `LeftKnuckles` on LeftPad at (-3.0, 0.6, 0.15)

## Gadgets

### Frag
- Size L x H x W: [0.326, 0.51, 0.296] studs; 542 tris; 5 meshes, 2 moving.
- Script check: 5 objects, 542 tris, 0 FAIL, 6 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 5 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Body | Handle | (0.0, -0.025, -0.0) | static | 166 | A | 105108742050719 |
| Band | Handle | (0.0, -0.02, -0.0) | static | 44 | B | 137147661828196 |
| Fuze | Handle | (0.0, 0.215, -0.0075) | static | 72 | B | 101588107296408 |
| Spoon | Handle | (0.0, 0.27, -0.05) | rotate about x away from the body (flies off when released) | 44 | B | 87591480856309 |
| Pin | Handle | (0.0, 0.23, -0.0) | translate -z (pull back along the shaft), ring swings about x | 216 | B | 96110446397046 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `PinRing` on Pin at (0.0, 0.17, 0.155); `Throw` on Body at (0.0, 0.0, -0.0)

### Smoke
- Size L x H x W: [0.326, 0.67, 0.278] studs; 696 tris; 5 meshes, 2 moving.
- Script check: 5 objects, 696 tris, 0 FAIL, 6 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 5 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Body | Handle | (0.0, -0.085, -0.0) | static | 336 | A | 136785365417305 |
| Band | Handle | (0.0, -0.08, -0.0) | static | 44 | B | 100057634855706 |
| Fuze | Handle | (0.0, 0.235, -0.0075) | static | 72 | B | 83275385782842 |
| Spoon | Handle | (0.0, 0.29, -0.05) | rotate about x away from the body (flies off when released) | 28 | B | 139929232520555 |
| Pin | Handle | (0.0, 0.25, -0.0) | translate -z (pull back along the shaft), ring swings about x | 216 | B | 138214283851657 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `PinRing` on Pin at (0.0, 0.19, 0.165); `SmokeTop` on Body at (0.0, 0.13, -0.0); `SmokeBottom` on Body at (0.0, -0.3, -0.0)

### Flash
- Size L x H x W: [0.286, 0.7, 0.24] studs; 652 tris; 5 meshes, 2 moving.
- Script check: 5 objects, 652 tris, 0 FAIL, 7 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 5 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Body | Handle | (0.0, -0.08, -0.0) | static | 288 | A | 106339266881933 |
| Band | Handle | (0.0, -0.35, -0.0) | static | 48 | B | 76662467775618 |
| Fuze | Handle | (0.0, 0.255, -0.0075) | static | 72 | B | 92299871337919 |
| Spoon | Handle | (0.0, 0.31, -0.05) | rotate about x away from the body (flies off when released) | 28 | B | 130717629009388 |
| Pin | Handle | (0.0, 0.27, -0.0) | translate -z (pull back along the shaft), ring swings about x | 216 | B | 128456587691794 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `PinRing` on Pin at (0.0, 0.21, 0.145); `Flash` on Body at (0.0, 0.0, -0.0)

### StickyGrenade
- Size L x H x W: [0.443, 0.51, 0.406] studs; 560 tris; 6 meshes, 3 moving.
- Script check: 6 objects, 560 tris, 0 FAIL, 10 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 6 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Body | Handle | (0.0, 0.0, -0.0) | static | 168 | A | 99559481718916 |
| Band | Handle | (0.0, -0.07, -0.0) | static | 44 | B | 74420429858316 |
| Backing | Handle | (0.0, 0.03, -0.22) | rotate about x, peel down and off before the throw | 24 | B | 100085235081284 |
| Fuze | Handle | (0.0, 0.235, -0.0075) | static | 72 | B | 82754032788024 |
| Spoon | Handle | (0.0, 0.29, -0.05) | rotate about x away from the body (flies off when released) | 36 | B | 137520699000629 |
| Pin | Handle | (0.0, 0.25, -0.0) | translate -z (pull back along the shaft), ring swings about x | 216 | B | 79591832687318 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `PinRing` on Pin at (0.0, 0.25, 0.2); `StickFace` on Body at (0.0, 0.0, -0.21)

### Landmine
- Size L x H x W: [0.891, 0.18, 0.588] studs; 400 tris; 5 meshes, 3 moving.
- Script check: 5 objects, 400 tris, 0 FAIL, 3 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 5 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Body | Handle | (0.0, -0.01, -0.0) | static | 96 | A | 82426118174988 |
| Plate | Handle | (0.0, 0.1, -0.0) | translate -y 0.025 when stepped on | 48 | B | 109247218022939 |
| ArmSwitch | Handle | (0.0, 0.0, -0.3) | rotate about z (its own axis) 90 deg: safe / armed | 40 | B | 126508432385294 |
| SafetyPin | Handle | (0.0, 0.0, 0.3) | translate +z (pull out backward) to arm | 188 | B | 138474216093991 |
| Indicator | Handle | (0.198, 0.0525, 0.198) | static | 28 | skip | 88012123016104 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `Trigger` on Plate at (0.0, 0.1, -0.0); `Blast` on Body at (0.0, 0.0, -0.0)

### Medkit
- Size L x H x W: [0.52, 0.475, 0.27] studs; 248 tris; 9 meshes, 7 moving.
- Script check: 9 objects, 248 tris, 0 FAIL, 14 WARN.
- Grade: pending (HQ grader).
- Mesh ids: uploaded 2026-10-30 (Import 3D, Creator gunsy funsy, group 102028987, ownership checked on economy API); 9 meshes.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Body | Handle | (0.0, -0.28, -0.0) | static | 40 | A | 72433472575071 |
| Lid | Handle | (-0.12, -0.105, -0.0) | rotate about z (the case length) 110 deg up-back on its rear hinge | 12 | A | 78883312302130 |
| Cross | Body | (0.12, -0.315, -0.0) | static | 44 | B | 123854199118956 |
| Handle | Lid | (0.0, -0.095, -0.0) | rotate about x 90 deg to fold flat on the lid | 28 | B | 111354513516794 |
| LatchL | Body | (0.13, -0.165, 0.215) | rotate about z 120 deg outward-down to unlatch | 12 | B | 127051280880731 |
| LatchR | Body | (0.13, -0.165, -0.215) | rotate about z 120 deg outward-down to unlatch | 12 | B | 84587605521508 |
| Injector | Body | (-0.05, -0.355, 0.08) | the hand takes it out: free move; stab = translate along -z | 32 | B | 95579931490607 |
| InjectorCap | Injector | (-0.05, -0.355, -0.09) | pull off along -z before use | 32 | B | 82521893511702 |
| Bandage | Body | (0.0, -0.345, -0.0) | the hand takes it out; unroll = rotate about x | 36 | B | 117280858561724 |

Attachments: `Grip` on Handle at (0.0, 0.0, -0.0); `LidOpen` on Lid at (0.12, -0.085, -0.0); `InjectorTip` on Injector at (-0.05, -0.355, 0.23)
