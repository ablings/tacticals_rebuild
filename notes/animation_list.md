# Tacticals animation list (for finishing in Blender)

Read from match_place_ref.rbxl, 2026-10-16. Every source lives in `ReplicatedStorage.Repository.AnimationSources`; all 54 are
**placeholders** (2 to 17 keyframes, no markers). Rig: **R15**. Keep the exact names: the scripts find animations by name.

## Rules when you redo one
- **Keep the name, the length and Loop.** Length matters most for one-shots: the scripts time things off the config, not the
  animation (e.g. the Pistol reload must finish in **1.5 s**, the Revolver in **2.4 s**).
- **`...Left` = the same move mirrored** for players who set Gun Hand = Left. Make the right version first; I can mirror it.
- **Arms/torso aim is procedural.** AimPoseController bends Waist, shoulders and Neck for aim pitch on top of your animation, and
  HeadLookController owns the neck. Animate at **level aim**, and keep the neck light.
- Loop / priority below are what the game sets now; tell me if you want one changed.

## 0. FINAL weapon / melee / gadget set (weapons animator, 2026-10-30)
Authored in Blender on Edward's Starter Blocky rig (R15 pivots), gun parts keyed on the remodelled guns. **140 clips**
(right-hand + `...Left` mirrors) in `ReplicatedStorage.Repository.AnimationSources` via `art/anim/weapons/install_sources.lua`.
Per clip (length, loop, markers, published id): `art/anim/weapons/DONE.md`; wiring for systems at its end.
- Prefix sets (Hold, Lowered, Equip, Fire, Reload, ReloadEmpty, Draw, Holster, Inspect, +Left): `Pistol`, `Revolver`
  (no ReloadEmpty), `SMG`, `Rifle`, `Shotgun` (ReloadStart / ReloadShell / ReloadEnd / ReloadEndEmpty instead of
  Reload), `Sniper` (ReloadTactical instead of ReloadEmpty).
- Melee: QuickMeleeBash (gun-butt), MeleeSlash, MeleePunch, MeleeKnifeHeavy, MeleeKnifeBackstab; Bat (Hold, Equip, Swing,
  ChargeWindup, ChargeHold, SwingCharged), Katana (Hold, Equip, Slash), RiotShield (Hold, Bash, Impact, Break).
- Gadgets: SmokeHold, SmokeThrow (+L), SmokeRoll, FragPinPull, FragCook, FragThrow (+L), FlashThrow (+L), LandminePlace,
  MedkitUse.
- Every gun part is moved by the clip through the gun's own Motor6Ds (no code needed); `MagHide` / `MagShow` markers
  ask the code to hide the dropped mag on empty reloads.

## 0b. Ammo-aware reload variants (reload-variants animator, 2026-10-30)
The reload looks different by rounds left; every variant of a gun is exactly the gun's runtime ReloadTime long (AdjustSpeed
1.0) and shares its anchor markers. Design: `notes/reload_variants_design.md`. **19 clips + 19 `...Left` mirrors** in
`ReplicatedStorage.Repository.AnimationSources` via `art/anim/reload_variants/install_sources.lua`; per clip (rounds left,
length, markers, id, grade): `art/anim/reload_variants/DONE.md`. Published ids: not yet (ready to publish, group gunsy funsy).
- `PistolReload_Retain / _Drop / _Dry` 1.3 s (Pistol 7-11 / 1-6 / 0; Suppressed 6-9 / 1-5 / 0 at AdjustSpeed 1.3/1.5)
- `SMGReload_Retain / _Drop / _Dry` 1.7 s (Mini Uzi 16-29 / 1-15 / 0)
- `RifleReload_Retain / _Drop / _Dry` 2.2 s (Auto Rifle 16-29 / 1-15 / 0; Semi-Auto 7-11 / 1-6 / 0 at AdjustSpeed 2.2/2.5)
- `SniperReload_TopUp / _Dry` 3.0 s (1-4 / 0)
- `RevolverReload_Pluck1 / _Pluck2 / _Dump / _Dry` 2.0 s (5 / 4 / 1-3 / 0): needs `Round1..Round6` split in the model
- `ShotgunReloadStart_Dry` 0.2 s, `ShotgunReloadShell_Port / _B / _Last` 0.5 s (first shell when empty / alternate / fills the tube)
- Dual Pistols: not made yet (needs the left-hand mirror bake; see DONE.md open issues).

