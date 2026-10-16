# Overnight polish: Duels (arena deck)

Done 2026-10-16 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). RIVALS (2e616d06) was
only read: a pad-hallway survey (Queue Pads #1-10 at x 208..341, z 1160/1208, floor ~-685) and four captures. No computer use, no
imports, no RIVALS ids. Built from Parts, SurfaceGuis, Beams and our own `TX_overlay_panel_lines` texture.

| What | Path |
|---|---|
| Polish script (idempotent, UNDO flag) | `fix/polish_duels.lua` -> `python tools/run_luau.py fix/polish_duels.lua [UNDO]` |
| Check (clips, support, hooks, walk paths, lights; read-only) | `fix/check_polish_duels.lua` |
| Captures (8 cameras incl. the hub stairs) | `python tools/polish_duels_capture.py <prefix> [names]`, `... ref <name> x,y,z lx,ly,lz` |
| Sheet | `python tools/polish_duels_sheet.py` -> `out/polish/duels/sheet.jpg` (BEFORE / AFTER / close-ups / RIVALS) |
| Contact sheet helper | `python tools/contact.py <dir> <prefix> <out.jpg> names...` |

## Identity
A dramatic arena deck: the only room with a **near-black floor and charcoal envelope** where the light lives on the pads. It sits
between the warm cream Shop and the neutral gunmetal Armory and reads as neither. The open skylight and the west glass stay as the
military sky edge.

## RIVALS method (from the captures)
Near-black aisle; pads brighter than the floor, with thin Neon frames in the team colour (purple/gold); light logo rings on the pad
floors; white mode plates ("1v1") hung overhead; lane lines along both aisle edges; pill wall lamps. **The pads are lit by their
surfaces and Neon, not by SpotLights** (RIVALS has one pad SpotLight in the whole lobby). That made the light budget easy.

## What changed
1. **Envelope** (56 Rooms3 `D_*` meshes + 9 `Features.DropPits.FloorSlabs`, originals in attribute `PolishDuels_Orig`):
   charcoal walls, Plastic above the kick, dark-olive bands, near-black Plastic floor. The colours were **measured**: the first
   charcoal rendered teal/navy (blue minus red +12..+34, because the sky fill dominates dark colours). Each value is the neutral
   target divided by its render ratio (60% of the full correction; `tools/part_pixels.py` on three views). Then Concrete/Metal floor
   and gantries went to Plastic (sky specular). Result: walls -1..+4, floor +8.
2. **Per-team pads** (`Polish.Duels.Pads.<pad>.<Team1|Team2>`): the shared cream/olive outline meshes `D_Lines__neon_cream/olive`
   are hidden (one mesh for every pad, so it can't be split by team). Each team zone now has a tinted inset panel with the
   panel-line texture. **Team A is cream, team B olive** (Neon 236,232,218 / 90,106,42; olive at 138,156,74 glowed lime-white), with a
   0.38 Neon frame and a reticle emblem with the team letter. A stepped glow pool (three translucent circles in a LightInfluence-0
   SurfaceGui) sits on the panel. The panel is **fitted by rays** to the free plate area: the invisible team plates run into
   curbs, terminal posts and wall trim, so the edges step in until clear.
3. **Rig and lamps**: a gantry rig across the open hall, two beams along z at x -99 / -131 and two cross beams at z +-35.2. The beams
   are dark with a light top chord and a cream Neon line underneath, bracketed to the walls. Their positions dodge the wall pill
   lamps, found by a lamp scan. One lamp per team zone (housing, team-colour collar, warm Neon lens) has a **light shaft** (Beam,
   FaceCamera, LightEmission 1) down to the pad. 12 lamps.
4. **Signage**: cream mode plates per pad ("1V1 · PAD 01 · CREAM v OLIVE"), hung under the rig and angled down toward the aisle.
   An **ARENA DECK briefing board** stands on top of GantryX2, facing the door: it is visible from the doorway and even from the hub
   stairs, and sits above the eye line to the DECK sign. An EXIT · HUB plate under GantryX1 faces into the hall. Cream lane lines
   run along both aisle edges, split into segments that follow the floor height.
5. **Lights (no new instances)**: `FX.SparkBridgeA/B/SparkGantry` were enabled at Brightness 0; they are now off. Enabled lights:
   **102 -> 99 in Edit** (59 in Play at the Duels). `Lights.TargetTop` changed from a 70-degree wash (b1.4) to a 30-degree key on
   the centre disc (b3, warm).
6. **Team colours in UI**: `PadBoards` team A/B were red/blue; they are now cream/olive (`TEAM_A/TEAM_B`, 3 uses; the LEAVE-hover
   red is untouched). The source is backed up in `ServerStorage._RebuildRemoved.PolishDuels_PadBoards_Orig`. The old Edit-only
   `Holo.Display` count labels were recoloured the same way.

## Logic checks
- `check_polish_duels`: **0 clips** (rays + 52 probes, 173 parts). The first run found 37: panels/frames in pad curbs, terminal
  posts and wall trim, gantry ends on wall lamps (meshes with CanQuery off that the measuring rays skipped), lanes sunk into raised
  pad plates. All fixed. Support: all brackets reach a wall; one lane segment is 0.002 into a 0.01-higher plate (top still 0.058
  proud, no z-fight). Hooks: 6 pads ok (tag, QueueName, PlayersPerTeam, Team1/2, plates collide, barriers, Holo). 0 new collidable
  parts, 0 new lights. Walk paths (door, aisle, z +-5, energy gap; knee and head height) clear.
- `check_rooms2` FAILS 0, `check_rooms3` FAILS 0 (Duels door 7.93 clear, west passage 12.28), `check_hub1` nothing flagged,
  `check_training` ALL OK.
- **Play walk**: hub (-70,1,0) -> stairs -> Duels door (-99.2,19,0) -> round the south pads (-107,-20) (-114,-26) (-121,-20) ->
  west end (-136,-3) -> energy-wall gap -> west deck (-169,19,0) -> north pads (-121,20) (-114,26) (-107.7,20.5): all reached,
  no pit returns.
- **Queue**: on Pad_3v3_B team 2: `Team2Count` 0 -> 1, player `QueueMode = 3v3`. Before the change Pad_1v1_A also went
  `Team1Count` 0 -> 1. PadBoards showed TEAM A cream / TEAM B olive. The **Duels TV** listed the match ("3V3 — VS … LIVE"), the
  **DUELS strip** and `LF_LiveDuels` updated.
- Console in Play: baseline only (MatchmakingManager MemoryStore, AssetCheck 1/1154, UIBlox warnings).
- UNDO round trip: 74 instances restored, PadBoards source restored, backup removed, 0 attributes left, 102 lights. Re-applied twice:
  identical (173 parts).

## For the lead / Edward
- Pads now read as two-team bays at a glance. Cream vs olive is the strongest contrast our palette has; under the lamps the olive
  is clearly green, not yellow.
- The Holo `Beam` (queue-pad Holo beam bug, an open question) is untouched.
- The emblem letter is upright for players walking up from the centre aisle.
- Queued for import: nothing (no Blender kit was needed).
