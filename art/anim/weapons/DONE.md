# Weapon, melee and gadget animations: DONE (weapons animator, 2026-10-30)

Final gameplay clips authored in Blender on Edward's Starter Blocky rig (R15 pivots), gun parts keyed in the same action
on the remodelled guns (art/anim/guns, Motor6D per part). Pipeline: `art/anim/PIPELINE.md`. Sources:
`art/anim/weapons/blender/clips/*.py` -> `blender/sets/*.blend`. Install into a place copy: run
`art/anim/weapons/install_sources.lua` (all clips, markers, PublishedId). Captures: `captures/anim/weapons/`.
Grade: by HQ's fresh grader after this task (the task did not self-grade: HQ rule).

## Pistol (Pistol, Suppressed; Dual Pistols for now)

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| PistolDraw | 0.500 | no | Action | Grip 0.067 | - | rbxassetid://80232420828725 |
| PistolDrawLeft | 0.500 | no | Action | Grip 0.067 | - | rbxassetid://96260774350384 |
| PistolEquip | 0.350 | no | Action | - | - | rbxassetid://83717542980803 |
| PistolEquipLeft | 0.350 | no | Action | - | - | rbxassetid://74502752538202 |
| PistolFire | 0.150 | no | Action | ShellEject 0.017 | Slide, Trigger | rbxassetid://114235040459903 |
| PistolFireLeft | 0.150 | no | Action | ShellEject 0.017 | Slide, Trigger | rbxassetid://87443244353722 |
| PistolHold | 1.000 | yes | Action | - | - | rbxassetid://131122542166969 |
| PistolHoldLeft | 1.000 | yes | Action | - | - | rbxassetid://119968798290830 |
| PistolHolster | 0.450 | no | Action | Holstered 0.317 | - | rbxassetid://108643507786538 |
| PistolHolsterLeft | 0.450 | no | Action | Holstered 0.317 | - | rbxassetid://93088259789896 |
| PistolInspect | 3.000 | no | Action | SlideRack 2.000 | Slide | rbxassetid://110728355727310 |
| PistolInspectLeft | 3.000 | no | Action | SlideRack 2.000 | Slide | rbxassetid://126756538378000 |
| PistolLowered | 1.000 | yes | Action | - | - | rbxassetid://91860946318810 |
| PistolLoweredLeft | 1.000 | yes | Action | - | - | rbxassetid://106755195979108 |
| PistolReload | 1.500 | no | Action | MagOut 0.100, MagStowed 0.467, MagIn 0.767 | Mag, MagRelease | rbxassetid://114211152566042 |
| PistolReloadEmpty | 1.900 | no | Action | MagOut 0.100, MagHide 0.300, MagShow 0.317, MagIn 0.633, SlideRack 0.983 | Mag, MagRelease, Slide, SlideStop | rbxassetid://120332754928071 |
| PistolReloadEmptyLeft | 1.900 | no | Action | MagOut 0.100, MagHide 0.300, MagShow 0.317, MagIn 0.633, SlideRack 0.983 | Mag, MagRelease, Slide, SlideStop | rbxassetid://111595947017416 |
| PistolReloadLeft | 1.500 | no | Action | MagOut 0.100, MagStowed 0.467, MagIn 0.767 | Mag, MagRelease | rbxassetid://110772761770787 |

