# Tacticals UI handoff → Shadow PC (2026-10-19, from the main PC UI session)

## Get the project
```
git clone https://github.com/ablings/<private repo>.git "%USERPROFILE%\Documents\tacticals_rebuild"
```
(If the folder already exists there: `git pull` instead.) Work commits end at 83d6997. The repo holds the
saved working places (Tacticals_rebuild.rbxl = lobby, match_place_ref.rbxl = match; saved by the lead at fa7da81, port 20).
`rivals_practice` is on GitHub (`git pull`); it holds `mcpcli.py` (Studio MCP bridge client).
Read `CLAUDE.md` in tacticals_rebuild, and the vault pages `wiki/tacticals/Lobby UI Kit.md` + `wiki/log.md`.

## State
- Port 20 is live (weapon abilities, 8 new items, Kit cards, item HUD). Published by the lead session on Edward's go.
- Commits AFTER port 20, in the repo but NOT deployed to any studio and NOT published:
  - f27a2d4 + ed50188: match clock. No 3-2-1 / FIGHT / ROUND n banners. The clock counts tenths under a minute
    (5.0, 4.9 ...), red under 5 s of a live round. (`ui/match/DuelHUD.client.lua`)
  - 474a994: Kit screen blur (BlurEffect 8 + stronger DOF; the item stays sharp). (`ui/lobby/Armory.lua`)
  - 83d6997: Pump Shotgun / Bat / Riot Shield models had gaps (Edward: "detached"). Fixed in
    `tools/new_weapons/build_new_items.lua`.

## To do on the Shadow PC (only when Edward says Studio can be opened)
1. Open both places, run `list_roblox_studios`, note the new ids.
2. UI deploy (check live == repo first; the guard needs `--force` on a new machine since its hash file is per studio):
   `python ui/deploy_ui.py <lobby id>` and `python ui/deploy_ui.py <match id> --match`
3. Model rebuild in BOTH studios (Edit mode, execute_luau): prepend `ONLY = { PumpShotgun = true, Bat = true, RiotShield = true }`
   to the source of `tools/new_weapons/build_new_items.lua`. Never rebuild DualPistols (LeftBarrel.Muzzle lookup).
   Lead's constraints: one "Muzzle" attachment in the shotgun; the grip stays "Handle" with its sounds.
4. Check in Play (take `tools/play_lock.py take ui` first, release after): Kit renders of the three models, the Kit blur,
   and a bot round for the clock (out/td.json-style StudioTeleportData).
5. Commit, vault, and tell the lead session ("Roblox training"). Publishing is the lead's job, and only on Edward's go.

## Rules (Edward)
Never publish yourself, never enter credentials, UI in Scale only, commit only your own paths with the Co-Authored-By trailer,
vault lessons after each finished piece of work.
