# Animation style targets: Grounded Tactical (2026-10-30)

One target per clip for the final gameplay animations. Style rules (easing table, recoil, gun-part timing, off hand, what to
avoid): vault `05 Animation/Animation Styles/Grounded Tactical.md`. **Read that first; this page only says what each clip does
when.** Quality floor: `art/anim/pullup_lean/DONE.md` (moving on frame 1, contacts within 0.06 studs, loops seamless, layer
clips key only their joints).

## Conventions
- **Rig:** Edward's Starter BLOCKY rig (R15 part names), `Roblox Starter Rigs/Rigs/Starter_Blocky_Rig.blend`. One action per clip,
  the gun's moving parts keyed in the **same action** (Motor6D Handle -> part, names as the remodel; see "Gun parts").
- **Frames are at 60 fps, `f0` = the first frame.** `f6-f14 Quart Out` = the keys between f6 and f14 use Quart Out
  (Blender interpolation mode; the FBX bakes it). "hold" = moving hold (0.3-1 deg drift, Sine InOut), never frozen.
- **Lengths are the code's** (`notes/animation_list.md`, `WeaponConfig`, `MeleeConfig`, `GadgetConfig`, `CoverConfig`,
  `MovementConfig` read from `match_place_ref.rbxl` copies, 2026-10-30). Code stretches reloads with
  `AdjustSpeed(length / ReloadTime)`: the runtime ReloadTime is now Pistol 1.3, Suppressed 1.5, Mini Uzi 1.7, Revolver 2.0,
  Auto Rifle 2.2, Semi-Auto 2.5, Sniper 3.0 (the clip lengths stay as listed; the beats scale with them).
- **Level aim, light neck** (AimPoseController / HeadLookController own pitch and the neck). Neck keys <= 10-15 deg.
- **`+Left`** = mirror for left-handed players: make every weapon one-shot / hold right-handed first; mirrors after approval.
- **Markers** (exact names): `MagOut`, `MagIn`, `MagStowed`, `SlideRack`, `BoltClosed`, `PumpClosed`, `ShellEject`, `ShellIn`,
  `CylinderOpen`, `CylinderClosed`, `Grip` (gun appears in the hand), `Holstered` (gun leaves the hand), `Hit`, `Release`, `Pin`,
  `Placed`, `Open`, `Heal`, `Push`, `Footstep`, `Land`, `Ground`, `DropGun`. Gameplay uses only `Hit` / `Release` / `Grip` /
  `Holstered` / `Placed` / `Push`; the rest drive sounds, shells and mags.
- Cancel window = from that frame the code may fade out (0.08-0.1) into the next action.

## Gun parts (the remodel tonight: name the Motor6D after the part)
| Gun | Moving parts | Fire | Reload |
|---|---|---|---|
| Pistol, Suppressed | `Slide`, `MagBase` (+ the mag body if separate) | Slide back 1 f, forward 2 f (Quad In) | mag out / in; empty: Slide locked back from f0, racked |
| Revolver | `Cylinder` (crane hinge), `Hammer`, `Ejector` (optional) | Hammer falls f0, Cylinder 1/6 turn f0-f2 Quad In | swing out, eject, load, close |
| Mini Uzi | `Mag` (in the grip), `CockingKnob` | knob fixed | mag out / in; empty: knob pull |
| Auto Rifle / Semi-Auto | `Mag` + `MagBase` (together), `ChargingHandle` (add it) | optional 1 f Receiver shake: no | mag out / in; empty: charge |
| Pump Shotgun | `Pump` (fore-end, on the tube axis), `Shell` (hand prop, shown/hidden by marker) | pump cycle in Fire | shell by shell; empty: pump |
| Sniper | `BoltArm` + `BoltKnob` (together, pivot on the bore axis), `Mag`, `BipodLeg` x2 (optional) | bolt cycle in Fire | mag out / in + bolt |
| Fixed, never key | Handle, Frame, Receiver, Barrel, TriggerGuard, Stock, scopes, rails, vents, MuzzleBrake, Suppressor | | |

---