## 1. Character animations that exist (54)

### Pistol (used by Pistol, Suppressed, **and for now Mini Uzi, Auto Rifle, Semi-Auto, Sniper**)
| Name | Length | Loop | What it is |
|---|---|---|---|
| PistolHold (+Left) | 1.0 | yes | Arms up, aiming: shown while aiming or right after a hip-fire shot |
| PistolLowered (+Left) | 1.0 | yes | Gun down at your side when not aiming (camera not facing forward) |
| PistolEquip (+Left) | 0.35 | no | Bring the gun up when it's selected |
| PistolFire (+Left) | 0.15 | no | One shot of recoil kick |
| PistolReload (+Left) | 1.6 → **1.5** | no | Mag out, new mag in, rack the slide |

### Revolver
| Name | Length | Loop | What it is |
|---|---|---|---|
| RevolverHold (+Left) | 1.0 | yes | Aiming pose |
| RevolverLowered (+Left) | 1.0 | yes | Gun down at your side |
| RevolverEquip (+Left) | 0.35 | no | Bring it up |
| RevolverFire (+Left) | 0.30 | no | Heavy recoil kick |
| RevolverReload (+Left) | 2.4 | no | Swing out cylinder, dump shells, reload, flick shut |

### Melee
| Name | Length | Loop | What it is |
|---|---|---|---|
| MeleeSlash | 0.45 | no | Knife slash |
| MeleePunch | 0.40 | no | Fists punch |
| QuickMeleeBash | 0.40 | no | Quick melee with the gun in hand (now just a copy of the punch: should be a gun-butt bash) |

### Gadgets (Smoke; Flash and Frag reuse these)
| Name | Length | Loop | What it is |
|---|---|---|---|
| SmokeHold | 1.0 | yes | Holding the grenade ready |
| SmokeThrow (+Left) | 0.40 | no | Overarm throw |
| SmokeRoll | 0.55 | no | Underarm roll/lob along the floor |

### Cover
| Name | Length | Loop | What it is |
|---|---|---|---|
| CoverIdleTall (+Left) | 1.0 | yes | Standing with your back to tall cover |
| CoverCrouch (+Left) | 1.0 | yes | Crouched behind low cover |
| CoverCrouchPeek (+Left) | 1.0 | yes | Crouched, leaning out to aim past the edge |
| CoverLookPos / CoverLookNeg | 1.0 | yes | Head and shoulders turned toward the left / right edge (blended in) |
| CoverShuffleTall | 0.60 | yes | Side-stepping along tall cover |
| CoverShuffleCrouch | 0.72 | yes | Side-stepping while crouched |
| CoverBlindCorner (+Left) | 1.0 | yes | Blind fire: gun arm curled around a tall edge, body hidden |
| CoverBlindCornerCrouch (+Left) | 1.0 | yes | Same, while crouched |
| CoverBlindOver (+Left) | 1.0 | yes | Blind fire over low cover: half-rise, gun up over the top, other hand braced |
| CoverBrace | 0.75 | no | Near miss: flinch and tuck into the cover |
| CoverDash | 0.48 | yes | Sprint dash between covers |
| CoverRoll | 0.50 | no | Dodge roll |
| CoverVault | 0.55 | no | Vault over low cover |
| CoverSneak | 1.2 | yes | Slow sneak walk |
| CoverPullUp | 0.70 | no | **Final, published** (2026-10-29): jump, both hands catch a ledge 4.0-5.1 studs high, pull, knee over, stand. Action4, markers `EdgeGrab` 0.10 / `TopReached` 0.50, root motion in code (`RootKeys`). id 105938022338716 |
| CoverLeanLeft / CoverLeanRight | 1.2 | yes | **Final, published**: tall-cover peek lean, torso 16 deg out, head 0.88 / gun 0.74-0.86 studs out, legs planted; keys only torso + legs so aim and fire layer on top. Action4, fade 0.1. ids 127076882923530 / 121823634742999 |
| CoverLeanLeftCrouch / CoverLeanRightCrouch | 1.2 | yes | **Final, published**: the same on the CoverCrouchPeek legs (low-cover side peek). ids 135867304208492 / 85469112434832 |

