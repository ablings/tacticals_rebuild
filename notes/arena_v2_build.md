# Arena v2: build log (2026-10-26, Shadow PC map builder)

Built from the approved plan (`notes/arena_v2_plan.md`; Edward 2026-10-26: asymmetry as planned, decks 5, "yes studio parts").
Sheet: `notes/arena_v2_sheet.jpg` (v1 left / v2 right per pair; cameras `captures/cams-arena_v2.json`).

## How it is built
- `fix/map_arena.lua`: plain Blocks + 2 Wedges, axis-aligned, 0.5 grid, every visible part collides (collision = what you see).
  The layout block is generated from `notes/maps/arena_v2_layout.json` by `tools/arena_v2_lua.py` (never hand-edit it).
- Surfaces (look E of `notes/arena_lookdev.md`) all in the `SURFACE` table: Plastic; floor 205,199,181; structure 203,196,183 (box, rims,
  window frames, decks, curbs, ramps); solid cover 177,171,160 (pillars, walls, low walls, parapets, the ledge wall); grid = our image
  86361987736184, 5-stud tile, black, 3 copies at 0.85 one line width apart, world-aligned (lines at x, z = origin + 5k, y = floor + 5k).
  **A new grid tile = change `SURFACE.GRID.image` (and `tile`)**; set `copies = 1` if the new tile draws its own line width.
- Grid faces: floor top; box walls inner face only; every piece top + 4 sides; ramps slope + 2 sides; no rims.
- Rims: inflated 0.05 across the wall only, E/W rims stop at the N/S rims (v1 overlapped at all 4 corners).
- Spawn tint plates: the pocket inset 0.25 and stopped short of B's shield pillars.
- v1 + its registry entry: `ServerStorage._ArenaV1_Backup` (match) / the v1 duel source (lobby). `UNDO = true` restores them.

## Cover hooks (no script reads folder names; CoverController = raycast + `NotCover`)
| Part | Treated as | Why |
|---|---|---|
| pillar / wall / wall on the ledge | tall cover | 7-10 high |
| low wall / parapet | low cover (vault) | 3.4 |
| window sill (separate part) | low cover, vaultable through the opening | the head probe passes through the opening |
| window post / lintel | tall cover / out of reach | |
| deck (5 high) | **NotCover** | between low (<=4) and tall (>=7); NotCover also means Space can never climb it (the climb only targets cover) |
| curb, ramp, floor, box, rims | NotCover | |
No combat script was changed. BotManager only reads `BotConfig.CoverFolders = { "Warehouse/CollisionProxies" }`, so bots have no cover
spots on the Arena (also true for v1): a script/config change for the lead (e.g. add an Arena cover folder path).

## Checks
- Read-back (`tools/arena_v2_readback.py`): all 92 piece parts + 2 ramps = the plan exactly (0 differences), anchored, collide,
  axis-aligned, on the grid, NotCover per role right; SpawnA (-70, 0) facing +x, SpawnB (70, 2.5) facing -x, team spots = the plan's.
- `tools/arena_v2_check.py` on the built geometry: 0 errors, 0 warnings, the same numbers as the plan (spawn LOS 0 / 43,681, exposure
  mean 25.0, timings within 7 %).
- MapAudit (kit source inlined, `tools/arena_v2_audit.py`): **0 FAIL, 0 WARN** (105 parts, 6 spawn spots). First run had 6 FAIL: the perch's
  two curbs overlapped 0.5 x 0.5 at the corner (layout fixed: W curb starts at y 45.5) and B's spawn plate shared a plane with the shield
  pillars. The window / ledge-wall tops (12) and box tops are tagged `KitIntendedDrop` (out of reach). v1 had 29 FAIL.
  `run_checks.py --map` itself needs ServerStorage.KitChecks + KitMaps, which the match place doesn't have.

## Play lap (match copy, StudioTeleportData me + bot, Arena voted)
- Spawns: A at (-70.0, -0.1) facing +x, bot at (70, 2.5) facing -x, every round; Arena lighting applied (ClockTime 15.2, exposure -0.55).
  3v3 run: all 6 on the planned spots (A y -4 / 0 / 4, B y -1.5 / 2.5 / 6.5).
- Ramps (JumpHeight 0 on the client): A and B up to feet 5.00 and back to 0.00, 1.6 s each way at walk 12.5.
- Windows: all 6 sills taken as cover (CoverController part = the sill) and vaulted both ways: 12 / 12 over, landing on the floor.
- Cover: pillar A_C_P, wall A_Fwd_W, low walls A_S_L + B_LedgeFront_L, sill, perch parapet: all react. Deck faces: no cover, Space does
  not climb, walking into them at 20 never steps up.
- Ways down: parapet vault -> floor; Space over a curb -> floor (both decks, all curb edges); no damage.
- Round: 5 rounds to Victory 5-0, each round both on their spawns.
- Lobby copy: 3v3 duel (me + 5 bots): all 6 on the planned spots in the slot; cover / vault / no deck cover / ramp work in the slot.

## Measured in Play (the plan's open assumptions)
- **Crouched head in low cover: top 3.79-3.89 above the floor, 0.4-0.5 over a 3.4 low wall / sill / parapet** (Head part top; the head
  centre ~3.2 stays under). The plan assumed 3.2. This is the game's pose against its own kit height (the Warehouse uses 3.4 too), so not
  changed here: a decision for the lead / Edward (low cover 3.8-4.0 would hide the head and still read as low: head probe at 4.5).
- **Curb:** Roblox's step-up carries a walking player over the 1-high curb and off the deck (an extra way down, harmless). A player can't
  stop on it: walking at it stops 0.5 short; placed on it, the body settles back to the deck (feet 5.33 max), so the eye never reaches 10.6.
- **End-on low wall:** confirmed climbable (Space at a free end -> standing on top at 3.4), as the plan allows.