## 1. Pistol (`Pistol`; Pistol + Suppressed)
| Clip | Len | Loop | Key poses | Beats (60 fps) and easing | Markers |
|---|---|---|---|---|---|
| PistolHold (+L) | 1.0 | yes | two-hand isosceles grip, arms near straight (elbows 10-15 deg soft), gun at eye line, knees 6 deg | f0-30 Sine InOut chest +0.4 deg / sink 0.01, f30-60 back; f60 = f0 | |
| PistolLowered (+L) | 1.0 | yes | gun hand at the thigh, muzzle 45 deg down and in front of the foot, finger straight, off hand relaxed at the belt | same drift, gun hand 0.5 deg | |
| PistolEquip (+L) | 0.35 | no | from Lowered to Hold | f0-f10 Quart Out arc up and forward (off hand meets f8), f10-f14 Back Out 5% settle, f14-f21 hold | |
| PistolFire (+L) | 0.15 | no | | f0 = Hold, f1 peak (wrist +8, elbows +4, shoulders 0.06 back, chest +1) Linear, f1-f9 Cubic Out return. Slide: f0-f1 back, f1-f3 Quad In forward | `ShellEject` f1 |
| PistolReload (+L) tactical | 1.5 | no | tilt, strip, stow, seat, rewrap | f0-f6 Cubic Out tilt 20 deg roll to the off hand, down 0.15; f6 thumb release; MagBase out f6-f12 Cubic Out (off hand strips it); f12-f28 Sine InOut to the hip pouch; f28-f44 Sine InOut new mag to the well; f44-f46 Linear seat + heel push; f46-f50 hold; f50-f62 Quart Out gun back up; off hand rewraps f56-f64; f64-f90 hold. Cancel before f46 | `MagOut` f6, `MagStowed` f28, `MagIn` f46 |
| PistolReloadEmpty (+L) NEW | 1.9 | no | slide locked back from f0 | f0-f6 tilt; f6 release, mag drops free f6-f18 Quad In (hide f18) while the off hand goes to the pouch f6-f16; f16-f36 Sine InOut new mag; f36-f38 Linear seat; f38-f41 hold; f41-f52 Sine InOut off hand over the top; Slide back f52-f55 Cubic Out, hold f55-f57, forward f57-f59 Quad In hard stop; f59-f74 Quart Out up, rewrap f62-f72; f74-f114 hold. Cancel before f38 | `MagOut` f6, `MagIn` f38, `SlideRack` f59 |
| PistolDraw (+L) NEW | 0.50 | no | hand to the hip holster, pull, punch out | f0-f4 Cubic Out hand to grip; f4 grip; f4-f10 Quart Out straight up out of the holster; f10-f20 Quart Out punch out to aim (off hand meets f16); f20-f24 Back Out 4%; f24-f30 hold | `Grip` f4 |
| PistolHolster (+L) NEW | 0.45 | no | | f0-f8 Cubic InOut gun to the chest, muzzle down; f8-f16 Sine InOut to the holster mouth (head glances down f6-f12, light); f16-f19 Linear push in; f19-f27 Cubic Out hand off, relaxed | `Holstered` f19 |
| PistolInspect (+L) NEW | 3.0 | no | show left side, show right side, press check | f0-f20 Cubic InOut bring closer (0.6 studs), roll 70 deg; f20-f60 hold; f60-f80 Cubic InOut roll over; f80-f100 hold; off hand pinches the Slide f100-f106 back 0.15 Cubic Out, f106-f118 hold (look at the chamber, head lead f98), f118-f120 Quad In forward; f120-f150 Sine InOut thumb taps the mag base; f150-f180 Cubic Out back to Hold | `SlideRack` f120 |

## 2. Revolver (`Revolver`)
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| RevolverHold (+L) | 1.0 | yes | two-hand grip, elbows softer than the pistol (15-20 deg), slightly lower | drift as PistolHold | |
| RevolverLowered (+L) | 1.0 | yes | as PistolLowered, gun heavier: muzzle 50 deg down | | |
| RevolverEquip (+L) | 0.35 | no | | f0-f11 Quart Out (one frame slower than the pistol), f11-f15 Back Out 4%, f15-f21 hold; Hammer stays down | |
| RevolverFire (+L) | 0.30 | no | heavy kick | Hammer falls f0 (1 f), Cylinder 1/6 turn f0-f2 Quad In; f2 peak (muzzle +18, elbows +10, shoulders 0.12 back, chest +3, head +2 at f3) Linear; f2-f18 Quint Out return with one 0.5 deg dip under the line at f12 | |
| RevolverReload (+L) | 2.4 | no | always a full dump (no tactical / empty split) | f0-f6 Cubic Out tilt 30 deg left, off hand under the frame; f6-f8 thumb latch; Cylinder out f8-f13 Cubic Out 90 deg; f13-f16 hold; f16-f22 Cubic Out muzzle up 60 deg, f19-f22 Linear thumb on the Ejector; f22-f34 muzzle down; f34-f50 Sine InOut off hand to the belt (speedloader); f50-f70 Sine InOut loader to the cylinder; f70-f72 Linear insert; f72-f78 twist; loader hidden f80; f80-f96 hand back; f96-f99 Quart Out wrist flick, Cylinder closes (hard stop, no Back); f99-f102 hold; f102-f120 Quart Out up; f120-f144 hold. Cancel before f70 | `CylinderOpen` f13, `ShellEject` f22, `ShellIn` f72, `CylinderClosed` f99 |
| RevolverDraw (+L) NEW | 0.55 | no | as PistolDraw, +3 f in the pull | f0-f5, `Grip` f5, f5-f12 up, f12-f23 out, f23-f27 Back 4%, f27-f33 hold | `Grip` f5 |
| RevolverHolster (+L) NEW | 0.45 | no | as PistolHolster | | `Holstered` f19 |
| RevolverInspect (+L) NEW | 3.0 | no | roll to show the side, open the cylinder, check the chambers, close by hand | f0-f20 Cubic InOut roll; f20-f50 hold; Cylinder out f50-f56 Cubic Out; f56-f100 hold (head leads to the chambers f52); off hand pushes it shut f100-f106 Cubic Out (no flick, no spin); f106-f140 hold; f140-f180 Cubic Out back | `CylinderOpen` f56, `CylinderClosed` f106 |

