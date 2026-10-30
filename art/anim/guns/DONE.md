# Guns: remodel status (modeler)

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

## Studio import / upload (not done yet)
- Meshes are **not uploaded yet**: Creator Hub only takes images/audio/video, and AssetService:CreateAssetAsync answers
  "not available yet" in Studio (tested 2026-10-30). Upload = Studio Import 3D of `art/guns/fbx/<Gun>_roblox.fbx`
  (Creator = gunsy funsy, Insert Using Scene Position), which needs a session with computer use (clicks in the dialog).
- After import: measure ScaleCube (B1), check Marker orientation (B2), delete both, then build the Tool from the manifest:
  invisible Handle at the origin, each MeshPart placed at its bbox_centre, Motor6D named after the part at its pivot,
  colour/material/WrapChannel from the manifest, attachments from the manifest (Muzzle keeps the old flash children).

## Guns

### Pistol
- Size L x H x W: [1.16, 0.79, 0.195] studs; 790 tris; 8 meshes, 6 moving.
- Script check: 8 objects, 790 tris, 0 FAIL, 15 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.0875, -0.34) | static | 192 | A |  |
| Slide | Handle | (0.0, 0.46, -0.37) | translate +z (back) up to 0.30: blowback, rack, lock open | 312 | A |  |
| Barrel | Handle | (0.0, 0.4375, -0.595) | static | 104 | B |  |
| Mag | Handle | (0.0, 0.215, -0.05) | translate down the grip axis (-y, +0.23 z per stud): drop out / insert | 24 | B |  |
| MagRelease | Handle | (-0.08, 0.17, -0.175) | translate +x 0.03 (pressed in) | 12 | B |  |
| SlideStop | Handle | (-0.08, 0.316, -0.335) | rotate about x, lever tip up 12 deg (slide lock) | 52 | B |  |
| Trigger | Handle | (0.0, 0.255, -0.31) | rotate about x, bottom back 15 deg (pull) | 48 | B |  |
| Round | Mag | (0.0, 0.215, -0.035) | rides in the mag top at rest; animate to ShellEject on fire / show in the hand on reload | 46 | B |  |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -0.945); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Slide at (0.07, 0.51, -0.375); `Mag` on Mag at (0.0, -0.22, 0.05); `SlideGrab` on Slide at (0.0, 0.44, -0.01)

### SilencedPistol
- Size L x H x W: [1.9, 0.905, 0.195] studs; 1258 tris; 9 meshes, 7 moving.
- Script check: 9 objects, 1258 tris, 0 FAIL, 18 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.1135, -0.365) | static | 204 | A |  |
| Slide | Handle | (0.0, 0.46, -0.4) | translate +z (back) up to 0.30: blowback, rack, lock open | 432 | A |  |
| Barrel | Handle | (0.0, 0.4258, -0.6225) | static | 104 | B |  |
| Suppressor | Barrel | (0.0, 0.46, -1.01) | static (screw on/off: rotate about z, translate -z) | 336 | B |  |
| Mag | Handle | (0.0, 0.221, -0.065) | translate down the grip axis: drop out / insert | 24 | B |  |
| MagRelease | Handle | (-0.08, 0.206, -0.18) | translate +x 0.03 (pressed in) | 12 | B |  |
| SlideStop | Handle | (-0.08, 0.331, -0.355) | rotate about x, lever tip up 12 deg | 52 | B |  |
| Trigger | Handle | (0.0, 0.276, -0.33) | rotate about x, bottom back 15 deg | 48 | B |  |
| Round | Mag | (0.0, 0.221, -0.045) | rides in the mag top; animate to ShellEject | 46 | B |  |

Attachments: `Muzzle` on Suppressor at (0.0, 0.46, -1.68); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Slide at (0.07, 0.536, -0.32); `Mag` on Mag at (0.0, -0.294, 0.06); `SlideGrab` on Slide at (0.0, 0.456, 0.03)

