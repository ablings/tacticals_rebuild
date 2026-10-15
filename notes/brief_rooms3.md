# Rooms pass 3: Duels hall + Exfil hangar (and the east tunnel end), Blender kit only

Same method and language as the hub and rooms2 (read notes/hub1_kit.md, notes/rooms2_kit.md, notes/hub2.md lessons, notes/rivals_style.md,
notes/layout.md, notes/hooks.md, notes/rooms.md, out/survey/plan_duels.png, plan_exfil.png and the captures). Keep every footprint,
door and height:
- **Duels** (west, x -138..-92, floor y 16 via the hub's west stairs and an 11-wide door; 6 queue pads 1v1/2v2/3v3 A and B; a 9-wide gap
  in the energy wall to a dead-end WEST DECK at y 16 fenced by invisible walls). Hooks that MUST keep working (hooks.md): the QueuePad
  tag models with attributes QueueName and PlayersPerTeam and children Team1, Team2, Team1Barrier, Team2Barrier, Holo (Holo.Display
  BillboardGui), BayId; collision groups DuelQueued/DuelBarrier; the Duels officer NPC on the top landing; Duels sign. The new kit must
  leave each pad's footprint and children untouched (dress AROUND them: pad surrounds, frames, team-coloured trims in cream vs olive
  like RIVALS' purple vs gold pads, readable signage per pad in the RIVALS manner).
- **Exfil hangar + pad** (east, x ~96..160, hangar roof y 20-21, open-sky helicopter pad), the 22 x 18 tunnel continues from the hub
  portal. Hooks: ExfilBarrier touch part, Exfil.HatchPoint, Exfil.CabinPoint, the Heli model (keep it, and the hard-coded cutscene
  camera at (120,9,-18) must still see the heli: keep that sightline clear), hangar respawn (112,3.5,0) walkable, RoomLight Exfil centre
  (150,10,0). The hangar is the "floating sky military base" showcase: open sky edge with railings/guard rails, hangar doors, landing pad
  markings (cream on near-black like RIVALS hazard tape), service gear, military-green crates.
Contents may change to fit the RIVALS look; no extra kid-friendly elements RIVALS doesn't have.
Deliver: kit/rooms3.fbx in world coordinates with K_Scale3 at (0,120,0) and K_Marker3 like before; every mesh <20k tris, split by
material, bevelled, UV'd for the Tac textures (reuse tex/asset_ids.json; only new textures if truly needed, with a carrier FBX);
kit/rooms3_manifest.json; Blender previews out/rooms3/bl_*.png + contact sheet; notes/rooms3_kit.md including what placement must
hide/keep and each hook's home. Blender only (another agent is in Studio). Save kit/rooms3_kit.blend (never call read_homefile).
Time-box ~2 hours.
