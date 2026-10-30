# Reload variants by rounds left: Tacticals design (2026-10-30)

Reference and measurements: `notes/reload_variants_ref.md` (+ `notes/reload_variants_sheet.jpg`). Style: vault
`05 Animation/Animation Styles/Grounded Tactical.md` (section 7 and "Ammo-aware reloads at a fixed length").

## Rules for every variant
1. **The length never changes.** Every variant of a gun is authored at exactly `ReloadTime x 60` frames, so
   `AdjustSpeed(track.Length / ReloadTime)` is 1.0. Server timing, ammo refill and the cancel rule stay as they are.
2. **Shared anchors.** All variants of a gun put `MagOut` / `MagIn` (or `CylinderOpen` / `ShellIn` / `CylinderClosed`) on the
   **same frames** and share their first 6 frames (the tilt), so the sounds, the HUD and a cancel feel the same whatever the count.
   Only the window between the anchors changes.
3. **How the time is kept** (from the reference): the varying part is **props inside a fixed beat** (how many rounds fall, how many
   casings are plucked); where a variant needs fewer actions, the hands go **slower with a head lead / look** in the same window,
   never a frozen hold; where it needs more (slide, knob, handle, bolt), it **drops the mag free instead of stripping it** to pay
   for them. Every variant settles at least 6 f before the end; the end is a moving hold.
4. **Picking the variant:** the client reads the rounds left at the reload start (`getAmmo()` before `ReloadWeapon:FireServer()`)
   and plays `<Prefix>Reload<Variant>`; missing clip = the current `<Prefix>Reload`. Proposed config:
   `ReloadVariants = { {Max = 0, Clip = "Dry"}, {Max = 5, Clip = "Drop"}, ... }` (first row whose `Max >= rounds left`).
5. Easing and part timing follow Grounded Tactical section 7 (mag out Cubic Out, seat Linear 2 f + 2 f hold, slide forward Quad In 2 f
   hard stop, knob / handle back Cubic Out 4 f, bolt per its row). Cancel = before `MagIn` / `ShellIn`, as now.

## Variant table (frames at 60 fps, f0 = first frame)

### Revolver: 2.0 s = **120 f**, 6 rounds (Edward's main ask: every count looks different)
Anchors for all: f0-f6 Cubic Out tilt 30 deg left, off hand under the frame; f6-f8 thumb latch; Cylinder out f8-f13 Cubic Out 90 deg
(`CylinderOpen` f13); f13-f20 Cubic Out the cylinder face turns to the camera with a head lead (the live rounds read as brass,
spent as dark primers); **`ShellIn` f80** (last round in); hand back f80-f90; **`CylinderClosed` f96** (wrist flick Quart Out 3 f,
no Back); f96-f99 hold; f99-f110 Quart Out up; f110-f120 hold.

| Rounds left (spent) | Variant clip | Window f20-f80 | Gun parts |
|---|---|---|---|
| 5 (1 spent) | `RevolverReloadPluck1` | pluck: thumbnail under the rim f20-f25 Cubic Out, casing out and flicked away f25-f30 (`ShellEject` f25); off hand to the belt loop f30-f56 Sine InOut (slow, head follows); single round to the chamber f56-f74; press f74-f80 Cubic Out (`ShellIn` f80); **f80-f90 thumb spins the cylinder two free turns (Quad Out)**, then the flick close at f90-f96 | `Round1` out/in; `LooseRound` hand prop shown f40-f80 |
| 4 (2 spent) | `RevolverReloadPluck2` | pluck 1 f20-f28 (`ShellEject` f24); index 1/6 turn f28-f31 Quad In; pluck 2 f31-f39 (`ShellEject` f35); belt f39-f52; round 1 in f52-f62 (`ShellIn` f62); index f62-f65; round 2 f65-f80 (`ShellIn` f80); spin f80-f90; close f90-f96 | `Round1`, `Round2`, `LooseRound` |
| 3 (3 spent) | `RevolverReloadDump` | muzzle up 60 deg f20-f26 Cubic Out; ejector stroke f26-f30 Linear (`ShellEject` f28): **3 brass live rounds + 3 dark casings fall**; muzzle down f30-f40; off hand to the belt f40-f54 (speed-loader); loader to the cylinder f54-f74 Sine InOut; insert f74-f78 Linear; twist f78-f80 (`ShellIn` f80); loader hidden f82 | `Ejector`, `Round1-6`, `SpeedLoader` prop |
| 2 (4 spent) | `RevolverReloadDump` | same clip; the code shows 2 live + 4 spent | same |
| 1 (5 spent) | `RevolverReloadDump` | same clip; 1 live + 5 spent | same |
| 0 (6 spent) | `RevolverReloadDry` | **hard slap**: muzzle up f20-f24 Cubic Out (faster), palm slams the ejector f24-f26 (`ShellEject` f25), 6 dark casings spray; off hand to the belt f26-f44 (unhurried, head lead to the loader); loader to the cylinder f44-f74 Sine InOut; insert f74-f78; twist f78-f80 (`ShellIn` f80); loader hidden f82; **close with a half-turn spin before the latch** f90-f96 | `Ejector`, `Round1-6`, `SpeedLoader` |