### DualPistols
- Size L x H x W: [1.05, 0.757, 1.277] studs; 2084 tris; 18 meshes, 13 moving.
- Script check: 18 objects, 2084 tris, 0 FAIL, 40 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.1431, -0.2537) | static | 204 | A |  |
| Slide | Frame | (0.0, 0.4603, -0.315) | translate +z (back) up to 0.28 | 400 | A |  |
| Barrel | Frame | (0.0, 0.442, -0.4288) | static | 104 | B |  |
| Comp | Barrel | (0.0, 0.4493, -0.7656) | static | 132 | B |  |
| Mag | Frame | (0.0, 0.1846, -0.0613) | translate down the grip axis | 24 | B |  |
| MagRelease | Frame | (-0.07, 0.224, -0.1575) | translate +x 0.03 (pressed in) | 12 | B |  |
| SlideStop | Frame | (-0.07, 0.364, -0.3325) | rotate about x, lever tail up 12 deg | 56 | B |  |
| Trigger | Frame | (0.0, 0.3159, -0.28) | rotate about x, bottom back 12 deg | 64 | B |  |
| Round | Mag | (0.0, 0.1846, -0.0525) | rides in the mag top; animate to ShellEject | 46 | B |  |
| LeftFrame | Handle | (-1.1, 0.0, -0.0) | whole left pistol: animate / weld to the left hand (pivot = its grip centre) | 204 | A |  |
| LeftSlide | LeftFrame | (-1.1, 0.4603, -0.315) | translate +z (back) up to 0.28 | 400 | A |  |
| LeftBarrel | LeftFrame | (-1.1, 0.442, -0.4288) | static | 104 | B |  |
| LeftComp | LeftBarrel | (-1.1, 0.4493, -0.7656) | static | 132 | B |  |
| LeftMag | LeftFrame | (-1.1, 0.1846, -0.0613) | translate down the grip axis | 24 | B |  |
| LeftMagRelease | LeftFrame | (-1.17, 0.224, -0.1575) | translate +x 0.03 (pressed in) | 12 | B |  |
| LeftSlideStop | LeftFrame | (-1.17, 0.364, -0.3325) | rotate about x, lever tail up 12 deg | 56 | B |  |
| LeftTrigger | LeftFrame | (-1.1, 0.3159, -0.28) | rotate about x, bottom back 12 deg | 64 | B |  |
| LeftRound | LeftMag | (-1.1, 0.1846, -0.0525) | rides in the mag top; animate to ShellEject | 46 | B |  |

Attachments: `Muzzle` on Comp at (0.0, 0.4603, -0.84); `LeftMuzzle` on LeftComp at (-1.1, 0.4603, -0.84); `Grip` on Handle at (0.0, 0.0, -0.0); `LeftGrip` on LeftFrame at (-1.1, 0.0, -0.0); `ShellEject` on Slide at (0.0613, 0.5346, -0.2713); `LeftShellEject` on LeftSlide at (-1.0387, 0.5346, -0.2713); `Mag` on Mag at (0.0, -0.1741, 0.0437); `LeftMag` on LeftMag at (-1.1, -0.1741, 0.0437)

### Revolver
- Size L x H x W: [1.475, 0.878, 0.28] studs; 1420 tris; 10 meshes, 7 moving.
- Script check: 10 objects, 1420 tris, 0 FAIL, 25 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Frame | Handle | (0.0, 0.1475, -0.355) | static | 146 | A |  |
| Barrel | Handle | (0.0, 0.4265, -0.9625) | static | 116 | A |  |
| Grip | Handle | (0.0, 0.0125, -0.05) | static | 128 | A |  |
| Crane | Handle | (-0.04, 0.265, -0.68) | rotate about z (the bore axis direction) up to 95 deg: swings the cylinder out to the left | 40 | B |  |
| Cylinder | Crane | (0.0, 0.37, -0.49) | rotate about its own axis (z) 60 deg per shot; spin when swung out | 370 | B |  |
| EjectorRod | Cylinder | (0.0, 0.37, -0.36) | translate +z (back) 0.2: pushes the extractor star and the rounds out | 100 | B |  |
| Rounds | EjectorRod | (0.0, 0.37, -0.47) | group of 6 in the chambers: out with the extractor, new set in (speed loader) | 372 | B |  |
| Hammer | Handle | (0.0, 0.32, -0.18) | rotate about x: cock back 35 deg, fall forward on fire | 40 | B |  |
| Trigger | Handle | (0.0, 0.18, -0.4) | rotate about x, bottom back 20 deg (double action) | 56 | B |  |
| CylinderLatch | Handle | (-0.09, 0.32, -0.245) | translate -z (forward) 0.04 to release the cylinder | 52 | B |  |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -1.315); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Cylinder at (-0.25, 0.37, -0.36); `Mag` on Rounds at (0.0, 0.37, -0.34)