Pull-up / lean details, root-motion table and wiring notes: `art/anim/pullup_lean/DONE.md`; sources installer
`art/anim/pullup_lean/install_sources.lua`. Published 2026-10-29 the same way as CoverClimb: Studio right-click the
KeyframeSequence > Save / Export > Save to Roblox, Creator **gunsy funsy** (the dropdown starts on "Me" every time), Delete
Local Instances off; then `PublishedId = "rbxassetid://<id>"` on the source; ownership checked on
`economy.roblox.com/v2/assets/<id>/details` (Creator Group 102028987).

### Movement and hits
| Name | Length | Loop | What it is |
|---|---|---|---|
| MoveCrouchIdle | 1.0 | yes | Crouched, standing still |
| MoveCrouchWalk | 1.2 | yes | Crouch walk |
| MoveSlide | 0 (one pose) | yes | Slide: currently a single held pose, needs a real loop |
| HitFlinch | 0.30 | no | Small flinch when you get shot |
| BotLeanLeft / BotLeanRight | 1.0 | yes | Training bots leaning out of cover (2 joints only) |

## 2. What's missing for the other guns
Mini Uzi, Auto Rifle, Semi-Auto and Sniper use the **Pistol** body animations now (`AnimationSourcePrefix = "Pistol"`), so they're
held one-handed like a pistol. To give them their own, make a set for each (with Left versions) and I'll change the prefix:

