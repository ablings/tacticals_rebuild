# Weapon, melee and gadget animations: DONE (weapons animator, 2026-10-30)

Final gameplay clips authored in Blender on Edward's Starter Blocky rig (R15 pivots), gun parts keyed in the same action
on the remodelled guns (art/anim/guns, Motor6D per part). Pipeline: `art/anim/PIPELINE.md`. Sources:
`art/anim/weapons/blender/clips/*.py` -> `blender/sets/*.blend`. Install into a place copy: run
`art/anim/weapons/install_sources.lua` (all clips, markers, PublishedId). Captures: `captures/anim/weapons/`.
Grade: by HQ's fresh grader after this task (the task did not self-grade: HQ rule).

## Pistol (Pistol, Suppressed; Dual Pistols for now)

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| PistolDraw | 0.500 | no | Action | Grip 0.067 | - | ready to publish |
| PistolDrawLeft | 0.500 | no | Action | Grip 0.067 | - | ready to publish |
| PistolEquip | 0.350 | no | Action | - | - | ready to publish |
| PistolEquipLeft | 0.350 | no | Action | - | - | ready to publish |
| PistolFire | 0.150 | no | Action | ShellEject 0.017 | Slide, Trigger | ready to publish |
| PistolFireLeft | 0.150 | no | Action | ShellEject 0.017 | Slide, Trigger | ready to publish |
| PistolHold | 1.000 | yes | Action | - | - | ready to publish |
| PistolHoldLeft | 1.000 | yes | Action | - | - | ready to publish |
| PistolHolster | 0.450 | no | Action | Holstered 0.317 | - | ready to publish |
| PistolHolsterLeft | 0.450 | no | Action | Holstered 0.317 | - | ready to publish |
| PistolInspect | 3.000 | no | Action | SlideRack 2.000 | Slide | ready to publish |
| PistolInspectLeft | 3.000 | no | Action | SlideRack 2.000 | Slide | ready to publish |
| PistolLowered | 1.000 | yes | Action | - | - | ready to publish |
| PistolLoweredLeft | 1.000 | yes | Action | - | - | ready to publish |
| PistolReload | 1.500 | no | Action | MagOut 0.100, MagStowed 0.467, MagIn 0.767 | Mag, MagRelease | ready to publish |
| PistolReloadEmpty | 1.900 | no | Action | MagOut 0.100, MagHide 0.300, MagShow 0.317, MagIn 0.633, SlideRack 0.983 | Mag, MagRelease, Slide, SlideStop | ready to publish |
| PistolReloadEmptyLeft | 1.900 | no | Action | MagOut 0.100, MagHide 0.300, MagShow 0.317, MagIn 0.633, SlideRack 0.983 | Mag, MagRelease, Slide, SlideStop | ready to publish |
| PistolReloadLeft | 1.500 | no | Action | MagOut 0.100, MagStowed 0.467, MagIn 0.767 | Mag, MagRelease | ready to publish |

## Revolver

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| RevolverDraw | 0.550 | no | Action | Grip 0.067 | - | ready to publish |
| RevolverDrawLeft | 0.550 | no | Action | Grip 0.067 | - | ready to publish |
| RevolverEquip | 0.350 | no | Action | - | - | ready to publish |
| RevolverEquipLeft | 0.350 | no | Action | - | - | ready to publish |
| RevolverFire | 0.300 | no | Action | - | Crane, Cylinder, Hammer, Trigger | ready to publish |
| RevolverFireLeft | 0.300 | no | Action | - | Crane, Cylinder, Hammer, Trigger | ready to publish |
| RevolverHold | 1.000 | yes | Action | - | - | ready to publish |
| RevolverHoldLeft | 1.000 | yes | Action | - | - | ready to publish |
| RevolverHolster | 0.450 | no | Action | Holstered 0.317 | - | ready to publish |
| RevolverHolsterLeft | 0.450 | no | Action | Holstered 0.317 | - | ready to publish |
| RevolverInspect | 3.000 | no | Action | CylinderOpen 0.933, CylinderClosed 1.767 | Crane | ready to publish |
| RevolverInspectLeft | 3.000 | no | Action | CylinderOpen 0.933, CylinderClosed 1.767 | Crane | ready to publish |
| RevolverLowered | 1.000 | yes | Action | - | - | ready to publish |
| RevolverLoweredLeft | 1.000 | yes | Action | - | - | ready to publish |
| RevolverReload | 2.400 | no | Action | CylinderOpen 0.217, ShellEject 0.367, MagHide 0.533, ShellIn 1.200, CylinderClosed 1.650 | Crane, Cylinder, CylinderLatch, EjectorRod, Rounds | ready to publish |
| RevolverReloadLeft | 2.400 | no | Action | CylinderOpen 0.217, ShellEject 0.367, MagHide 0.533, ShellIn 1.200, CylinderClosed 1.650 | Crane, Cylinder, CylinderLatch, EjectorRod, Rounds | ready to publish |