### MiniUzi
- Size L x H x W: [2.08, 1.245, 0.23] studs; 878 tris; 10 meshes, 7 moving.
- Script check: 10 objects, 878 tris, 0 FAIL, 19 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Receiver | Handle | (0.0, 0.47, -0.18) | static | 192 | A |  |
| LowerFrame | Handle | (0.0, 0.115, -0.14) | static | 100 | A |  |
| Barrel | Handle | (0.0, 0.5179, -0.855) | static | 148 | B |  |
| Mag | Handle | (0.0, 0.31, -0.01) | translate -y (straight down out of the grip) | 24 | B |  |
| CockingKnob | Handle | (0.0, 0.57, -0.23) | translate +z (back) 0.35 along the top slot, snap forward | 64 | B |  |
| Trigger | Handle | (0.0, 0.3, -0.23) | rotate about x, bottom back 15 deg | 36 | B |  |
| Selector | Handle | (-0.1, 0.34, -0.24) | rotate about x 30 deg (safe / semi / auto) | 40 | B |  |
| GripSafety | Handle | (0.0, 0.27, 0.095) | rotate about x, bottom in 8 deg when gripped | 12 | B |  |
| Stock | Handle | (0.0, 0.41, 0.315) | rotate about x ~185 deg to fold under the receiver | 216 | B |  |
| Round | Mag | (0.0, 0.29, 0.02) | rides in the mag top; animate to ShellEject | 46 | B |  |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -1.01); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Receiver at (0.11, 0.43, -0.37); `Mag` on Mag at (0.0, -0.51, -0.01); `StockButt` on Stock at (0.0, 0.32, 1.05)

### AutoRifle
- Size L x H x W: [4.2, 1.72, 0.31] studs; 1708 tris; 19 meshes, 10 moving.
- Script check: 19 objects, 1708 tris, 0 FAIL, 38 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Upper | Handle | (0.0175, 0.4775, -1.18) | static | 84 | A |  |
| Lower | Handle | (0.0, 0.14, -0.465) | static | 68 | A |  |
| Grip | Handle | (0.0, -0.125, 0.04) | static | 64 | B |  |
| Handguard | Handle | (0.0, 0.45, -1.75) | static | 614 | A |  |
| Barrel | Handle | (0.0, 0.45, -1.95) | static | 140 | B |  |
| BufferTube | Handle | (0.0, 0.425, 0.4) | static | 56 | B |  |
| Stock | Handle | (0.0, 0.425, 0.7) | translate along the buffer tube +z 0.25 (collapse / extend) | 48 | A |  |
| ButtPad | Stock | (0.0, 0.195, 1.25) | static | 12 | B |  |
| Optic | Handle | (0.0152, 0.8, -0.61) | static | 184 | B |  |
| OpticLens | Optic | (0.0, 0.84, -0.77) | static | 36 | skip |  |
| Mag | Handle | (0.0, 0.235, -0.8) | drop out down/forward along its curve; new mag rocked in about x at the well | 44 | B |  |
| ChargingHandle | Handle | (0.0, 0.585, 0.16) | translate +z 0.45 (pull back), release forward | 36 | B |  |
| BoltCarrier | Handle | (0.0, 0.46, -0.4) | translate +z 0.45 per shot (shows through the open port) | 52 | B |  |
| DustCover | Handle | (0.135, 0.345, -0.615) | rotate about z (the barrel axis) 100 deg down: springs open on the first shot / charge | 24 | B |  |
| Trigger | Handle | (0.0, 0.205, -0.35) | rotate about x, bottom back 12 deg | 40 | B |  |
| Selector | Handle | (0.0, 0.255, -0.17) | rotate about x 45/90 deg (safe / semi / auto) | 64 | B |  |
| MagRelease | Handle | (0.13, 0.255, -0.545) | translate -x 0.03 (pressed) | 28 | B |  |
| BoltCatch | Handle | (-0.12, 0.255, -0.9) | rotate about x 10 deg (paddle up locks the bolt back) | 52 | B |  |
| Round | Mag | (0.0, 0.325, -0.8) | rides in the mag top; animate to ShellEject | 62 | B |  |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -2.9); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Upper at (0.16, 0.455, -0.62); `Mag` on Mag at (0.0, -0.715, -0.9); `Handguard` on Handguard at (0.0, 0.315, -1.7); `AimPoint` on Optic at (0.0, 0.84, -0.45)