## Revolver

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| RevolverDraw | 0.550 | no | Action | Grip 0.067 | - | rbxassetid://137615061884872 |
| RevolverDrawLeft | 0.550 | no | Action | Grip 0.067 | - | rbxassetid://101399842974512 |
| RevolverEquip | 0.350 | no | Action | - | - | rbxassetid://78137459252992 |
| RevolverEquipLeft | 0.350 | no | Action | - | - | rbxassetid://96773594810409 |
| RevolverFire | 0.300 | no | Action | - | Crane, Cylinder, Hammer, Trigger | rbxassetid://96569480809706 |
| RevolverFireLeft | 0.300 | no | Action | - | Crane, Cylinder, Hammer, Trigger | rbxassetid://96510437596983 |
| RevolverHold | 1.000 | yes | Action | - | - | rbxassetid://131803146211146 |
| RevolverHoldLeft | 1.000 | yes | Action | - | - | rbxassetid://122097458651666 |
| RevolverHolster | 0.450 | no | Action | Holstered 0.317 | - | rbxassetid://140424628985078 |
| RevolverHolsterLeft | 0.450 | no | Action | Holstered 0.317 | - | rbxassetid://118987128110233 |
| RevolverInspect | 3.000 | no | Action | CylinderOpen 0.933, CylinderClosed 1.767 | Crane | rbxassetid://102925820514647 |
| RevolverInspectLeft | 3.000 | no | Action | CylinderOpen 0.933, CylinderClosed 1.767 | Crane | rbxassetid://138933318528541 |
| RevolverLowered | 1.000 | yes | Action | - | - | rbxassetid://115907369926018 |
| RevolverLoweredLeft | 1.000 | yes | Action | - | - | rbxassetid://111535700787252 |
| RevolverReload | 2.400 | no | Action | CylinderOpen 0.217, ShellEject 0.367, MagHide 0.533, ShellIn 1.200, CylinderClosed 1.650 | Crane, Cylinder, CylinderLatch, EjectorRod, Rounds | rbxassetid://126713514899794 |
| RevolverReloadLeft | 2.400 | no | Action | CylinderOpen 0.217, ShellEject 0.367, MagHide 0.533, ShellIn 1.200, CylinderClosed 1.650 | Crane, Cylinder, CylinderLatch, EjectorRod, Rounds | rbxassetid://94477885226897 |

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
| RifleDraw | 0.600 | no | Action | Grip 0.100 | - | rbxassetid://78876167227147 |
| RifleDrawLeft | 0.600 | no | Action | Grip 0.100 | - | rbxassetid://70991514496637 |
| RifleEquip | 0.350 | no | Action | - | - | rbxassetid://116998767148437 |
| RifleEquipLeft | 0.350 | no | Action | - | - | rbxassetid://130002492421194 |
| RifleFire | 0.120 | no | Action | ShellEject 0.017 | BoltCarrier, Trigger | rbxassetid://111037178563294 |
| RifleFireLeft | 0.120 | no | Action | ShellEject 0.017 | BoltCarrier, Trigger | rbxassetid://134297281110341 |
| RifleHold | 1.000 | yes | Action | - | - | rbxassetid://76751408627265 |
| RifleHoldLeft | 1.000 | yes | Action | - | - | rbxassetid://99702035736726 |
| RifleHolster | 0.600 | no | Action | Holstered 0.400 | - | rbxassetid://75035408703914 |
| RifleHolsterLeft | 0.600 | no | Action | Holstered 0.400 | - | rbxassetid://108383560587785 |
| RifleInspect | 3.000 | no | Action | SlideRack 2.100 | BoltCarrier, ChargingHandle, Mag | rbxassetid://128418389822265 |
| RifleInspectLeft | 3.000 | no | Action | SlideRack 2.100 | BoltCarrier, ChargingHandle, Mag | rbxassetid://77571797826621 |
| RifleLowered | 1.000 | yes | Action | - | - | rbxassetid://102774795254703 |
| RifleLoweredLeft | 1.000 | yes | Action | - | - | rbxassetid://132015717320543 |
| RifleReload | 2.400 | no | Action | MagOut 0.267, MagStowed 0.733, MagIn 1.167 | Mag, MagRelease | rbxassetid://74065368140291 |
| RifleReloadEmpty | 2.800 | no | Action | SlideRack 1.467, MagHide 0.500, MagShow 0.517, MagOut 0.267, MagIn 1.000 | BoltCarrier, ChargingHandle, Mag, MagRelease | rbxassetid://111382130366290 |
| RifleReloadEmptyLeft | 2.800 | no | Action | SlideRack 1.467, MagHide 0.500, MagShow 0.517, MagOut 0.267, MagIn 1.000 | BoltCarrier, ChargingHandle, Mag, MagRelease | rbxassetid://103012093992408 |
| RifleReloadLeft | 2.400 | no | Action | MagOut 0.267, MagStowed 0.733, MagIn 1.167 | Mag, MagRelease | rbxassetid://126569505805502 |

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
| MeleeKnifeBackstab | 0.600 | no | Action | Hit 0.167 | - | rbxassetid://78673719136338 |
| MeleeKnifeHeavy | 0.700 | no | Action | Hit 0.283 | - | rbxassetid://92787005222321 |
| MeleePunch | 0.400 | no | Action | Hit 0.100 | - | rbxassetid://112654310392426 |
| MeleeSlash | 0.450 | no | Action | Hit 0.117 | - | rbxassetid://122754483660768 |
| QuickMeleeBash | 0.400 | no | Action | Hit 0.133 | - | rbxassetid://78125697331250 |

## Bat

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| BatChargeHold | 1.000 | yes | Action | - | - | rbxassetid://97881258420838 |
| BatChargeWindup | 0.800 | no | Action | - | - | rbxassetid://98165537194557 |
| BatEquip | 0.350 | no | Action | - | - | rbxassetid://126172666243917 |
| BatHold | 1.000 | yes | Action | - | - | rbxassetid://85889452198064 |
| BatSwing | 0.750 | no | Action | Hit 0.167 | - | rbxassetid://82431732523451 |
| BatSwingCharged | 0.600 | no | Action | Hit 0.100 | - | rbxassetid://112759144468031 |

## Katana

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| KatanaEquip | 0.400 | no | Action | - | - | rbxassetid://105719672965814 |
| KatanaHold | 1.000 | yes | Action | - | - | rbxassetid://124201784974669 |
| KatanaSlash | 0.650 | no | Action | Hit 0.117 | - | rbxassetid://121708902048641 |

## Riot Shield

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| RiotShieldBash | 1.000 | no | Action | Hit 0.117 | - | rbxassetid://74464731581821 |
| RiotShieldBreak | 0.600 | no | Action | DropGun 0.067 | - | rbxassetid://97614848249187 |
| RiotShieldHold | 1.000 | yes | Action | - | - | rbxassetid://121983717239708 |
| RiotShieldImpact | 0.250 | no | Action | - | - | ready to publish |

## Gadgets

| Clip | Length | Loop | Priority | Markers (s) | Gun parts keyed | Published id |
|---|---|---|---|---|---|---|
| FlashThrow | 0.400 | no | Action | Release 0.150 | - | rbxassetid://87737247078120 |
| FlashThrowLeft | 0.400 | no | Action | Release 0.150 | - | rbxassetid://115076960014662 |
| FragCook | 1.000 | yes | Action | - | - | rbxassetid://117863825008865 |
| FragPinPull | 0.300 | no | Action | Pin 0.117 | - | rbxassetid://130293465314345 |
| FragThrow | 0.400 | no | Action | Release 0.150 | - | rbxassetid://136841760419115 |
| FragThrowLeft | 0.400 | no | Action | Release 0.150 | - | rbxassetid://89044847366527 |
| LandminePlace | 0.900 | no | Action | Placed 0.367 | - | rbxassetid://94762691342089 |
| MedkitUse | 2.500 | no | Action | Open 0.367, Heal 0.700 | - | rbxassetid://72050726044106 |
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
