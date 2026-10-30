# Reload variants by rounds left: RIVALS reference (measured 2026-10-30)

Edward (2026-10-30): "certain items have the same reload time, like in RIVALS ... the revolver's reload animation changes depending
on how many bullets are in it but it's still the same speed: a cool visual change. Add this."

**How it was measured.** RIVALS live, Shooting Range ("Try out any weapon here for free"), first person, Edward's account.
Each reload is its own burst (`feed.ps1 act -burst`, 30-35 fps, timestamps in ms; ±30 ms per frame).
Times run from the **first frame the viewmodel starts the reload** to the frame it **settles back in the hold** (ready to fire),
plus the frame where the **HUD ammo count refills**. The R press itself isn't in the frames; on an empty mag RIVALS reloads by itself
right after the last shot. Frames: `roblox_kits/out/captures/rivals_reload_1030/` (git-ignored; `labels.txt` maps bursts to counts).
Grids: `sheets/*_grid.jpg`. Contact sheet: `notes/reload_variants_sheet.jpg`. We learn timing and method only; nothing is copied.

## Results per gun

| RIVALS gun (mag) | Counts tested (rounds left) | Reload, start to settled | Ammo refills at | Same length? | What changes visually |
|---|---|---|---|---|---|
| **Revolver (6)** | 5, 4, 3, 2, 1 left (1-5 spent) | **3.10-3.13 s** (all five) | +1.87-1.97 s | **yes, 1-5 spent are identical in timing** | the cylinder face shows the **live rounds still in it** (brass dots), and tipping the muzzle up **dumps exactly those live rounds** (5 fall at 1 spent ... 1 falls at 5 spent). Speed-loader with 6 every time |
| Revolver | 0 left (6 spent, auto) | **2.05-2.09 s** | +1.14 s | **no: about 1.0 s shorter** | nothing to dump: no muzzle-up beat, straight from cylinder-out to the speed-loader |
| Assault Rifle (20) | 19, 10, 1, 0 | 2.96-3.02 s | +2.16-2.23 s | yes | **none**: one clip for every count, empty included (no charging handle) |
| Burst Rifle (12, 3 per pull) | 9, 6, 3, 0 | 2.43-2.46 s | | yes | none (the "empty" burst measured 2.72 s only because it began with the last 3-round burst) |
| Handgun (13) | 12, 6, 1, 0 | 1.80 s (0 left: 1.74 s from the last shot) | | yes | none: mag drops free and a new one is slapped in every time; no slide-lock variant |
| Uzi (27) | 26, 14, 0 | 1.85-1.87 s | | yes | none |
| Sniper (4) | 3, 2, 1 | 2.52-2.54 s | | yes, 1-3 left | mag swap only, **no bolt work** (a round is still chambered) |
| Sniper | 0 (auto) | ~3.5 s from the last shot (bolt cycle after the shot, then the swap) | | **no** | the last shot's bolt cycle runs first (casing flies), then the swap with the hand back on the bolt at the end |
| Shotgun (7, pump, shell by shell) | 6, 3, 1, 0 | per shell **0.46 s** after the first | first shell +0.5 s after R | per shell yes; total grows with shells | **from empty only:** the first shell goes **into the ejection port** and the pump is racked (**+1.3 s**: 1st shell at +0.95 s, 2nd at +2.26 s), then the tube as usual. With shells left: straight to the tube |
| Energy Pistols (dual) | 10 shots, then R | no reload (energy, endless ammo) | | n/a | RIVALS has **no dual-magazine reload** to study; our Dual Pistols design is our own |
| (not owned/needed: Shorty, Daggers, Flare Gun, Spray, Exogun, Slingshot) | | | | | |

## What this means

1. **Only one RIVALS gun really varies by count: the revolver.** Its trick is cheap and readable: **one clip, one timing, and the
   number of live rounds that fall out matches the rounds you had left**. The live rounds are visible in the cylinder face right
   after it swings out, so the count reads twice (before and during the dump). Everything else in the clip is identical across 1-5
   spent, so the total time cannot drift.
2. **"Same time" holds for every partial count; empty is the exception.** Revolver empty is ~1 s **faster** (no dump), sniper empty
   and shotgun empty are **slower** (bolt / port load + pump). RIVALS doesn't hide the empty difference; it is a real mechanical beat.
3. **Magazine guns don't vary at all** (rifle, burst, handgun, Uzi): one clip, mag dropped free every time. Nothing is "hidden"
   because nothing differs.
4. **How the revolver keeps the time fixed:** the varying part is a **physics-like drop of N props inside a fixed beat** (the
   muzzle-up hold, ~0.45 s, the same for every count). The hands do the same thing; only the props differ. No faster hands, no
   skipped beats between 1 and 5 spent.

## Tacticals now (the design is `notes/reload_variants_design.md`)
- Runtime `ReloadTime` (WeaponConfig, read from a copy of `match_place_ref.rbxl` 2026-10-30; the `[ABILITY]` block overrides the table):
  Pistol **1.3**, Dual Pistols **1.4**, Suppressed **1.5**, Mini Uzi **1.7**, Revolver **2.0**, Automatic Rifle **2.2**,
  Semi-Auto **2.5**, Sniper **3.0**; Pump Shotgun = ShellReload `StartDelay 0.2` + `ShellTime 0.5` per shell.
- Magazines: Pistol 12, Dual Pistols 24, Suppressed 10, Mini Uzi 30, Revolver 6, Auto Rifle 30, Pump 6, Semi-Auto 12, Sniper 5.
- The client plays the reload clip with `AdjustSpeed(track.Length / ReloadTime)`, so any clip fits the time; the design authors
  each variant at **exactly** `ReloadTime x 60` frames so the speed is 1.0 and the beats land where they are keyed.
