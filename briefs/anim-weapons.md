# Clip plan: final weapon / melee / gadget animations (animator, 2026-10-30)

Style: Grounded Tactical (vault `05 Animation/Animation Styles/Grounded Tactical.md`); per-clip beats, easings and markers:
`notes/anim_style_targets.md` sections 1-8 (the body / movement set, sections 9-12, belongs to the other animator).
Pipeline: `art/anim/PIPELINE.md`. Source of truth: `art/anim/weapons/blender/clips/<set>.py` -> `sets/<set>.blend`.

| Batch | Clips | Kind | Notes |
|---|---|---|---|
| 1 (body-only) | PistolHold, PistolLowered, PistolEquip, PistolDraw, PistolHolster, SmokeHold, SmokeThrow, SmokeRoll, FragPinPull, FragCook, FragThrow, FlashThrow, LandminePlace, MedkitUse, MeleeSlash, MeleePunch, MeleeKnifeHeavy, MeleeKnifeBackstab | clips | holds loop (Action), one-shots Action; reload/fire/equip get Action4 from the code |
| 2 | Revolver / SMG / Rifle / Shotgun / Sniper Hold, Lowered, Equip, Draw, Holster; QuickMeleeBash; Bat / Katana / RiotShield sets | clips | two-handed holds need each gun's grip (Tool.Grip) and handguard |
| 3+ (per gun, once listed in `art/anim/guns/DONE.md`) | <Prefix>Fire, Reload, ReloadEmpty / Tactical, Inspect (+ Shotgun ReloadStart/Shell/End, Sniper bolt in Fire) | clips with gun-part keys | parts keyed in the same action (Motor6D Handle -> part) |

Every right-hand weapon clip gets a `...Left` mirror (melee and two-hand-symmetric gadget clips don't).
Springs (sway, recoil tail, equip bounce) stay in the code's WeaponFeel; the clips leave room for them (moderate peaks).
Markers: exact names from the targets page (`Hit`, `Release`, `Grip`, `Holstered`, `Placed`, `MagOut`, `MagIn`, ...).
Lengths and Loop flags: the code's (targets page / `notes/animation_list.md`).
