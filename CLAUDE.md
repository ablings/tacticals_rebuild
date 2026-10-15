# tacticals_rebuild: shared instructions for every Claude session

Edward's real game **Tacticals** (place 126491009194165). Rebuild its lobby in the **RIVALS style** with Tacticals' own colours.
Started 2026-10-14 on the main PC.

## What Edward asked for
- **Keep the room layout** exactly as the current lobby (every room's footprint, doors, connections, heights). What is *in* each room
  may change to whatever fits.
- **Look like RIVALS:** RIVALS' wall, floor, door and trim treatment (neutral greys on concrete/metal, concrete / concrete-panel /
  corrugated material variants, tiling textures, Neon trim), RIVALS' lighting, RIVALS' texturing approach. RIVALS is the "perfect
  game": "kid friendly" means matching RIVALS' look and nothing more. **Do not add kid-friendly elements RIVALS does not have.**
- **Colour accents from the Tacticals loading screen** in place of RIVALS' purple and yellow: olive (138,156,74), dark olive
  (107,122,58), cream (236,232,218), warm grey (200,196,186), sage (167,173,152), near-black (10,12,10).
- **Theme:** a floating sky military base.

## Hard rules
- **Never edit, save or publish the live place.** Work only in `Tacticals_rebuild.rbxl` (a local copy downloaded by Edward,
  2026-10-14). File > Save to File only; never Save to Roblox, never Publish.
- **Own assets only.** Copy RIVALS' lighting *values* and *method*; never use RIVALS' asset ids, meshes, textures or images.
  Our RIVALS-replica textures (rivals_practice/tex, hallway_tex) are own work and may be reused.
- **Uploads go under the Roblox group "Gunsy Funsy"** (Import 3D Creator = the group; images via Creator Hub in the built-in browser,
  where Edward is logged in).
- The RIVALS reference place (`Downloads/place 17625359962 RIVALS(1).rbxl`) is read-only: never write or save it.
- All Studio windows are on Edward's **right monitor** (XF243Y P); his left monitor is his. Keep Firefox, Discord and Pokemon TCG Live
  as they are; never click in them.
- Never send Delete, Backspace or Ctrl+A to Studio by computer use.
- Builder and reviewer are different agents; send Edward a comparison sheet each round; vault notes as in the other practices.

## Survey (2026-10-14, read-only)
- Workspace.LobbyMap: ~1,982 MeshParts, ~1,050 Parts, 83 lights. Hub around the origin (~186 x 110); Rooms/Shop north (+z),
  Rooms/Armory south (-z), Duels west (x -138..-92), Exfil east (x 114..134), TimesSquare east (x 167..438), Showroom at y ~400,
  Training floating at y ~600, City backdrop below. Older versions in ServerStorage (LobbyMap_V1/V2, RoomKit, PropKit...).
- RIVALS lighting: LightingStyle Realistic, PrioritizeLightingQuality on, Brightness 3, Ambient (121,121,121), OutdoorAmbient
  (198,198,193), ExposureCompensation -0.15, ClockTime 12, ColorShift_Top (255,217,184), ColorShift_Bottom (170,126,213) purple ->
  swap for a palette tint, ShadowSoftness 0.5, GlobalShadows on, Atmosphere Density 0.255 Offset 0.2 Colour (140,196,231)
  Decay (92,60,14) Haze 1.82 Glare 0.
- RIVALS materials: Plastic/SmoothPlastic most parts, Neon 578, Metal 531, Concrete+Concrete-02a 368, Metal+Concrete-02a 238,
  Concrete+Corrugated_02a 106, Pearlescent variants, ConcretePanels-02a, Corrugated_01a, Wood01a; 1,438 Texture objects; neutral greys
  (151,153,163), (163,162,165), (108,107,106), (124,123,126), (48,48,48); accents purple (193,70,255)/(115,73,162), gold
  (255,215,0)/(163,135,51).

## Lighting state (2026-10-14 22:36)
- RIVALS lighting values applied to the copy by script (originals backed up in ServerStorage._PreRebuildLighting): Realistic,
  Brightness 3, Ambient 121, exposure -0.15, ClockTime 12, sage ColorShift_Bottom, one Atmosphere with RIVALS values, Lobby_Bloom /
  Lobby_DOF / SunRays disabled (kept by name: scripts look them up). Two Sky objects remain (Sky, Lobby_Sky): decide which.
- Technology is still ShadowMap (3): patch to Future (4) offline with `tools/set_technology.py` while the place is closed.

## Computer use (Edward, 2026-10-14 23:00)
- While Edward is on the PC: do NOTHING that needs tabbing into a window (no computer use, no File menu saves, no Import 3D).
  Work through scripts, the Studio MCP and the Blender MCP only; leave saves and imports for Edward or for when he says so.

## Queued (Edward, 2026-10-15)
- After the rebuild: **remove particle effects that RIVALS doesn't have** (compare RIVALS' lobby ParticleEmitters/Beams/Trails/Fire/
  Smoke/Sparkles with Tacticals'; hide/disable UNDO-ably, and remove the matching LobbyFX tags so scripts don't re-enable them).
