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
- Small reach gaps left (studs): PistolInspect 0.12, SMGInspect 0.15, RevolverInspect 0.07, BatEquip 0.23 (one moment
  each, off hand short of the gun while it moves).
- Neck: shouldered holds turn the head 15 deg back toward the aim; HeadLookController adds the rest.
