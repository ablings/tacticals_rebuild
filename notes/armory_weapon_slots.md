# Armory weapon slots: swap guide (Armory round 2, 2026-10-15 night)

Edward has not chosen the weapons yet. Every weapon in the Armory is a **placeholder** sitting in a named slot, so the real
weapons go in by editing one config table. Built by `fix/polish_armory2.lua` (run after `fix/polish_armory.lua`).

## Swap a weapon (one edit)
1. Put the new weapon Model in `Workspace.LobbyMap.Rooms.Armory.WeaponsDisplay` (the hidden catalogue: Display_AutoRifle,
   Display_SemiAuto, Display_Sniper, Display_MiniUzi, Display_Pistol, Display_Revolver, Display_SilencedPistol, Display_Knife),
   or in `ServerStorage.ArmoryWeapons` (create the folder). Name the barrel-end part or attachment `Muzzle` (or `Barrel`) and the
   magazine/grip `Mag` (or `Magazine` / `Handle` / `Grip`) so the fitter knows which way is forward and which way is down.
2. Open `ServerStorage.ArmoryWeaponSlots` and change the model name next to the slot (or `M.Default` to change every slot that
   isn't listed).
3. In the Studio command bar: `require(game.ServerStorage.ArmoryWeaponSlots).Apply()`. It returns the number of slots filled and
   a list of failures. It is idempotent; run it again after every edit (in Studio the module is cached per session: if the edit
   doesn't show, run `require(game.ServerStorage.ArmoryWeaponSlots:Clone()).Apply()`).

Tested: Featured -> Display_Sniper and GunWall_5 -> Display_Pistol applied and fitted, then reverted (20 of 20, 0 failures).

## What a slot is
`Model WeaponSlot_<Area>_<n>`:
- `Anchor` (invisible Part, the PrimaryPart) with an Attachment `Mount`. Anchor frame: **RightVector = barrel (muzzle +)**,
  **UpVector = weapon top**, **LookVector = out of the wall / bench**.
- Attributes: `WeaponId` (the model now in it), `MaxLength` (longest side after the fit; the scale is capped at 1.5x),
  `Align` (`Bottom` = the weapon's lowest point rests on the anchor line, i.e. the rail, peg line or bench top; `Centre` = its
  centre sits on the anchor), `Gap` (studs off the surface), `Area`.
- `Weapon`: the placeholder clone. Scripts, welds, joints and constraints are stripped; every part is anchored, CanCollide /
  CanQuery / CanTouch off, `NotCover`. **Nothing is welded to the room.**
- Rack slots also hold their two `Peg` parts (static hardware, about 0.75 above the rest line for the placeholder rifle).

## The 20 slots
| Area | Slots | Where | Fit |
|---|---|---|---|
| Featured | `WeaponSlot_Featured_1` | **inside `Rooms.Armory.FeaturedScissors`** (the hook: name, pivot (-10,3.4,-96) and `Spin = 25` unchanged; the scissors meshes are hidden inside it) | Centre on the dais axis at y 3.45, MaxLength 5.9; RoomFX spins and bobs the whole model |
| GunWall | `WeaponSlot_GunWall_1..9` | 3 rows on the gun wall's rails (rail tops 9.72 / 6.22 / 2.72, front z -111.21) x columns x -11.75 / -6.25 / -0.75; 1-3 top row left to right | Bottom, MaxLength 4.7. **Since polish_armory3:** the anchor is the magazine-foot line 0.46 below the rail top and gap 0.04, so the placeholder's stock sits at rail height with the mag hanging in front of the rail; two static pegs (`Polish.Armory.Round3.GunWallPegs`) carry it. A weapon with a different mag drop still fits; re-run polish_armory3 to refit the pegs. |
| RackW / RackE | `WeaponSlot_RackW_1..4`, `WeaponSlot_RackE_1..4` | eye-level pegboard niches in the two former rack bays per side wall (z -80..-88.2 and -91..-100); odd = lower row (rest y 2.0), even = upper row (rest y 4.3) | Bottom on the rest line, MaxLength 6.4 (rifle at 1.45x), gap 0.06 |
| Bench | `WeaponSlot_Bench_1..2` | standing on its magazine along each bench top (y 3.04) at (12.25,-83.55) and (20.25,-88.05), facing the entrance | Bottom, MaxLength 4.4 |

The glass display case by the dais had two guns baked in; they are hidden. Under its 0.6-stud glass there is no room for a
full-size weapon slot, so the case shows magazines/ammo only. A pistol-sized slot could go there if Edward wants one.

The round-1 high bays (`Polish.Armory.WeaponBays`, y 10-15) no longer hold weapons: guns and pegs are hidden and the stencils read
`LOCKER W-01 / AMMO · SEALED` (the slotted panels read as louvred ammo-locker fronts). Weapons are at eye level now, as in RIVALS.

## Placeholder
One neutral placeholder everywhere: `Display_AutoRifle` (dark grey receiver, tan furniture). Pick any catalogue model per slot
when the real weapons exist.

## Undo / rebuild
- `python tools/run_luau.py fix/polish_armory2.lua UNDO` restores every touched property (attribute `PolishArmory2_Orig`) and
  removes Round2, the featured slot and the config module.
- A re-run of `fix/polish_armory.lua` rebuilds `Polish.Armory` and drops `Round2`: re-run `polish_armory2.lua` after it.
- `fix/check_polish_armory.lua` checks every slot (Anchor = PrimaryPart, WeaponId = config entry, a visible Weapon, no joints)
  and that no baked weapon mesh is visible.