### SemiAuto
- Size L x H x W: [4.9, 1.48, 0.31] studs; 2566 tris; 22 meshes, 11 moving.
- Script check: 22 objects, 2566 tris, 0 FAIL, 53 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Upper | Handle | (0.0, 0.51, -1.455) | static | 72 | A |  |
| Lower | Handle | (0.0, 0.215, -0.51) | static | 64 | A |  |
| Grip | Handle | (0.0, 0.015, 0.025) | static | 80 | B |  |
| Handguard | Handle | (0.0, 0.46, -2.085) | static | 992 | A |  |
| Barrel | Handle | (0.0, 0.46, -2.255) | static | 194 | B |  |
| BufferTube | Handle | (0.0, 0.45, 0.41) | static | 56 | B |  |
| Stock | Handle | (0.0, 0.45, 0.72) | translate along the buffer tube +z 0.2 (length of pull) | 70 | A |  |
| ButtPad | Stock | (0.0, 0.175, 1.37) | static | 12 | B |  |
| CheekRiser | Stock | (0.0, 0.55, 0.82) | translate +y 0.1 (adjust) | 68 | A |  |
| Scope | Handle | (0.005, 0.94, -0.74) | static | 380 | B |  |
| ScopeRings | Handle | (0.0, 0.8012, -0.825) | static | 112 | B |  |
| ScopeLensFront | Scope | (0.0, 0.94, -1.63) | static | 44 | skip |  |
| ScopeLensRear | Scope | (0.0, 0.94, 0.16) | static | 44 | skip |  |
| Mag | Handle | (0.0, 0.42, -0.83) | translate -y (straight down), new mag pushed up | 28 | B |  |
| ChargingHandle | Handle | (-0.13, 0.51, -0.48) | rotate the lever out about z 70 deg, translate +z 0.4 (pull), return | 36 | B |  |
| BoltCarrier | Handle | (0.0, 0.46, -0.58) | translate +z 0.45 per shot | 40 | B |  |
| DustCover | Handle | (0.135, 0.41, -0.795) | rotate about z 100 deg down: springs open on the first shot | 24 | B |  |
| Trigger | Handle | (0.0, 0.36, -0.38) | rotate about x, bottom back 10 deg (match trigger) | 44 | B |  |
| Selector | Handle | (0.0, 0.3, -0.21) | rotate about x 90 deg (safe / fire) | 64 | B |  |
| MagRelease | Handle | (0.13, 0.3, -0.66) | translate -x 0.03 (pressed) | 28 | B |  |
| BoltCatch | Handle | (-0.12, 0.32, -0.9) | rotate about x 10 deg | 52 | B |  |
| Round | Mag | (0.0, 0.38, -0.86) | rides in the mag top; animate to ShellEject | 62 | B |  |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -3.48); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Upper at (0.16, 0.45, -0.86); `Mag` on Mag at (0.0, -0.38, -0.83); `Handguard` on Handguard at (0.0, 0.32, -1.98); `AimPoint` on Scope at (0.0, 0.94, 0.18)