## 3. SMG (`SMG`; Mini Uzi) NEW SET
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| SMGHold (+L) | 1.0 | yes | compact two-hand: gun hand on the grip, off hand under the front, elbows tucked, gun at chin height 0.4 in front of the chest | drift 0.4 deg | |
| SMGLowered (+L) | 1.0 | yes | gun hand at the hip, muzzle 40 deg down, off hand still on the front | | |
| SMGEquip (+L) | 0.35 | no | | f0-f9 Quart Out, f9-f13 Back Out 4%, f13-f21 hold | |
| SMGFire (+L) | 0.10 | no | restarts each shot (fade 0.03) | f1 peak (muzzle +2.5, shoulders 0.04 back, chest +0.5) Linear, f1-f6 Cubic Out; yaw 0.3 deg toward the gun hand (code may alternate sign) | `ShellEject` f1 |
| SMGReload (+L) tactical | 1.9 | no | mag in the grip | f0-f6 Cubic Out tilt 25 deg; f6-f10 off hand to the grip base; f10 release, Mag out the bottom f10-f16 Cubic Out; f16-f34 Sine InOut stow; f34-f54 Sine InOut new mag; f54-f56 Linear seat + heel slap; f56-f60 hold; f60-f80 Cubic InOut off hand to the front; f80-f94 Quart Out up; f94-f114 hold. Cancel before f56 | `MagOut` f10, `MagStowed` f34, `MagIn` f56 |
| SMGReloadEmpty (+L) | 2.3 | no | + knob | as tactical to f56 but the mag drops free (Quad In f10-f22, hide f22); f56-f60 hold; f60-f72 Sine InOut off hand over the top; CockingKnob back f72-f76 Cubic Out, hold f76-f78, forward f78-f80 Quad In; f80-f104 off hand to the front; f104-f118 Quart Out up; f118-f138 hold | `MagOut` f10, `MagIn` f56, `SlideRack` f80 |
| SMGDraw (+L) | 0.50 | no | from a chest sling / hip | f0-f5 Cubic Out hand to grip, `Grip` f5; f5-f18 Quart Out up and out, off hand catches the front f14; f18-f22 Back 4%; f22-f30 hold | `Grip` f5 |
| SMGHolster (+L) | 0.45 | no | to the sling at the right hip | f0-f10 Cubic InOut down and in; f10-f18 Sine InOut to the sling; f18 release; f18-f27 Cubic Out off | `Holstered` f18 |
| SMGInspect (+L) | 3.0 | no | tilt, knob check, mag tap | f0-f20 roll 60; f20-f60 hold; knob back 0.1 f70-f74, look f70-f100, forward f100-f102 Quad In; f110-f140 mag tap; f140-f180 back | `SlideRack` f102 |

## 4. Rifle (`Rifle`; Auto Rifle + Semi-Auto) NEW SET
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| RifleHold (+L) | 1.0 | yes | stock in the shoulder pocket, cheek weld (head -8 pitch, 5 roll), gun elbow 45 deg out, off hand on the handguard, chest +5 forward, knees 6, feet staggered | drift 0.5 deg, sink 0.015 | |
| RifleLowered (+L) | 1.0 | yes | low ready: stock still in the shoulder, muzzle 35 deg down, head up off the stock | | |
| RifleEquip (+L) | 0.35 | no | | f0-f11 Quart Out (muzzle arcs up from low), stock meets the shoulder f9; f11-f15 Back Out 4%; f15-f21 hold | |
| RifleFire (+L) | 0.12 | no | restarts on auto (fade 0.03); Semi-Auto uses it too | f1 peak (muzzle +3.5, shoulder rocks back 0.07, chest +1, off elbow drops 3) Linear; f1-f7 Cubic Out | `ShellEject` f1 |
| RifleReload (+L) tactical | 2.4 | no | | f0-f8 Cubic Out roll 25 deg right, muzzle -10; f4-f14 off hand to the mag; f16 release, Mag+MagBase out f16-f24 Cubic Out (strip 0.8 along the well); f24-f44 Sine InOut stow (chest pouch); f44-f66 Sine InOut new mag, tilted 10 deg front lip first; f66-f70 Linear rock in and seat; f70-f74 hold; f74-f80 Cubic Out tug check; f80-f92 Cubic InOut off hand to the handguard; f92-f108 Quart Out roll back and shoulder; f108-f144 hold. Cancel before f70 | `MagOut` f16, `MagStowed` f44, `MagIn` f70 |
| RifleReloadEmpty (+L) | 2.8 | no | + charge | f0-f16 as tactical; mag drops free f16-f30 Quad In (hide f30); f18-f56 Sine InOut new mag; f56-f60 Linear seat; f60-f64 hold; f64-f80 Sine InOut off hand to the ChargingHandle; back f80-f84 Cubic Out, hold f84-f86, forward f86-f88 Quad In; f88-f104 Cubic InOut back to the handguard; f104-f120 Quart Out shoulder; f120-f168 hold | `MagOut` f16, `MagIn` f60, `SlideRack` f88 |
| RifleDraw (+L) | 0.60 | no | from the back sling | f0-f6 Cubic Out gun hand over the right shoulder, `Grip` f6; f6-f18 Cubic InOut swing over and down on an arc; off hand catches the handguard f18; f18-f28 Quart Out mount; f28-f32 Back 4%; f32-f36 hold | `Grip` f6 |
| RifleHolster (+L) | 0.60 | no | to the back sling | f0-f10 Cubic InOut off the shoulder, off hand releases f8; f10-f24 Sine InOut up over the shoulder; f24 release; f24-f36 Cubic Out hand down | `Holstered` f24 |
| RifleInspect (+L) | 3.0 | no | tilt left side, mag check, chamber check | f0-f24 Cubic InOut lift and roll 45; f24-f60 hold; f60-f72 Mag out 0.3 partly (Cubic Out), look; f72-f90 Linear back in; ChargingHandle back 0.15 f100-f104, look f104-f124, forward f124-f126 Quad In; f126-f150 hold; f150-f180 Cubic Out back to Hold | `SlideRack` f126 |

