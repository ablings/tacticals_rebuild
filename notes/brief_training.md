# Training room (Edward, 2026-10-15): REBUILD, Parts-first like RIVALS, more space, RIVALS-level content

Edward clarified: not new mechanics, but "amount of npcs and stuff": match RIVALS' range in content (number of target NPCs/dummies,
props, cover, density, space) using Tacticals' existing scripts unchanged.

Edward: the current Tacticals Training (grid tiles) is the visual standard; but rebuild it "with more space and the rivals mechanics".
RIVALS builds its range in Studio with Parts (Lobby.ShootingRange 374 Parts vs 70 MeshParts; ~1,180 Parts with a 5x5 grid Texture).

Step 1 (research, read-only): what RIVALS' shooting range does as a player sees it (layout, lanes, distances, target types, moving
targets, pop-ups, respawn, hit feedback, damage numbers, any HUD, how you enter/leave), and what Tacticals' Training does today
(scripts in out/survey/src/*.lua: arrival, EnemySpots, dummies, FLOOR_Y 600 logic). Output a spec (notes/training_spec.md) of the new
room: footprint (bigger than 172 x 238, within the floating y 600 platform logic), zones, cover, target lanes, which mechanics we add
or change in Tacticals' own scripts (own code, never RIVALS code), and what stays. Edward approves the spec before any script changes.
Step 2 (build, after approval): Parts-first in Studio, grid tiles like the current room and RIVALS, own grid texture TX_overlay_grid,
Tac variants, palette; then the mechanics in Tacticals' scripts; keep every hook that remains relevant.

## Edward's answers (2026-10-15)
- Roof/walkable block level at **24** studs; the room has a **ceiling** (not open sky). Default chosen: ceiling at +48 (24 headroom over
  the roof deck).
- **Raise alive dummies** 24 -> 35.
- **Script-only RIVALS extras: yes** ("would be cool"): floating 1-HP bullseye targets, infinite-HP DPS dummies with a damage-per-second
  readout, jump pads, tightropes, weapon-swap bins. Own code in Tacticals' scripts (never RIVALS code), fitted to Tacticals' combat and
  weapon systems; each feature isolated and switchable.
- Not answered, defaults: the gallery is always kept filled (its 16 spots guaranteed); lights ON (closed room) with the RoomFX Training
  radius widened to cover the new arena and gallery.

## Build order
1. Room geometry Parts-first in Studio (grid tiles, palette, ceiling, roof level 24, ramps/ladders, gallery, signs, NotCover rules,
   Arrivals/EnemySpots folders filled per the spec), hide the old Training UNDO-ably; check FLOOR_Y logic and walk routes.
2. Script changes (own code), one feature per module with a flag: alive count 35, gallery fill, RoomFX radius, then bullseyes,
   DPS dummies, jump pads, tightropes, weapon-swap bins. Test each in Play (server + client) in the local copy.