**Model need (answers the animator):** yes, split `Rounds` into **`Round1`..`Round6`** (Motor6D to `Cylinder`, one per chamber,
in firing order) so single rounds can be plucked and loaded, plus props `LooseRound` and `SpeedLoader` (shown / hidden by markers).
The code gives each `RoundN` its look at the reload start: live = brass with a tip, spent = casing only / dark primer
(`Transparency` of a `Tip` child, or a second mesh). The falling dump uses `WeaponEffects.DropCasings` at the `ShellEject` marker
(today it fires at a fixed 0.5 s): spent count as casings, live count as live rounds. Fire order makes the spent chambers consecutive,
so Pluck1/Pluck2 always pluck `Round1` (and `Round2`) after the index turn the fire clip already does.

### Pistol: 1.3 s = **78 f**, 12 rounds
Anchors: f0-f6 Cubic Out tilt 20 deg to the off hand, down 0.15; **`MagOut` f6** (thumb release); **`MagIn` f42** (Linear seat f40-f42);
settled by f62; f62-f78 moving hold.

| Rounds left | Variant | Window f6-f62 | Gun parts |
|---|---|---|---|
| 7-11 | `PistolReloadRetain` | off hand strips the mag f6-f12 Cubic Out; to the hip pouch f12-f24 Sine InOut (`MagStowed` f24); new mag f24-f40; seat; f42-f44 hold; f44-f62 Quart Out up, rewrap f50-f58 | `MagBase` |
| 1-6 | `PistolReloadDrop` | mag drops free f6-f16 Quad In (hide f16); off hand to the pouch f6-f14; new mag f14-f40 with a look at the well (head lead f28); seat; f42-f44 hold; **press check**: Slide back 0.12 f44-f47 Cubic Out, hold f47-f50, forward f50-f52 Quad In; f52-f62 Quart Out up | `MagBase`, `Slide` |
| 0 | `PistolReloadDry` | Slide locked back from f0; mag drops free f6-f16; new mag f14-f40; seat; f42-f46 hold; **thumb hits the slide stop: Slide forward f46-f48 Quad In hard stop** (`SlideRack` f48); f48-f62 Quart Out up, recoil-like 1 deg settle | `MagBase`, `Slide` |

### Suppressed: 1.5 s = **90 f**, 10 rounds (shares the `Pistol` prefix)
The same three clips **authored at 90 f** (every Pistol frame x 90/78 = 1.154, rounded): `MagOut` f7, `MagStowed` f28, `MagIn` f48,
press check f51-f60, slide stop f53-f55 (`SlideRack` f55), settled f72, hold to f90. Ranges: **Retain 6-9, Drop 1-5, Dry 0.**
If the clips are shared with the Pistol instead, the code's AdjustSpeed plays them at 78/90 (0.87): same beats, still exact.

### Dual Pistols: 1.4 s = **84 f**, 24 rounds (12 per gun; RIVALS has no reference, our own design)
Anchors: f0-f6 both guns tilt in toward each other 15 deg; **`MagOut` f6**; **`MagIn` f32** (last mag seated); settled by f66.
Reload method: each gun hand pushes its gun **down onto a mag held upright in a thigh carrier** (no free hand).