## 5. Shotgun (`Shotgun`; Pump Shotgun) NEW SET
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| ShotgunHold (+L) | 1.0 | yes | as RifleHold, feet wider, chest +6, off hand on the Pump | drift 0.5 | |
| ShotgunLowered (+L) | 1.0 | yes | low ready, muzzle 40 deg down | | |
| ShotgunEquip (+L) | 0.35 | no | | f0-f12 Quart Out, f12-f15 Back Out 4%, f15-f21 hold | |
| ShotgunFire (+L) | 0.85 | no | shot + pump (FireInterval 0.85) | f0 = Hold; f1-f2 peak (muzzle +11, shoulder 0.22 back, chest +4, head +2, hips +1) Linear; f2-f12 Quint Out recover; Pump back f12-f20 Quart Out 0.45 studs (gun rolls 5 deg toward the off hand); f20-f22 hold; Pump forward f22-f28 Cubic In hard stop; f28-f51 Cubic Out settle, cancellable from f28 | `ShellEject` f18, `PumpClosed` f28 |
| ShotgunReloadStart (+L) | 0.20 | no | = ShellReload.StartDelay | f0-f12 Cubic Out roll the gun belly up 70 deg, muzzle -10; off hand from the Pump to the belt carrier | |
| ShotgunReloadShell (+L) | 0.50 | no (played per shell) | = ShellTime; start pose = end pose | f0-f10 Sine InOut off hand belt -> loading port with a Shell (shown f2); f10-f14 Cubic Out thumb push; f14-f16 hold; f16-f30 Sine InOut back to the belt. A shot cuts it: fade 0.08 to Fire from any frame | `ShellIn` f14 |
| ShotgunReloadEnd (+L) | 0.30 | no | | f0-f12 Cubic InOut roll back, off hand to the Pump; f12-f18 Quart Out shoulder | |
| ShotgunReloadEndEmpty (+L) | 0.55 | no | started empty: + pump | f0-f12 as End; Pump back f12-f18 Quart Out, hold f18-f20, forward f20-f25 Cubic In; f25-f33 settle | `PumpClosed` f25 |
| ShotgunDraw / Holster / Inspect (+L) | 0.65 / 0.60 / 3.0 | no | back sling, as Rifle with +3 f in each swing; inspect: roll to show the port, half-pump to check (Pump back 0.15, look, forward Cubic In), shell top-up thumb | Draw `Grip` f6; Holster `Holstered` f24 | |

## 6. Sniper (`Sniper`) NEW SET
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| SniperHold (+L) | 1.0 | yes | as RifleHold, cheek on the stock behind the scope (head -10 pitch), chest +6, knees 8 | drift 0.4 (steadier) | |
| SniperLowered (+L) | 1.0 | yes | low ready, muzzle 45 down, heavier | | |
| SniperEquip (+L) | 0.35 | no | | f0-f13 Quart Out, f13-f16 Back Out 3%, f16-f21 hold | |
| SniperFire (+L) | 1.30 | no | shot + bolt (FireInterval 1.3) | f1-f2 peak (muzzle +9, shoulder 0.2 back, chest +3, head +2) Linear; f2-f14 Quint Out recover; f14-f18 Sine InOut gun hand to the BoltKnob; bolt up 60 deg f18-f22 Cubic Out; back f22-f30 Quart Out; f30-f32 hold; forward f32-f38 Cubic In; down f38-f41 Quart Out; f41-f52 Cubic InOut hand back to the grip; f52-f78 Cubic Out reacquire (head back on the stock f50). Cancellable from f54 | `ShellEject` f26, `BoltClosed` f41 |
| SniperReload (+L) | 3.0 | no | mag + bolt (what the code expects now) | f0-f10 Cubic Out off the cheek, roll 15, weight back; f10-f16 off hand to the Mag; f18 release, out f18-f26 Cubic Out; f26-f50 Sine InOut stow (hide f50); f50-f80 Sine InOut new mag; f80-f84 Linear seat; f84-f88 hold; f88-f98 Sine InOut gun hand to the bolt; up f98-f102 Cubic Out, back f102-f110 Quart Out, hold f110-f113, forward f113-f119 Cubic In, down f119-f122 Quart Out; f122-f134 hand to the grip; f134-f154 Quart Out remount; f154-f180 hold. Cancel before f84 | `MagOut` f18, `MagStowed` f50, `MagIn` f84, `BoltClosed` f122 |
| SniperReloadTactical (+L) optional | 2.5 | no | a round still chambered: no bolt | as SniperReload to f88, then f88-f108 off hand back, f108-f128 remount, f128-f150 hold | `MagIn` f84 |
| SniperDraw / Holster (+L) | 0.75 / 0.65 | no | back sling, the heaviest swing | Draw `Grip` f7, mount f22-f36 Quart Out, Back 3% f36-f40 | |
| SniperInspect (+L) | 3.0 | no | scope check (head to the scope f20), bolt lift + half pull and look, close Cubic In; optional bipod fold out f120-f126 / in f150-f156 Cubic InOut | | `BoltClosed` |