| New prefix | Guns | Hold / Lowered / Equip / Fire / Reload | Reload length |
|---|---|---|---|
| `SMG` | Mini Uzi | two-handed compact, fast recoil | 1.9 s |
| `Rifle` | Auto Rifle, Semi-Auto | shouldered, two-handed | 2.4 s / 2.3 s (one anim, I'll speed it) |
| `Sniper` | Sniper | shouldered; **Fire must include working the bolt** (1.3 s between shots) | 3.0 s |

## 3. Gun model animations (the gun's own parts)
Right now **every gun part is welded with a WeldConstraint**, so nothing on a gun can move yet. When you import, I'll swap the welds
for Motor6Ds named after each part (Handle → part) so the parts listed below can be keyframed alongside the character. Animate the
gun parts in the **same action** as the character move (e.g. PistolReload moves the arms *and* the mag/slide).

| Gun | Parts that should move | Fire | Reload | Equip / Holster |
|---|---|---|---|---|
| Pistol | **Slide**, **MagBase** | Slide snaps back and forward | MagBase drops out, new one in, Slide racks | Slide check (optional) |
| Suppressed | **Slide**, **MagBase** (Suppressor stays fixed) | Same as Pistol | Same as Pistol | — |
| Revolver | **Cylinder**, **Hammer** | Hammer falls, Cylinder turns 1/6 | Cylinder swings out (and spins), back in | Hammer cock (optional) |
| Mini Uzi | **Mag**, **CockingKnob** | CockingKnob is fixed on an Uzi, nothing needed | Mag out/in, CockingKnob pulled back | — |
| Auto Rifle | **Mag**, **MagBase** (one piece: move together) | (optional: tiny Receiver shake) | Mag out/in, charge | — |
| Semi-Auto | **Mag** | — | Mag out/in | — |
| Sniper | **BoltArm**, **BoltKnob** (together), **Mag**, BipodLeg x2 (optional) | Bolt up, back, forward, down | Mag out/in, bolt cycle | Bipod fold (optional) |
| Knife | single part (`Knife`) | — | — | flip/twirl for inspect (optional) |

Parts that stay fixed: Handle, Frame, Receiver, Barrel, TriggerGuard, Stock, scopes, rails, vents, MuzzleBrake.

## 4. New animations you want to add
Not in the game yet: name them like this and I'll wire them into the scripts.

| Name | What it is | Notes |
|---|---|---|
| `<Prefix>Holster` (+Left) | Put the gun away (back to the hip/back) | Plays when you holster (key 1) or switch slot; I'll wait for it to finish before the gun disappears |
| `<Prefix>Draw` (+Left) | Pull the gun from the holster | Today's `Equip` is a quick bring-up; Draw would replace it on first pull-out |
| `<Prefix>Inspect` (+Left) | Weapon inspect (needs a key: I'd suggest F) | Optional |
| `MeleeKnifeHeavy`, `MeleeKnifeBackstab` | Knife heavy swing / backstab | Optional; there's only one knife swing now |
| `FlashThrow`, `FragThrow` | Their own throws | Optional; they use the Smoke throw now |

`<Prefix>` = Pistol, Revolver, and SMG / Rifle / Sniper if you make those sets.

## Hand-off
Export each action from Blender as FBX (R15 rig, one action each, names as above). When you send them over, I'll import them into
AnimationSources, set Loop and priority, add the gun Motor6Ds, and update the scripts. Uploads go under Gunsy Funsy.

## 5. Final body / movement set (anim-body, 2026-10-30)
Every body placeholder above (Cover*, Move*, HitFlinch, BotLean*) is replaced by a final clip with the **same name, length and
Loop**, made in Blender on the Starter Blocky rig (style Grounded Tactical). Per-clip ids, lengths, markers and grades:
`art/anim/body/DONE.md`; install: `art/anim/body/install_sources.lua`; code wiring: `art/anim/body/HANDOFF_systems.md`.
- **New names the code must add** (hand-off): `CoverShuffleTallRight`, `CoverShuffleCrouchRight` (shuffles step toward the
  character's left; pick by cover.side), `CoverLookPosCrouch` / `CoverLookNegCrouch`, `CoverBraceCrouch`, `CoverDiveAim`
  (MoveAnimations.DiveAim), locomotion `MoveRun` / `MoveWalkAim` / `MoveStrafeLeft` / `MoveStrafeRight` / `MoveBackpedal` /
  `MoveSprint` / `MoveSprintPistol` / `MoveStart` / `MoveStop` / `TurnInPlaceLeft` / `TurnInPlaceRight` / `MoveLandHard` /
  `MoveLimp`, reactions `HitFlinchF/B/L/R`, `HitHeadshot`, `HitExplosionStagger`, `HitBurning`, deaths `DeathForward` /
  `DeathBackward` / `DeathCrumple` / `DeathHeadshot` / `DeathExplosion` / `DeathCover`, life `IdleFidgetShift` /
  `IdleFidgetGunCheck` / `IdleFidgetLook` / `BreatheCalm` / `BreatheHeavy` / `RoundReady` / `Victory` / `Defeat` / `DoorOpen`.
- Changed on purpose: shuffles step 6 times per cycle (zero foot slide at 8 studs/s on blocky legs), CoverSneak 4 steps per
  cycle, MoveWalkAim / MoveCrouchWalk 4 steps per cycle; MoveSlide is a real 0.5 s loop; BotLean* key hips + legs + chest.
- Every clip keys only the joints it owns (the others are Weight 0), so layers never reset the hips.