| Rounds left | Variant | Window | Gun parts |
|---|---|---|---|
| 12-23 | `DualReloadStagger` | **overlap**: right gun mag drops f6-f16, right gun down to the thigh f6-f24, seat f24-f26 (`MagIn` f26 right), up f26-f44; left gun starts at f14: drop f14-f24, down f14-f30, seat f30-f32 (`MagIn` f32), up f32-f50; the guns are never both down; f50-f66 settle, small cross-check look | `MagBaseR/L` |
| 1-11 | `DualReloadPair` | both mags drop free together f6-f16; both guns down f6-f30 (a look down f12); both seat f30-f32 (`MagIn` f32); **two heel taps** of the guns on the thigh f32-f40; up f40-f66 Quart Out | `MagBaseR/L` |
| 0 | `DualReloadDry` | both slides locked back from f0; drop together; both seat f32; **slides released by the thumbs staggered: right f38-f40, left f40-f42 Quad In** (`SlideRack` f40, f42: a double click); up f42-f66 | `MagBaseR/L`, `SlideR/L` |
Rig need: split the dual model's slides and mag bases per gun (`SlideR`, `SlideL`, `MagBaseR`, `MagBaseL`).

### Mini Uzi: 1.7 s = **102 f**, 30 rounds (mag in the grip)
Anchors: f0-f6 tilt 25 deg; f6-f10 off hand to the grip base; **`MagOut` f10**; **`MagIn` f56** (seat + heel slap f54-f56); settled by f92.

| Rounds left | Variant | Window f10-f92 | Gun parts |
|---|---|---|---|
| 16-29 | `SMGReloadRetain` | strip f10-f16; stow f16-f34 (`MagStowed` f34); new mag f34-f54; f56-f60 hold; off hand to the front f60-f78 Cubic InOut; up f78-f92 Quart Out | `Mag` |
| 1-15 | `SMGReloadDrop` | drops free f10-f22 (hide f22); off hand to the pouch f10-f24; new mag f24-f54 (look at the grip f40); f56-f60 hold; **tug** f60-f66 (Mag down 0.03 and back, Cubic Out); off hand to the front f66-f80; up f80-f92 | `Mag` |
| 0 | `SMGReloadDry` | as Drop to f56; off hand over the top f58-f66; CockingKnob back f66-f70 Cubic Out, hold f70-f72, forward f72-f74 Quad In (`SlideRack` f74); off hand to the front f74-f82; up f82-f92 | `Mag`, `CockingKnob` |

### Automatic Rifle: 2.2 s = **132 f**, 30 rounds
Anchors: f0-f8 roll 25 deg right, muzzle -10; f4-f14 off hand to the mag; **`MagOut` f16**; **`MagIn` f70** (rock in f66-f70); settled by f120.

| Rounds left | Variant | Window f16-f120 | Gun parts |
|---|---|---|---|
| 16-29 | `RifleReloadRetain` | strip f16-f24; to the chest pouch f24-f44 (`MagStowed` f44); new mag front lip first f44-f66; f70-f74 hold; tug f74-f80; off hand to the handguard f80-f96; shoulder f96-f120 Quart Out | `Mag`+`MagBase` |
| 1-15 | `RifleReloadDrop` | drops free f16-f30; off hand to the pouch f16-f32; new mag f32-f66 (look f46); f70-f74 hold; tug f74-f80; **heel tap on the base** f80-f86; to the handguard f86-f100; shoulder f100-f120 | `Mag`+`MagBase` |
| 0 | `RifleReloadDry` | as Drop to f74; off hand to the ChargingHandle f74-f86; back f86-f90 Cubic Out, hold f90-f92, forward f92-f94 Quad In (`SlideRack` f94); to the handguard f94-f106; shoulder f106-f120 | `Mag`+`MagBase`, `ChargingHandle` |

### Semi-Auto: 2.5 s = **150 f**, 12 rounds (shares the `Rifle` prefix)
Rifle frames x 150/132 (1.136): `MagOut` f18, `MagStowed` f50, `MagIn` f80, tug f84-f91, tap f91-f98, `SlideRack` f107, settled f136,
hold to f150. Ranges: **Retain 7-11, Drop 1-6, Dry 0.** Shared clips at AdjustSpeed 132/150 are also exact.

### Sniper: 3.0 s = **180 f**, 5 rounds
Anchors: f0-f10 off the cheek, roll 15, weight back; f10-f16 off hand to the Mag; **`MagOut` f18**; **`MagIn` f84** (seat f80-f84);
settled by f160.