## SMG (Mini Uzi)

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| SMGDraw | 0.500 | no | Action | Grip 0.083 | - | ready to publish |
| SMGDrawLeft | 0.500 | no | Action | Grip 0.083 | - | ready to publish |
| SMGEquip | 0.350 | no | Action | - | - | ready to publish |
| SMGEquipLeft | 0.350 | no | Action | - | - | ready to publish |
| SMGFire | 0.100 | no | Action | ShellEject 0.017 | Trigger | ready to publish |
| SMGFireLeft | 0.100 | no | Action | ShellEject 0.017 | Trigger | ready to publish |
| SMGHold | 1.000 | yes | Action | - | - | ready to publish |
| SMGHoldLeft | 1.000 | yes | Action | - | - | ready to publish |
| SMGHolster | 0.450 | no | Action | Holstered 0.300 | - | ready to publish |
| SMGHolsterLeft | 0.450 | no | Action | Holstered 0.300 | - | ready to publish |
| SMGInspect | 3.000 | no | Action | SlideRack 1.700 | CockingKnob | ready to publish |
| SMGInspectLeft | 3.000 | no | Action | SlideRack 1.700 | CockingKnob | ready to publish |
| SMGLowered | 1.000 | yes | Action | - | - | ready to publish |
| SMGLoweredLeft | 1.000 | yes | Action | - | - | ready to publish |
| SMGReload | 1.900 | no | Action | MagOut 0.167, MagStowed 0.567, MagIn 0.933 | Mag | ready to publish |
| SMGReloadEmpty | 2.300 | no | Action | SlideRack 1.333, MagHide 0.367, MagShow 0.383, MagOut 0.167, MagIn 0.933 | CockingKnob, Mag | ready to publish |
| SMGReloadEmptyLeft | 2.300 | no | Action | SlideRack 1.333, MagHide 0.367, MagShow 0.383, MagOut 0.167, MagIn 0.933 | CockingKnob, Mag | ready to publish |
| SMGReloadLeft | 1.900 | no | Action | MagOut 0.167, MagStowed 0.567, MagIn 0.933 | Mag | ready to publish |

## Rifle (Auto Rifle, Semi-Auto)

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| RifleDraw | 0.600 | no | Action | Grip 0.100 | - | ready to publish |
| RifleDrawLeft | 0.600 | no | Action | Grip 0.100 | - | ready to publish |
| RifleEquip | 0.350 | no | Action | - | - | ready to publish |
| RifleEquipLeft | 0.350 | no | Action | - | - | ready to publish |
| RifleFire | 0.120 | no | Action | ShellEject 0.017 | BoltCarrier, Trigger | ready to publish |
| RifleFireLeft | 0.120 | no | Action | ShellEject 0.017 | BoltCarrier, Trigger | ready to publish |
| RifleHold | 1.000 | yes | Action | - | - | ready to publish |
| RifleHoldLeft | 1.000 | yes | Action | - | - | ready to publish |
| RifleHolster | 0.600 | no | Action | Holstered 0.400 | - | ready to publish |
| RifleHolsterLeft | 0.600 | no | Action | Holstered 0.400 | - | ready to publish |
| RifleInspect | 3.000 | no | Action | SlideRack 2.100 | BoltCarrier, ChargingHandle, Mag | ready to publish |
| RifleInspectLeft | 3.000 | no | Action | SlideRack 2.100 | BoltCarrier, ChargingHandle, Mag | ready to publish |
| RifleLowered | 1.000 | yes | Action | - | - | ready to publish |
| RifleLoweredLeft | 1.000 | yes | Action | - | - | ready to publish |
| RifleReload | 2.400 | no | Action | MagOut 0.267, MagStowed 0.733, MagIn 1.167 | Mag, MagRelease | ready to publish |
| RifleReloadEmpty | 2.800 | no | Action | SlideRack 1.467, MagHide 0.500, MagShow 0.517, MagOut 0.267, MagIn 1.000 | BoltCarrier, ChargingHandle, Mag, MagRelease | ready to publish |
| RifleReloadEmptyLeft | 2.800 | no | Action | SlideRack 1.467, MagHide 0.500, MagShow 0.517, MagOut 0.267, MagIn 1.000 | BoltCarrier, ChargingHandle, Mag, MagRelease | ready to publish |
| RifleReloadLeft | 2.400 | no | Action | MagOut 0.267, MagStowed 0.733, MagIn 1.167 | Mag, MagRelease | ready to publish |

