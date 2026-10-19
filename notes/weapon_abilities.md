# Weapon abilities (Edward, 2026-10-18/19)

Each weapon has one identity, shown on the Kit screen (ability row + Speed / Reload / Accuracy bars).
Mechanics: Tacticals session. Kit screen, icons, HUD feedback: UI session. Numbers marked (tune) are suggestions.

## Speed ladder (movement: run, dash to cover, slide, vault; and reload time)
1 Pistol (fastest) · 2 Dual Pistols · 3 Suppressed · 4 Mini Uzi · 5 Revolver · 6 Automatic Rifle · 7 Pump Shotgun · 8 Semi-Auto · 9 Sniper (slowest)

## Guns
| Item id | Ability | What it does |
|---|---|---|
| Pistol | **Quickdraw** | More accurate when shooting without aiming in (hip fire). Fastest movement in the game (run, dash to cover, slide, vault) and the fastest reload. |
| SilencedPistol | **Whisper** | Second fastest (movement + reload). All its sounds are quieter: they can't be heard beyond a short range (all guns share a similar sound cue, this one just carries less). |
| MiniUzi | **Run and Gun** | Keeps full movement speed while running and shooting; slightly more accurate hip fire. It can sprint while aimed in (other guns can't, or are slowed), but aimed-in accuracy drops to 85% while sprinting (slight spread). |
| Revolver | **Knockback Shot** | A fully aimed-in shot that hits forces the target to dash to the nearest cover (Edward 2026-10-19: the target, not the shooter): their peek / aim is cancelled and they are moved into that cover. |
| AutoRifle | (no ability) **30-round magazine** | Already strong: no ability, a 30-round magazine instead. |
| SemiAuto | **Precision Rhythm** | Consecutive hits without missing add damage: +5% per hit, up to 3 stacks (tune). A miss resets it. A small stack counter on the crosshair. |
| Sniper | (no ability) **One-shot headshot** | A headshot is a one-shot kill: that's its reward. |
| PumpShotgun (NEW) | **Door Breaker** | The close-range answer. A point-blank hit (~6 studs) on someone in cover knocks them out of it: the reverse of the Revolver. Reloads one shell at a time (a shot interrupts the reload). Price ~2500 (tune). |
| DualPistols (NEW) | **Akimbo** | Can't aim in at all, but hip fire is fully accurate and the fire rate doubles while moving. Close-range aggression. Price ~2200 (tune). |

## Melee
| Item id | Ability | What it does |
|---|---|---|
| Fists | **Vault Takedown** | Vaulting over cover into an enemy near the vault (within ~4-5 studs of the landing, or crouched behind that cover) stuns and topples them for ~1 s (can't shoot / aim) and deals 50 damage. Per-target cooldown ~8 s (tune). Heavy thud, victim camera shake, "TAKEDOWN" hit marker; fist icon in the kill feed. |
| Knife | **Slide Lunge** | The first swing during or right after a slide lunges ~6 studs forward with bonus damage (tune). |
| Bat (NEW) | **Home Run** | Hold to charge a swing (~0.8 s); a charged hit knocks the target back several studs: out of cover or off a ledge. Price ~1000 (tune). |
| Katana (NEW) | **Parry** | Right after a swing there's a short block window (~0.35 s): bullets hitting you from the front in it are deflected (no damage), with a spark + clang. Rewards timing. Price ~2500 (tune). (UI proposal; Edward to confirm.) |
| RiotShield (NEW) | **Bulwark** | Held out it blocks bullets from the front; you move slowly and can bash (short stun). Damage to the shield is capped / it can break (tune). Price ~3000 (tune). |

## Gadgets (no abilities yet: Edward)
Smoke, Flash (Flashbang), Frag, plus NEW: **StickyGrenade** (sticks to surfaces / players, then explodes; ~1500),
**Landmine** (placed on the floor, triggers on an enemy stepping near; ~1800), **Medkit** (heals over a short channel; ~1000).

## UI side (UI session)
- Kit screen: an ability row under the info card (silhouette icon, name, one line), plus Speed / Reload / Accuracy bars from the ladder.
  Auto Rifle and Sniper show their perk ("30-round magazine", "One-shot headshot") so no card is empty.
- HUD: Semi-Auto stack pips by the crosshair; Revolver "ready" tick when fully aimed in; "TAKEDOWN" marker for the Fists.
- Data: ReplicatedStorage.Modules.Shared.Config.WeaponAbilities (ui/settings/WeaponAbilities.lua): text + the ladder ranks;
  the Tacticals session can read the same module for its numbers.

## Status (Tacticals session)
- 2026-10-19 Phase 1 in both working copies (not published): `fix/weapon_abilities.lua` (WeaponConfig + CombatManager) and
  [ABILITY] edits in ui/set Weapon/Movement/Cover controllers + WeaponEffects. Speed ladder (MoveSpeed: run, crouch, slide,
  dash to cover, vault via `WeaponConfig.Mobility`; ReloadTime, reload animation stretched to fit), Pistol hip 1.75°,
  Suppressed SoundScale 0.35, Mini Uzi RunAndGun (AimSprintSpread 1.5°), Auto Rifle 30/120, Semi-Auto Rhythm
  (player attribute RhythmStacks; tested 45/47/50/52, miss -> 0), Sniper HeadshotKills (no head drop-off).
- Next: Phase 2 (Revolver Knockback on the target, Fists Vault Takedown, Knife Slide Lunge), then Phase 3 new items (need models).
