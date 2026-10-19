# Weapon abilities (Edward, 2026-10-18/19)

Each weapon has one identity, shown on the Kit screen (ability row + Speed / Reload / Accuracy bars).
Mechanics: Tacticals session. Kit screen, icons, HUD feedback: UI session. Numbers marked (tune) are suggestions.

## Speed ladder (movement: run, dash to cover, slide, vault; and reload time)
1 Pistol (fastest) · 2 Suppressed · 3 Mini Uzi · 4 Revolver · 5 Automatic Rifle · 6 Semi-Auto · 7 Sniper (slowest)

## Guns
| Item id | Ability | What it does |
|---|---|---|
| Pistol | **Quickdraw** | More accurate when shooting without aiming in (hip fire). Fastest movement in the game (run, dash to cover, slide, vault) and the fastest reload. |
| SilencedPistol | **Whisper** | Second fastest (movement + reload). All its sounds are quieter: they can't be heard beyond a short range (all guns share a similar sound cue, this one just carries less). |
| MiniUzi | **Run and Gun** | Keeps full movement speed while running and shooting; slightly more accurate hip fire. It can sprint while aimed in (other guns can't, or are slowed), but aimed-in accuracy drops to 85% while sprinting (slight spread). |
| Revolver | **Knockback Shot** | A fully aimed-in shot that hits forces the target back into cover: their peek / aim is cancelled and they are pushed back behind their cover. (UI reading; Edward to confirm it's the target, not the shooter.) |
| AutoRifle | (no ability) **30-round magazine** | Already strong: no ability, a 30-round magazine instead. |
| SemiAuto | **Precision Rhythm** | Consecutive hits without missing add damage: +5% per hit, up to 3 stacks (tune). A miss resets it. A small stack counter on the crosshair. |
| Sniper | (no ability) **One-shot headshot** | A headshot is a one-shot kill: that's its reward. |

## Melee
| Item id | Ability | What it does |
|---|---|---|
| Fists | **Vault Takedown** | Vaulting over cover into an enemy near the vault (within ~4-5 studs of the landing, or crouched behind that cover) stuns and topples them for ~1 s (can't shoot / aim) and deals 50 damage. Per-target cooldown ~8 s (tune). Heavy thud, victim camera shake, "TAKEDOWN" hit marker; fist icon in the kill feed. |
| Knife | **Slide Lunge** | The first swing during or right after a slide lunges ~6 studs forward with bonus damage (tune). |

## Gadgets (Smoke, Flash, Frag)
Not decided yet.

## UI side (UI session)
- Kit screen: an ability row under the info card (silhouette icon, name, one line), plus Speed / Reload / Accuracy bars from the ladder.
  Auto Rifle and Sniper show their perk ("30-round magazine", "One-shot headshot") so no card is empty.
- HUD: Semi-Auto stack pips by the crosshair; Revolver "ready" tick when fully aimed in; "TAKEDOWN" marker for the Fists.
- Data: ReplicatedStorage.Modules.Shared.Config.WeaponAbilities (ui/settings/WeaponAbilities.lua): text + the ladder ranks;
  the Tacticals session can read the same module for its numbers.
