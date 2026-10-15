# Rooms pass 2: Shop + Armory (+ their corridors and gates), Blender kit only

Same method as the hub (read notes/hub1_kit.md, notes/hub1_place.md lessons, notes/rivals_style.md, notes/layout.md, notes/hooks.md,
notes/rooms.md, the survey plans out/survey/plan_shop.png, plan_armory.png and captures). Keep every footprint, door and height:
- Shop (Rooms/Shop): ~60 x 46 at x -23..22, z 74..108, floor y 0, ceiling 13-14; reached from the hub's north gate (10w x 12h) by a
  10-wide, 12-high corridor and an 11-wide doorway.
- Armory (Rooms/Armory): ~64 x 50 at x -27..28, z -112..-81, floor y 0, ceiling 22; reached from the south gate the same way.
Contents may change to fit the RIVALS look of a sky military base: RIVALS-style shop (counter, display walls, featured item plinth,
signage) and armory (weapon racks/gun wall, featured display dais, supply counter), in the same banded wall language as the hub,
olive band 7-10, cream lane/trim lines, military-green crates (65,94,56). Must keep (hooks.md): NPC_Quartermaster and Shop_Counter
prompt (Shop), NPC_Supply, Armory_Dais and GunWall_Kit prompts and Armory.FeaturedScissors (Spin attribute) (Armory), RoomLight-tagged
lights with attribute Room (room-light centres Shop (0,6,89), Armory (0,8,-91)); leave space and positions for them (list each hook's
current position and give it a home in the new layout). Note: the Shop and Armory NPCs may be swapped (the Shop NPC opens the Kit menu,
the Armory one the Shop): do NOT change NPC behaviour; just keep their positions working.
Deliver: kit/rooms2.fbx built in place in world coordinates with a 10-stud cube K_Scale2 at (0,120,0) and marker K_Marker2 like hub1,
every mesh <20k tris, split by material, bevelled, UV'd for the Tac textures (reuse tex/ and tex/asset_ids.json: the textures are
already uploaded; only add NEW textures if truly needed, and if so make a carrier FBX kit/rooms2_tex.fbx), a manifest
kit/rooms2_manifest.json (mesh -> colour, material, MaterialVariant name from MaterialService.TacHub1, collision), Blender previews
out/rooms2/bl_*.png + contact sheet, and notes/rooms2_kit.md including what the placement script must hide/keep. Blender only: no
Studio. Save kit/rooms2_kit.blend (open it fresh via the MCP; never call read_homefile). Time-box ~2 hours.
