# Batch 1 (body-only): DONE, self-checked (animator, 2026-10-30)

Pistol body clips, all gadgets, knife / fist melee. Built in Blender (`art/anim/weapons/blender/clips/{pistol,gadgets,melee}.py`
-> `sets/*.blend`), exported at 60 fps, installed into `out/anim_weapons/anim_weapons.rbxl` (AnimationSources).
Not published yet (see DONE.md when done). Graded by HQ's fresh grader after the task (HQ rule: no self-started graders).

| Clip | Length | Loop | Priority | Markers (s) | Keys | Max hand gap (studs) |
|---|---|---|---|---|---|---|
| FlashThrow | 0.400 | no | Action | Release 0.150 | 25 | 0.0001 |
| FlashThrowLeft | 0.400 | no | Action | Release 0.150 | 25 | 0.0001 |
| FragCook | 1.000 | yes | Action | - | 3 | 0.0 |
| FragPinPull | 0.300 | no | Action | Pin 0.117 | 19 | 0.0002 |
| FragThrow | 0.400 | no | Action | Release 0.150 | 25 | 0.0002 |
| FragThrowLeft | 0.400 | no | Action | Release 0.150 | 25 | 0.0002 |
| LandminePlace | 0.900 | no | Action | Placed 0.367 | 44 | 0.0 |
| MedkitUse | 2.500 | no | Action | Open 0.367, Heal 0.700 | 80 | 0.0 |
| MeleeKnifeBackstab | 0.600 | no | Action | Hit 0.167 | 34 | 0.0 |
| MeleeKnifeHeavy | 0.700 | no | Action | Hit 0.283 | 39 | 0.0002 |
| MeleePunch | 0.400 | no | Action | Hit 0.100 | 23 | 0.0001 |
| MeleeSlash | 0.450 | no | Action | Hit 0.117 | 27 | 0.0002 |
| PistolDraw | 0.500 | no | Action | Grip 0.067 | 25 | 0.0 |
| PistolDrawLeft | 0.500 | no | Action | Grip 0.067 | 25 | 0.0 |
| PistolEquip | 0.350 | no | Action | - | 14 | 0.0 |
| PistolEquipLeft | 0.350 | no | Action | - | 14 | 0.0 |
| PistolFire | 0.150 | no | Action | ShellEject 0.017 | 9 | 0.0 |
| PistolFireLeft | 0.150 | no | Action | ShellEject 0.017 | 9 | 0.0 |
| PistolHold | 1.000 | yes | Action | - | 3 | 0.0 |
| PistolHoldLeft | 1.000 | yes | Action | - | 3 | 0.0 |
| PistolHolster | 0.450 | no | Action | Holstered 0.317 | 28 | 0.0 |
| PistolHolsterLeft | 0.450 | no | Action | Holstered 0.317 | 28 | 0.0 |
| PistolLowered | 1.000 | yes | Action | - | 3 | 0.0 |
| PistolLoweredLeft | 1.000 | yes | Action | - | 3 | 0.0 |
| SmokeHold | 1.000 | yes | Action | - | 3 | 0.0 |
| SmokeRoll | 0.550 | no | Action | Release 0.267 | 34 | 0.0 |
| SmokeThrow | 0.400 | no | Action | Release 0.150 | 25 | 0.0002 |
| SmokeThrowLeft | 0.400 | no | Action | Release 0.150 | 25 | 0.0002 |

Captures (`captures/anim/weapons/`): `<Clip>_side_15.png` (1x, 15 fps), `<Clip>_game_15.png` (gameplay camera, 1x),
`<Clip>_side_60.png` (every frame = 0.25x) for the short one-shots, `PistolFire_fp.png` (first person),
`roundtrip_ingame.png` (Play mode, real avatar, the game's own controller playing PistolLowered).

Checks: lengths / loops = the code's; loops have first = last pose (Cycles, 3-key moving hold 0.4 deg / 0.01 sink);
every action moves on frame 1; contacts on the marker frame with Expo In / Linear into it; no hand target out of reach
(gap 0.000, the exporter warns otherwise); joints rotation-only except Root, so any avatar proportions work.
Known limits: melee clips have no Left versions (the code has none); gadget throws are right-handed with a Left mirror
for Smoke / Frag / Flash throws.