## Shotgun (Pump Shotgun)

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| ShotgunDraw | 0.650 | no | Action | Grip 0.100 | - | ready to publish |
| ShotgunDrawLeft | 0.650 | no | Action | Grip 0.100 | - | ready to publish |
| ShotgunEquip | 0.350 | no | Action | - | - | ready to publish |
| ShotgunEquipLeft | 0.350 | no | Action | - | - | ready to publish |
| ShotgunFire | 0.850 | no | Action | ShellEject 0.300, PumpClosed 0.467 | Pump, Trigger | ready to publish |
| ShotgunFireLeft | 0.850 | no | Action | ShellEject 0.300, PumpClosed 0.467 | Pump, Trigger | ready to publish |
| ShotgunHold | 1.000 | yes | Action | - | - | ready to publish |
| ShotgunHoldLeft | 1.000 | yes | Action | - | - | ready to publish |
| ShotgunHolster | 0.600 | no | Action | Holstered 0.400 | - | ready to publish |
| ShotgunHolsterLeft | 0.600 | no | Action | Holstered 0.400 | - | ready to publish |
| ShotgunInspect | 3.000 | no | Action | PumpClosed 1.767 | Pump | ready to publish |
| ShotgunInspectLeft | 3.000 | no | Action | PumpClosed 1.767 | Pump | ready to publish |
| ShotgunLowered | 1.000 | yes | Action | - | - | ready to publish |
| ShotgunLoweredLeft | 1.000 | yes | Action | - | - | ready to publish |
| ShotgunReloadEnd | 0.300 | no | Action | - | - | ready to publish |
| ShotgunReloadEndEmpty | 0.550 | no | Action | PumpClosed 0.417 | Pump | ready to publish |
| ShotgunReloadEndEmptyLeft | 0.550 | no | Action | PumpClosed 0.417 | Pump | ready to publish |
| ShotgunReloadEndLeft | 0.300 | no | Action | - | - | ready to publish |
| ShotgunReloadShell | 0.500 | no | Action | ShellIn 0.233 | LoadShell | ready to publish |
| ShotgunReloadShellLeft | 0.500 | no | Action | ShellIn 0.233 | LoadShell | ready to publish |
| ShotgunReloadStart | 0.200 | no | Action | - | - | ready to publish |
| ShotgunReloadStartLeft | 0.200 | no | Action | - | - | ready to publish |

## Sniper

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| SniperDraw | 0.750 | no | Action | Grip 0.117 | - | ready to publish |
| SniperDrawLeft | 0.750 | no | Action | Grip 0.117 | - | ready to publish |
| SniperEquip | 0.350 | no | Action | - | - | ready to publish |
| SniperEquipLeft | 0.350 | no | Action | - | - | ready to publish |
| SniperFire | 1.300 | no | Action | ShellEject 0.433, BoltClosed 0.683 | Bolt, Trigger | ready to publish |
| SniperFireLeft | 1.300 | no | Action | ShellEject 0.433, BoltClosed 0.683 | Bolt, Trigger | ready to publish |
| SniperHold | 1.000 | yes | Action | - | - | ready to publish |
| SniperHoldLeft | 1.000 | yes | Action | - | - | ready to publish |
| SniperHolster | 0.650 | no | Action | Holstered 0.433 | - | ready to publish |
| SniperHolsterLeft | 0.650 | no | Action | Holstered 0.433 | - | ready to publish |
| SniperInspect | 3.000 | no | Action | BoltClosed 1.833 | Bolt | ready to publish |
| SniperInspectLeft | 3.000 | no | Action | BoltClosed 1.833 | Bolt | ready to publish |
| SniperLowered | 1.000 | yes | Action | - | - | ready to publish |
| SniperLoweredLeft | 1.000 | yes | Action | - | - | ready to publish |
| SniperReload | 3.000 | no | Action | MagOut 0.300, MagStowed 0.833, MagIn 1.400, BoltClosed 2.033 | Bolt, Mag, MagRelease | ready to publish |
| SniperReloadLeft | 3.000 | no | Action | MagOut 0.300, MagStowed 0.833, MagIn 1.400, BoltClosed 2.033 | Bolt, Mag, MagRelease | ready to publish |
| SniperReloadTactical | 2.500 | no | Action | MagOut 0.300, MagStowed 0.833, MagIn 1.400 | Mag, MagRelease | ready to publish |
| SniperReloadTacticalLeft | 2.500 | no | Action | MagOut 0.300, MagStowed 0.833, MagIn 1.400 | Mag, MagRelease | ready to publish |