## 7. Melee
HitDelay from MeleeConfig = the `Hit` frame. Cancel after `Hit` + 6 f.
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| MeleeSlash (knife) | 0.45 | no | reverse-grip forehand slash | f0-f3 Cubic Out coil (knife back across, torso 10 deg); f3-f7 Expo In slash on an arc at neck height; f7-f10 Cubic Out follow-through past the body line; f10-f27 Cubic Out recover. Cancel f13 | `Hit` f7 (0.12) |
| MeleePunch (fists) | 0.40 | no | straight cross off a guard | f0-f2 Cubic Out hip load; f2-f6 Expo In punch (hips turn 20 first, shoulder +1 f, fist +1 f); f6-f9 hold-through; f9-f24 Cubic Out back to guard. Cancel f12 | `Hit` f6 (0.10) |
| QuickMeleeBash | 0.40 | no | **gun-butt bash**, gun hand(s) stay on the gun | f0-f3 Cubic Out pull the gun back 0.3 to the chest, muzzle up 40 deg; f3-f8 Expo In drive the butt / grip base forward and down at head height, hips turn 15, rear heel lifts; f8-f11 Cubic Out 0.15 further; f11-f24 Cubic Out back to Hold. Cancel f14. Rifle-class guns: a short buttstroke with the stock; pistols: the grip base (one clip now, per-prefix later if wanted) | `Hit` f8 (0.14) |
| MeleeKnifeHeavy NEW | 0.70 | no | overhead diagonal stab, weight transfer | f0-f10 Cubic Out big coil (knife high back, weight on the rear foot); f10-f17 Expo In drive down and across, step-in 0.4; f17-f22 Cubic Out through; f22-f42 Cubic Out recover. Cancel f23 | `Hit` f17 (0.28; code needs Heavy.HitDelay 0.28, Cooldown 0.9) |
| MeleeKnifeBackstab NEW | 0.60 | no | off hand on the shoulder, low stab | f0-f6 Cubic Out off hand reaches the target's shoulder height, knife low; f6-f10 Expo In stab forward-up; f10-f16 hold-push; f16-f22 Cubic Out pull out; f22-f36 Cubic Out recover | `Hit` f10 (0.17) |
| BatHold / BatEquip NEW | 1.0 loop / 0.35 | | bat on the right shoulder, two hands choked up, weight even | Equip f0-f10 Quart Out from low to shoulder, f10-f14 Back 4% | |
| BatSwing NEW | 0.75 | no | flat swing | f0-f5 Cubic Out load (hips coil back, bat back); f5-f10 Expo In swing (hips -> chest +1 f -> arms +1 f -> bat); f10-f16 Cubic Out wrap over the left shoulder; f16-f45 Cubic Out recover. Cancel f16 | `Hit` f10 (0.16) |
| BatChargeWindup NEW | 0.80 | no | = Charge.Time | f0-f30 Cubic Out deep coil, rear knee 25; f30-f48 hold with a 0.3 deg strain tremble (Sine) | |
| BatChargeHold NEW | 1.0 | yes | the wound pose, moving hold | | |
| BatSwingCharged NEW | 0.60 | no | released from the wound pose: no further anticipation | f0-f6 Expo In; f6-f14 through and around; f14-f36 recover | `Hit` f6 (code: HitDelay 0.1 from the charged pose) |
| KatanaHold / KatanaEquip NEW | 1.0 loop / 0.40 | | two-hand mid guard, blade 45 up, tip at throat height | Equip f0-f12 Quart Out, f12-f16 Back 4% | |
| KatanaSlash NEW | 0.65 | no | diagonal cut ending in a guard | f0-f3 Cubic Out raise; f3-f7 Expo In cut; f7-f28 = the parry window (Parry.Window 0.35): blade held across the front in a high guard, moving hold; f28-f39 Cubic Out back to mid guard. Cancel f28 | `Hit` f7 (0.12) |
| RiotShieldHold NEW | 1.0 | yes | shield forward on the off arm, leaning in 6, rear leg braced, gun hand at the shield edge | drift 0.3 | |
| RiotShieldBash NEW | 1.0 | no | shoulder drive | f0-f3 Cubic Out pull in 0.1; f3-f7 Expo In shove 0.6 forward, step; f7-f12 Cubic Out push; f12-f60 Cubic Out recover. Cancel f20 | `Hit` f7 (0.12) |
| RiotShieldImpact NEW | 0.25 | no | a bullet hits the shield | f0-f2 Linear jolt 0.08 back, 2 deg; f2-f15 Cubic Out | |
| RiotShieldBreak NEW | 0.60 | no | shield torn off the arm | f0-f4 arm thrown out; f4-f36 Cubic Out recover empty-handed | `DropGun` f4 (= shield) |

