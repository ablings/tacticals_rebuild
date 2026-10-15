# Rooms pass 4: Training (y 600) + Showroom (y 400), Blender kit only

Same method and language as the hub and rooms2/3 (read notes/hub1_kit.md, notes/rooms2_kit.md, notes/rooms3_kit.md, notes/hub2.md and
notes/rooms2_place.md lessons, notes/rivals_style.md, notes/layout.md, notes/hooks.md, notes/rooms.md, out/survey/plan_training.png and
the captures). Keep every footprint and height:
- **Training** (floating, floor y 600, 172 x 238, ceiling ~636): reached by the Exfil cutscene respawn; scattered cover blocks on a grid
  (see plan_training.png). Hooks (hooks.md): `FLOOR_Y = 600` hard-coded; players above y 540 who aren't training get sent to the
  hangar; falls below y -25 caught; keep `Arrivals`, `EnemySpots`, `TrainingArrive` parts and positions; RoomLight Training centre
  (0,606,0) r175. Make it a RIVALS-style training range in the sky base: banded walls, sky windows, cover pieces (RIVALS-like crates,
  barriers, low walls in the palette), lane markings, target areas; keep the cover layout roughly where it is (gameplay), but rebuild
  the pieces in the kit style.
- **Showroom** (y ~400, x -31..31, z -19..35): only seen through the Kit menu camera (`CameraPoint`, `DisplayPoint`, `BenchTop`); no
  collision needed. Make it a clean RIVALS-style display stage (backdrop, plinth/bench, lights) framed for that camera; keep the three
  hook parts exactly.
No extra kid-friendly elements RIVALS doesn't have.
Deliver: kit/rooms4.fbx in world coordinates with K_Scale4 at (0,120,0) and K_Marker4 like before; every mesh <20k tris, split by
material, bevelled, UV'd for the Tac textures (reuse tex/asset_ids.json); kit/rooms4_manifest.json; Blender previews out/rooms4/bl_*.png
+ contact sheet (include a view from the Showroom CameraPoint); notes/rooms4_kit.md with what placement must hide/keep. Blender only
(another agent is in Studio). Save kit/rooms4_kit.blend (never call read_homefile). Time-box ~2 hours.