## Melee

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| MeleeKnifeBackstab | 0.600 | no | Action | Hit 0.167 | - | ready to publish |
| MeleeKnifeHeavy | 0.700 | no | Action | Hit 0.283 | - | ready to publish |
| MeleePunch | 0.400 | no | Action | Hit 0.100 | - | ready to publish |
| MeleeSlash | 0.450 | no | Action | Hit 0.117 | - | ready to publish |
| QuickMeleeBash | 0.400 | no | Action | Hit 0.133 | - | ready to publish |

## Bat

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| BatChargeHold | 1.000 | yes | Action | - | - | ready to publish |
| BatChargeWindup | 0.800 | no | Action | - | - | ready to publish |
| BatEquip | 0.350 | no | Action | - | - | ready to publish |
| BatHold | 1.000 | yes | Action | - | - | ready to publish |
| BatSwing | 0.750 | no | Action | Hit 0.167 | - | ready to publish |
| BatSwingCharged | 0.600 | no | Action | Hit 0.100 | - | ready to publish |

## Katana

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| KatanaEquip | 0.400 | no | Action | - | - | ready to publish |
| KatanaHold | 1.000 | yes | Action | - | - | ready to publish |
| KatanaSlash | 0.650 | no | Action | Hit 0.117 | - | ready to publish |

## Riot Shield

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| RiotShieldBash | 1.000 | no | Action | Hit 0.117 | - | ready to publish |
| RiotShieldBreak | 0.600 | no | Action | DropGun 0.067 | - | ready to publish |
| RiotShieldHold | 1.000 | yes | Action | - | - | ready to publish |
| RiotShieldImpact | 0.250 | no | Action | - | - | ready to publish |

## Gadgets

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| FlashThrow | 0.400 | no | Action | Release 0.150 | - | ready to publish |
| FlashThrowLeft | 0.400 | no | Action | Release 0.150 | - | ready to publish |
| FragCook | 1.000 | yes | Action | - | - | ready to publish |
| FragPinPull | 0.300 | no | Action | Pin 0.117 | - | ready to publish |
| FragThrow | 0.400 | no | Action | Release 0.150 | - | ready to publish |
| FragThrowLeft | 0.400 | no | Action | Release 0.150 | - | ready to publish |
| LandminePlace | 0.900 | no | Action | Placed 0.367 | - | ready to publish |
| MedkitUse | 2.500 | no | Action | Open 0.367, Heal 0.700 | - | ready to publish |
| SmokeHold | 1.000 | yes | Action | - | - | ready to publish |
| SmokeRoll | 0.550 | no | Action | Release 0.267 | - | ready to publish |
| SmokeThrow | 0.400 | no | Action | Release 0.150 | - | ready to publish |
| SmokeThrowLeft | 0.400 | no | Action | Release 0.150 | - | ready to publish |

## Wiring for systems (the animator does not edit game scripts)
1. **Prefixes.** `AnimationSourcePrefix`: Pistol / SilencedPistol / DualPistols -> `Pistol`; Revolver -> `Revolver`;
   MiniUzi -> `SMG`; AutoRifle / SemiAuto -> `Rifle`; PumpShotgun -> `Shotgun`; Sniper -> `Sniper`. Every prefix has
   Hold, Lowered, Equip, Fire, Reload (+Left) with the code's names; Reload is stretched by the code
   (`AdjustSpeed(len / ReloadTime)`) as now.
2. **Empty reloads.** `<Prefix>ReloadEmpty` (Pistol 1.9, SMG 2.3, Rifle 2.8 s) when the mag is empty, at
   `AdjustSpeed(len / (ReloadTime * EmptyLen / ReloadLen))`. Sniper: `SniperReload` (with the bolt) as now; optional
   `SniperReloadTactical` (no bolt) when a round is chambered. Revolver: one reload.