## 8. Gadgets
GadgetConfig plays throws / rolls at `AnimSpeed` 1.3: authored lengths stay; `Release` = ReleaseDelay x 1.3 in clip time.
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| SmokeHold | 1.0 | yes | grenade at the chest in the throw hand, off hand near, gun slung / lowered | drift | |
| SmokeThrow (+L) | 0.40 | no | overarm | f0-f4 Cubic Out wind back behind the head; f4-f9 Expo In throw; f9-f15 Cubic Out follow-through across to the off hip; f15-f24 Cubic Out recover | `Release` f9 (0.12 x 1.3 = 0.156) |
| SmokeRoll | 0.55 | no | underarm roll | f0-f8 Cubic Out dip and arm back; f8-f16 Cubic In swing low; f16-f24 Cubic Out rise through; f24-f33 recover | `Release` f16 (0.21 x 1.3 = 0.273) |
| FragPinPull NEW | 0.30 | no | press = cook starts (fuse 2.0 s) | f0-f5 Cubic Out off hand to the pin; f5-f8 Quart Out pull 0.3; f8-f12 flick the pin away; f8-f18 Cubic Out throw arm back into the cocked pose (= FragCook f0) | `Pin` f7 |
| FragCook NEW | 1.0 | yes | cocked overarm, weight on the rear foot, off arm pointing at the target | hold, 0.3 deg tremble; no build-up (the fuse UI tells the time) | |
| FragThrow (+L) NEW | 0.40 | no | as SmokeThrow, harder: longer follow-through, rear foot pivots | f0-f4, f4-f9 Expo In, f9-f17 through, f17-f24 | `Release` f9 |
| FlashThrow (+L) NEW | 0.40 | no | flatter, quicker arm; head turns away after the release | f0-f3 Cubic Out short wind; f3-f9 Expo In; f9-f14 through; head turns away 20 deg f12-f20 (eyes off the flash); f20-f24 | `Release` f9 |
| LandminePlace NEW | 0.90 | no | kneel, set it flat, arm it | f0-f12 Cubic InOut kneel (hips -1.2); f12-f20 Sine InOut set it down; f20-f22 Linear press; f22-f30 thumb the switch; f30-f54 Cubic InOut rise | `Placed` f22 (the code throws the mine today: needs a "place" path) |
| MedkitUse NEW | 2.5 | no | = ChannelTime; damage stops it (fade 0.1 from any frame) | f0-f12 Cubic Out gun lowered, off hand pulls the kit from the hip; f12-f22 Quart Out snap open; f24-f40 Sine InOut injector to the thigh; f40-f42 Linear press; f42-f48 hold; f48-f110 hold with a heavy-to-calm exhale (shoulders drop 0.04); f110-f130 Sine InOut stow; f130-f150 Cubic Out back to ready | `Open` f22, `Heal` f42 |