| Rounds left | Variant | Window f18-f160 | Gun parts |
|---|---|---|---|
| 1-4 (a round is chambered) | `SniperReloadTopUp` | strip f18-f26; stow f26-f50 (`MagStowed` f50); new mag f50-f80; seat; f84-f88 hold; **thumb runs across the top round** f88-f100 (count check, head lead f86); off hand back f100-f120; remount f120-f144 Quart Out; cheek weld settle f144-f160 | `Mag` |
| 0 | `SniperReloadDry` | drops free f18-f30; off hand to the pouch f18-f34; new mag f34-f80; seat; f84-f88 hold; gun hand to the bolt f88-f98; up f98-f102 Cubic Out, back f102-f110 Quart Out, hold f110-f113, forward f113-f119 Cubic In, down f119-f122 Quart Out (`BoltClosed` f122); hand to the grip f122-f134; remount f134-f154; settle f154-f160 | `Mag`, `BoltArm`+`BoltKnob` |

### Pump Shotgun: shell by shell, **StartDelay 0.2 s = 12 f, ShellTime 0.5 s = 30 f per shell**
The per-shell rhythm stays fixed (that is what keeps the time); the count shows in **which shell clip plays**.

| When | Clip | Length | Beats | Markers |
|---|---|---|---|---|
| start, shells left | `ShotgunReloadStart` (as now) | 12 f | f0-f12 Cubic Out roll belly up 70 deg, off hand to the belt | |
| start, **empty** | `ShotgunReloadStartDry` NEW | 12 f | f0-f12 Cubic Out roll **port up** 40 deg instead, off hand to the belt | |
| 1st shell when **empty** | `ShotgunReloadShellPort` NEW | 30 f | shell into the **ejection port** f0-f8 Sine InOut, thumb drops it in f8-f12 Cubic Out (`ShellIn` f12); hand to the Pump f12-f14; Pump back f14-f18 Quart Out, hold f18-f20, forward f20-f25 Cubic In (`PumpClosed` f25); f25-f30 roll to belly up (= the shell clip's start pose) | `ShellIn` f12, `PumpClosed` f25 |
| every other tube shell | `ShotgunReloadShell` (as now) / `ShotgunReloadShellB` NEW | 30 f | A: from the belt (as now, `ShellIn` f14); B: from the **receiver side-saddle**, shorter reach f0-f8, push f8-f12, a thumb press on the gate f12-f16 (`ShellIn` f14) | `ShellIn` f14 |
| the shell that fills the tube | `ShotgunReloadShellLast` NEW | 30 f | as A to f16, then a palm slap on the loading gate f16-f20 Cubic Out | `ShellIn` f14 |
| end | `ShotgunReloadEnd` (as now) | 18 f | roll back, off hand to the Pump, shoulder. **`ReloadEndEmpty` is no longer needed**: the pump moved to the port shell, so the end is the same for every count | |
A shot still cuts any shell clip (fade 0.08). Code: pick `ShellPort` for the first shell when the reload started at 0; `ShellLast`
when ammo + 1 == MagazineSize; otherwise alternate A / B.

## Summary table (for the animator and the code)

| Gun | Length | Variants (rounds left) | Shared anchors |
|---|---|---|---|
| Pistol | 78 f | Retain 7-11, Drop 1-6, Dry 0 | MagOut f6, MagIn f42 |
| Dual Pistols | 84 f | Stagger 12-23, Pair 1-11, Dry 0 | MagOut f6, MagIn f32 |
| Suppressed | 90 f | Retain 6-9, Drop 1-5, Dry 0 | MagOut f7, MagIn f48 |
| Mini Uzi | 102 f | Retain 16-29, Drop 1-15, Dry 0 | MagOut f10, MagIn f56 |
| Revolver | 120 f | Pluck1 5, Pluck2 4, Dump 1-3 (shows the live count), Dry 0 | CylinderOpen f13, ShellIn f80, CylinderClosed f96 |
| Automatic Rifle | 132 f | Retain 16-29, Drop 1-15, Dry 0 | MagOut f16, MagIn f70 |
| Pump Shotgun | 12 f + 30 f per shell + 18 f | StartDry + ShellPort when 0; Shell A / B alternating; ShellLast | ShellIn f14 (port: f12) |
| Semi-Auto | 150 f | Retain 7-11, Drop 1-6, Dry 0 | MagOut f18, MagIn f80 |
| Sniper | 180 f | TopUp 1-4, Dry 0 | MagOut f18, MagIn f84 |

Already built by the animator at the old base lengths (tactical / empty for pistol, SMG, rifle, sniper): re-time them to the lengths
above (Retain = their tactical, Dry = their empty) and add the Drop middle variant; revolver, shotgun and dual pistols are new from
this table.