3. **Shotgun.** `ShotgunReloadStart` (0.2, = StartDelay) -> `ShotgunReloadShell` (0.5, = ShellTime, per shell) ->
   `ShotgunReloadEnd` / `ShotgunReloadEndEmpty`; a shot cuts in from any frame (fade 0.08). `ShotgunFire` (0.85) holds
   the pump cycle; block the next shot for the whole clip (FireInterval 0.85).
4. **Sniper.** `SniperFire` (1.3) holds the bolt cycle (off hand works the bolt: the gun is welded to the gun hand).
5. **Draw / Holster / Inspect.** `<Prefix>Draw` (Grip marker = move the gun from the holster / sling into the hand),
   `<Prefix>Holster` (Holstered marker = gun leaves the hand), `<Prefix>Inspect` (suggest key F). The existing
   `DrawHip` / `DrawBack` (body set) keep working; the per-prefix Draws are the gun-specific versions.
6. **Melee.** `QuickMeleeBash` (Hit 0.133) replaces the punch copy. Knife: `MeleeSlash` (Hit 0.117), `MeleeKnifeHeavy`
   (Hit 0.283: config HitDelay 0.28, Cooldown 0.9), `MeleeKnifeBackstab` (Hit 0.167). Fists `MeleePunch` (Hit 0.1).
   Bat: `BatHold`, `BatEquip`, `BatSwing` (Hit 0.167), charge = `BatChargeWindup` (0.8 = Charge.Time) -> `BatChargeHold`
   (loop) -> `BatSwingCharged` (Hit 0.1). Katana: `KatanaHold`, `KatanaEquip`, `KatanaSlash` (Hit 0.117; f7-f28 = the
   parry guard). Riot shield: `RiotShieldHold`, `RiotShieldBash` (Hit 0.117), `RiotShieldImpact` (on a blocked bullet),
   `RiotShieldBreak` (DropGun 0.067 = drop the shield). Set each item's `AnimationSource` to these names.
7. **Gadgets.** `SmokeHold` / `SmokeThrow` (+Left) / `SmokeRoll` as now; new: `FragPinPull` (press, Pin 0.117) ->
   `FragCook` (loop while held) -> `FragThrow` (+Left, Release 0.15); `FlashThrow` (+Left, Release 0.15);
   `LandminePlace` (Placed 0.367: needs a "place" path instead of the throw); `MedkitUse` (2.5 = ChannelTime; Open 0.367,
   Heal 0.7; damage cancels with fade 0.1). Throws keep `AnimSpeed` 1.3.
8. **Markers** (exact names): Hit, Release, Grip, Holstered, Placed, Pin, Open, Heal, DropGun (gameplay); MagOut, MagIn,
   MagStowed, SlideRack, BoltClosed, PumpClosed, ShellEject, ShellIn, CylinderOpen, CylinderClosed (sounds / FX).
   **MagHide / MagShow** (empty reloads, revolver dump): hide the gun's `Mag` (revolver: `Rounds`) at MagHide, show at
   MagShow, so the dropped mag doesn't jump back to the hand.
9. **Gun parts** need nothing in code: the Animator drives the remodel's Motor6Ds (Handle -> part) through the plain
   RightGrip weld (tested: Mag 0.30 down mid-strip, Slide 0.30 back on the fire peak). The `...Left` clips put the Handle
   pose under LeftHand to match `WeaponUtil.SetGunHand`.
10. **Priorities.** Holds / Lowered / cover-free idles: Action (the code already raises Reload / Fire / Equip to Action4).
    Set Draw / Holster / Inspect / melee / gadget one-shots to Action4 as well so they beat cover poses.

## Known limits (open)
- **Gun scale vs R15 reach.** R15 arms reach 1.73 studs from shoulders 1.94 apart; the remodelled long guns are 3.7-6.2
  studs (real proportions at about 1.6x R15 scale). With the stock in the shoulder the support hand can reach the
  magwell / receiver front, not the handguard: rifles and the sniper use a 56-60 deg bladed stance with the off hand at
  the magwell; the shotgun uses an underarm hold so the off hand can ride the pump. Scaling the long guns to ~0.7 would
  allow the textbook handguard grip: a modeler / Edward decision.
- Small reach gaps left (studs): PistolInspect 0.04, RevolverInspect 0.06, BatEquip 0.03 (one moment
  each, off hand short of the gun while it moves).
- Neck: shouldered holds turn the head 15 deg back toward the aim; HeadLookController adds the rest.