## 9. Cover (existing; finals keep the names and lengths)
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| CoverIdleTall (+L) | 1.0 | yes | back flat to the wall, gun low across the body, head 20 deg to the open side (light), knees soft | drift 0.6 chest, Sine | |
| CoverCrouch (+L) | 1.0 | yes | low crouch, shoulder against the cover, gun low across, head just under the top | drift | |
| CoverCrouchPeek (+L) | 1.0 | yes | crouched, leaned out past the edge, gun up at level aim (arms from the Hold) | drift 0.3 (steady to aim) | |
| CoverLookPos / Neg | 1.0 | yes | head + shoulders 25 deg toward the edge (keys UpperTorso + Neck only) | | |
| CoverShuffleTall | 0.60 | yes | side-step along the wall (legs only), CoverWalkSpeed 8 = 4.8 studs per cycle | lead foot contact f0, trail foot f18; hips bob 0.05; feet never cross | `Footstep` f0, f18 |
| CoverShuffleCrouch | 0.72 | yes | crouched side-step, 5.8 studs per cycle | contacts f0, f22 | `Footstep` f0, f22 |
| CoverBlindCorner (+L) | 1.0 | yes | gun arm curled round the edge, body hidden, head turned away 10 | drift | |
| CoverBlindCornerCrouch (+L) | 1.0 | yes | same, crouched | | |
| CoverBlindOver (+L) | 1.0 | yes | half-rise, gun over the top, off hand braced flat on the top (contact <= 0.05) | | |
| CoverBrace | 0.75 | no | near miss: tuck | f0-f3 Quart Out flinch (head down 15, shoulders up 0.05, gun pulled in); f3-f20 hold; f20-f45 Cubic Out back | |
| CoverDash | 0.48 | yes | crouched run at 24 studs/s = 11.5 studs per cycle, gun low | contacts f0, f14; flight f5-f9, f19-f23 | `Footstep` f0, f14 |
| CoverRoll | 0.50 | no | tactical shoulder roll | f0-f4 Cubic Out dip, f4-f20 roll (Linear spin on the curl, it's momentum), f20-f30 Cubic Out up to crouch | `Land` f20 |
| CoverVault | 0.55 | no | hand plant, legs side-swing (code plays it in VaultTime 0.344) | f0-f4 Cubic Out reach, f6 plant, f6-f20 Sine InOut legs over, f22 feet down, f22-f33 Cubic Out rise | `EdgeGrab` f6, `Land` f22 |
| CoverSneak | 1.2 | yes | slow crouched walk, 8 studs/s = 9.6 studs per cycle, heel-to-toe | contacts f0, f36 | `Footstep` f0, f36 |
| CoverPullUp, CoverLean* | final | | **done** (DONE.md) | | |

## 10. Locomotion (NEW unless noted; legs + hips only so the weapon Hold keeps the arms, except Sprint)
All directional cycles share **one length and phase** (right contact f0, left contact at half) so 8-way blending stays in step.
Authored speed given: code plays at `speed / authored`.
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| MoveRun (gun, the 10 studs/s base) | 0.70 | yes | tactical jog, 7 studs per cycle, chest counter-rotates (muzzle drift <= 1 deg aimed) | R contact f0, down f3, passing f10, up f14, L contact f21 (mirror); hips roll +-3.5, yaw +-5, bob 0.1 | `Footstep` f0, f21 |
| MoveWalkAim (aimed walk) | 1.0 | yes | 6 studs/s, heel-roll, knees bent 12, gliding upper body | R f0, L f30; bob 0.05 | `Footstep` f0, f30 |
| MoveStrafeLeft / Right | 0.70 | yes | 10 studs/s, hips open 12 toward the step, no foot crossing through | lead contact f0, trail f21 | `Footstep` |
| MoveBackpedal | 0.70 | yes | authored at 7.5 studs/s (stride -25%), weight over the toes, chest upright | R f0, L f21 | `Footstep` |
| MoveSprint (gun low, two-handed) | 0.50 | yes | 20 studs/s = 10 studs per cycle; gun low and canted 30 across the body, off arm on the handguard, head stable; keys arms | R f0, L f15, flight f5-f9 / f20-f24; hips roll +-5, bob 0.18 | `Footstep` f0, f15 |
| MoveSprintPistol | 0.50 | yes | pistol low at the chest (muzzle down), off arm pumping | as MoveSprint | `Footstep` |
| MoveStart | 0.25 | no | hips lead into the direction, then the first step | f0-f4 Cubic Out hips 0.1 forward, chest +4; f4-f8 step; contact f8 | `Footstep` f8 |
| MoveStop | 0.35 | no | plant, weight over the front foot, settle | contact f0; f0-f6 Cubic Out 3% past; f6-f21 Cubic Out settle; trail foot f10 | `Footstep` f0, f10 |
| TurnInPlaceLeft / Right (90) | 0.50 | no | head leads, feet step | head f0-f4, chest f2-f10, hips f6-f16 (Cubic InOut); foot lifts f6, plants f14, second foot f14-f24; code turns the root f4-f20 | `Footstep` f14, f24 |
| MoveLandHard | 0.45 | no | big fall: compress, recover | f0 contact (arrive Linear); f0-f4 Quart Out compress (knees 60, hips -0.8, chest +15); f4-f8 hold; f8-f22 Cubic InOut rise; f22-f27 settle. Cancellable into movement from f10 | `Land` f0 |
| MoveSlide (existing, now a loop) | 0.50 | yes | lead leg out, rear knee tucked, hips low (-1.4), torso back 15, off hand trailing near the floor, gun forward | Sine micro-bob 0.03 and 0.5 deg; f30 = f0 (Slide.Time 0.75 = 1.5 cycles; fade in 0.08, out 0.15) | |
| MoveCrouchIdle (existing) | 1.0 | yes | knees out, weight even, gun at the Hold | drift | |
| MoveCrouchWalk (existing) | 1.2 | yes | authored at 6 studs/s (CrouchWalkAnimSpeed) = 7.2 per cycle, bob half of the run | R f0, L f36 | `Footstep` f0, f36 |
| DiveAim | 1.0 | yes | separate pose: flat lunge, body pitched along the dive (DivePitch 62), legs together trailing, knees 20, arms out on the gun at level aim, head up | drift 0.5. Author it either fully pitched or upright: **tell systems which** (it must not get the 62 twice) | |
| MoveLimp (low health) | 0.84 | yes | injured left leg: short contact, hips drop on that side, chest leans over the good leg | good contact f0, injured contact f28 (28 / 22 split), injured foot stays under 4 f only | `Footstep` f0, f28 |
| BotLeanLeft / Right (existing) | 1.0 | yes | training bots, 2 joints only: keep | | |

## 11. Hit reactions and deaths
Reactions key LowerTorso / UpperTorso / Neck only (Action3, fade in 0, out 0.1) so the gun keeps working.
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| HitFlinch (existing, generic) | 0.30 | no | = HitFlinchF | | |
| HitFlinchF / B / L / R NEW | 0.30 | no | F: chest back 6, head back 4 at f3; B: chest forward 5, head forward f3; L / R: chest rolls 6 away and yaws 8 | f0 = rest, f2 peak (Linear), f2-f18 Cubic Out | |
| HitHeadshot NEW | 0.25 | no | head snaps back | f1 head back 18 (Linear), chest 6 at f2; f2-f15 Quint Out | |
| HitExplosionStagger NEW | 0.90 | no | thrown away from the blast, two steps | f0-f3 Linear thrown (torso 15, a step back); f3-f14 stumble, foot plants f14; f14-f30 smaller step; f30-f54 Cubic Out back to stance (code turns the root to the blast side) | `Footstep` f14, f30 |
| HitBurning NEW | 1.2 | yes | shoulders hunched, head turned away, off hand swats the shoulder twice per loop, gun lowered | swats f10-f16, f40-f46 Cubic Out; drift otherwise | |
| DeathForward NEW (shot from behind) | 1.2 | no | knees give, falls face down | f0-f3 Linear jolt forward; f3-f20 knees buckle (Quad In); f20-f40 Quad In fall; f40 ground; f40-f50 Cubic Out settle; last frame static | `DropGun` f6, `Ground` f40 |
| DeathBackward NEW (shot from the front) | 1.1 | no | chest thrown back, one step, falls on the back | f0-f2 Linear; f2-f14 back-step; f14-f36 Quad In fall; `Ground` f36; f36-f66 settle | `DropGun` f4, `Ground` f36 |
| DeathCrumple NEW (generic) | 1.4 | no | knees, then sideways | f0-f20 Cubic In knees; `Ground` (knees) f20; f20-f50 Quad In topple; `Ground` f50; f50-f84 settle | `DropGun` f12, `Ground` f50 |
| DeathHeadshot NEW | 0.8 | no | head snaps, straight down | f1 head back 25 Linear; f1-f30 Quad In drop (no step); `Ground` f30; f30-f48 settle | `DropGun` f2, `Ground` f30 |
| DeathExplosion NEW | 0.9 | no | thrown, then ragdoll | f0-f6 Linear thrown up and back; code switches to ragdoll at `Ragdoll` f12 | `DropGun` f1, `Ragdoll` f12 |

## 12. Idles, breathing, social, world
| Clip | Len | Loop | Key poses | Beats and easing | Markers |
|---|---|---|---|---|---|
| IdleFidgetShift NEW | 2.5 | no | weight to the other leg, shoulder roll | f0-f40 Sine InOut hips 0.08 over, f40-f90 shoulder roll, f90-f150 back | |
| IdleFidgetGunCheck NEW | 3.0 | no | glance at the gun, tilt to the mag | head leads f0-f8; gun tilt f8-f30 Cubic InOut; hold f30-f120; back f120-f180 | |
| IdleFidgetLook NEW | 3.0 | no | look over the left, then the right shoulder (neck light, chest helps 10) | f0-f30 left, f30-f80 hold, f80-f120 right, f120-f180 back | |
| BreatheCalm NEW | 4.0 | yes | UpperTorso + Neck only | inhale f0-f100 Sine InOut (chest up 1.2, shoulders 0.02), exhale f100-f240 Sine InOut | |
| BreatheHeavy NEW | 1.5 | yes | after a sprint / low stamina | inhale f0-f35, exhale f35-f90; chest 3, shoulders 0.05, head counter 1.5. Crossfade 0.4 to Calm after 3-5 s | |
| RoundReady NEW | 1.2 | no | low ready -> mag tap -> ready | f0-f12 head up first; f6-f22 Quart Out gun up to the chest; f22-f30 Linear off hand taps the mag base; f34-f50 Back Out 4% settle; f50-f72 hold | `Tap` f30 |
| Victory NEW | 3.0 | no (hold the last pose) | gun to low ready, exhale, look round, rest | f0-f24 Cubic Out lower; f24-f60 Sine InOut exhale (shoulders drop); f60-f120 head leads a look round; f120-f180 gun across the chest at rest | |
| Defeat NEW | 2.5 | no (hold the last pose) | head drops, gun hangs in one hand, a weight shift | f0-f20 Cubic Out head down; f20-f60 shoulders slump, off hand off the gun; f60-f150 Sine InOut weight shift | |
| DoorOpen NEW | 0.80 | no | off hand pushes, gun hand keeps the gun on line at the chest | f0-f10 Cubic Out reach; f12 contact; f12-f24 Cubic Out push with a short step (hips 0.3 forward); f24-f30 hold; f30-f48 Cubic InOut back to the gun | `Push` f12 (the door starts), `Footstep` f20 |

## Wiring notes for systems (what the code must add for these clips)
1. `<Prefix>ReloadEmpty`: play it when the mag is empty, at `AdjustSpeed(len / (ReloadTime x EmptyLen / ReloadLen))`
   (Pistol 1.9/1.5, SMG 2.3/1.9, Rifle 2.8/2.4), or set a `ReloadTimeEmpty` per gun. Sniper: `SniperReload` already includes the bolt.
2. Shotgun: Start (0.2) -> Shell x n (0.5 each) -> End / EndEmpty; Fire cuts in from any frame.
3. New prefixes `SMG`, `Rifle`, `Shotgun`, `Sniper` -> `AnimationSourcePrefix`; Sniper / Shotgun Fire block the next shot for the
   whole clip (FireInterval already 1.3 / 0.85).
4. `Grip` / `Holstered` markers move the gun between the hand and the holster / sling.
5. MeleeKnifeHeavy needs a config (`HitDelay 0.28`, `Cooldown 0.9`); bat charge = Windup -> ChargeHold -> SwingCharged.
6. FragPinPull on press (cook starts), FragCook while held, FragThrow on release; LandminePlace needs a place path.
7. Breathing over a weapon Hold can't come from a clip (the Hold keys the torso): add it on the Waist as a code layer with the
   BreatheCalm / Heavy numbers; the clips are for unarmed and lobby use.
8. DiveAim: say whether the code pitches the root (then the clip stays upright) or not.