### Sniper
- Size L x H x W: [6.2, 1.647, 0.36] studs; 1996 tris; 22 meshes, 11 moving.
- Script check: 22 objects, 1996 tris, 0 FAIL, 25 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Chassis | Handle | (0.0, 0.19, -1.435) | static | 360 | A |  |
| Stock | Handle | (0.0, 0.07, 0.78) | static | 68 | A |  |
| ButtPad | Handle | (0.0, 0.07, 1.425) | static | 12 | B |  |
| CheekPiece | Stock | (0.0, 0.41, 0.7) | translate +y 0.1 (adjust) | 68 | B |  |
| Grip | Handle | (0.0, -0.145, -0.005) | static | 68 | B |  |
| Receiver | Handle | (0.0, 0.49, -0.96) | static | 88 | A |  |
| Barrel | Handle | (0.0, 0.46, -3.045) | static | 138 | B |  |
| Scope | Handle | (0.0076, 0.8726, -1.23) | static | 380 | B |  |
| ScopeRings | Handle | (0.0, 0.7686, -1.065) | static | 112 | B |  |
| ScopeLensFront | Scope | (0.0, 0.85, -2.505) | static | 44 | skip |  |
| ScopeLensRear | Scope | (0.0, 0.85, 0.05) | static | 44 | skip |  |
| ScopeCapRear | Scope | (0.0, 0.975, 0.08) | rotate about x: open 50 deg up-forward (rest) / closed over the eyepiece (-130 deg) | 72 | B |  |
| ScopeCapFront | Scope | (0.0, 1.0, -2.54) | rotate about x: open 120 deg (rest) / closed over the objective | 72 | B |  |
| Bolt | Handle | (0.0, 0.46, -0.52) | rotate about z 70 deg (lift), translate +z 0.55 (back), reverse | 56 | B |  |
| BoltHandle | Bolt | (0.0, 0.46, -0.52) | rides the bolt (same pivot); lift + pull | 108 | B |  |
| Mag | Handle | (0.0, 0.21, -0.97) | translate -y (straight down) | 24 | B |  |
| MagRelease | Handle | (0.0, 0.11, -0.7) | rotate about x, bottom forward 15 deg (paddle) | 12 | B |  |
| Trigger | Handle | (0.0, 0.17, -0.46) | rotate about x, bottom back 8 deg | 28 | B |  |
| BipodMount | Handle | (0.0, 0.11, -2.6) | static | 12 | B |  |
| BipodLegL | Handle | (-0.028, 0.145, -2.62) | rotate about x 90 deg down (deploy) and splay 15 deg out | 84 | B |  |
| BipodLegR | Handle | (0.028, 0.145, -2.62) | rotate about x 90 deg down (deploy) and splay 15 deg out | 84 | B |  |
| Round | Mag | (0.0, 0.17, -0.97) | rides in the mag top; shown in the port on the bolt cycle | 62 | B |  |

Attachments: `Muzzle` on Barrel at (0.0, 0.46, -4.72); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Receiver at (0.12, 0.47, -0.99); `Mag` on Mag at (0.0, -0.26, -0.97); `BoltKnob` on BoltHandle at (0.15, 0.22, -0.5); `AimPoint` on Scope at (0.0, 0.85, 0.08); `ScopeGlare` on Scope at (0.0, 0.85, -2.52)

### PumpShotgun
- Size L x H x W: [3.7, 0.8, 0.307] studs; 1152 tris; 14 meshes, 6 moving.
- Script check: 14 objects, 1152 tris, 0 FAIL, 27 WARN.
- Grade: pending (HQ grader).
- Mesh ids: pending upload.

| Part | Parent (Motor6D Part0) | Pivot (x, y, z) | Motion | Tris | Wrap | Mesh id |
|---|---|---|---|---|---|---|
| Receiver | Handle | (0.0, 0.2525, -0.74) | static | 160 | A |  |
| Stock | Handle | (0.0, 0.04, 0.2) | static | 96 | A |  |
| ButtPad | Stock | (0.0, -0.015, 0.8) | static | 12 | B |  |
| Barrel | Handle | (0.0, 0.254, -1.99) | static | 104 | B |  |
| MagTube | Handle | (0.0, 0.165, -1.93) | static | 64 | B |  |
| Pump | Handle | (0.0, 0.165, -1.88) | translate +z 0.35 (rack back) and return | 308 | A |  |
| Lifter | Handle | (0.0, 0.12, -0.66) | rotate about x: front end up 15 deg to lift a shell to the chamber | 12 | B |  |
| Trigger | Handle | (0.0, 0.14, -0.48) | rotate about x, bottom back 12 deg | 60 | B |  |
| Safety | Handle | (0.0, 0.18, -0.72) | translate x 0.03 (cross-bolt safe / fire) | 28 | B |  |
| SideSaddle | Handle | (-0.125, 0.2475, -0.5) | static | 12 | B |  |
| SaddleShells | SideSaddle | (-0.14, 0.2625, -0.5) | static (hand pulls one for a reload) | 112 | B |  |
| SaddleHeads | SideSaddle | (-0.14, 0.1625, -0.5) | static | 112 | B |  |
| LoadShell | Handle | (0.0, 0.16, -0.99) | the shell the hand carries: rest on the lifter in the loading port; animate from the saddle into the loading port | 44 | B |  |
| LoadShellHead | LoadShell | (0.0, 0.16, -0.8525) | static | 28 | B |  |

Attachments: `Muzzle` on Barrel at (0.0, 0.305, -2.84); `Grip` on Handle at (0.0, 0.0, -0.0); `ShellEject` on Receiver at (0.13, 0.3, -0.92); `Mag` on Receiver at (0.0, 0.1, -0.88); `Pump` on Pump at (0.0, 0.06, -1.88)
