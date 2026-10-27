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

## Feed the duels kit: automatic (Edward, 2026-10-24)
This repo is watched: when a Claude session here ends, the `roblox-kit-keeper` agent reviews the new commits in the background
and ports anything general (round flow, queue, arenas, rewards, remotes, combat validation, UI components) into
`Documents/roblox_kits` with a test. You don't run it. **Write commit messages that say what was wrong and why**: that's its input.

## Grade before you report (Edward, 2026-10-24)
Before telling Edward a visible or playable change is done (lobby, map, UI, animation, gameplay flow such as queue / teleport /
matches), run the matching grader agent at effort xhigh (roblox-model / map / ui / animation / systems-grader). Fix its blocking and
major items first, then report with its verdict. Full rule: vault `meta/Claude Standing Rules.md` 1c.

## Hard rules
- **Never edit, save or publish the live place** (it is Team Create: edits sync to the cloud). Edward ordered the port on
  2026-10-16: the result is `Tacticals_main_ported.rbxl`, built locally; Edward publishes it himself (notes/port_manifest.md).
  **2026-10-16 ~14:15, Edward in the lead's chat:** "Once you're ready i give you full permission to port everything to the
  tactical lobby and save what you need to save i am not at my pc so u have to be the one to do this". The lead does Save to Roblox
  of Tacticals_main_ported.rbxl onto the tacticals place (version history keeps the old one); Publish only if Edward says so.
  Old rule: Work only in `Tacticals_rebuild.rbxl` (a local copy downloaded by Edward,
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
  RIVALS inventory (read 2026-10-15): 388 ParticleEmitters + 94 Beams, all attached to a purpose: dummy-head hit FX (Training), queue
  holograms, featured weapon/bundle display sparkles, jump shards, lamp light beams, tightrope beams, one vent VFX. **No ambient
  particles** (no air dust/motes, drifting specks, steam, random sparks). Rule: keep purpose-bound FX (queue pads/holograms, featured
  displays, dummy hits, lamp/beam light shafts, Training extras); remove ambient ones (the floating white specks, motes, steam, sparks,
  drifting particles in the hub/rooms/hangar).
- After the overlap fix: a fresh agent does a **lap in Play mode** at player height through every room; anything still overlapping is
  logged with its **root cause**; the causes and prevention rules go into the vault (general rules without game names in
  `02 Modeling/Model Proof Check` and `03 Map Building/Map Proof Check`; Tacticals notes in `07 Projects/Tacticals/`; see
  `wiki/meta/Vault Guide.md`, vault restructured 2026-10-24) (Edward, 2026-10-15).
- After the lap and the particle cleanup, once everything is sound: **RIVALS vs Tacticals diff**. Go through the RIVALS place, then the
  rebuild, and list everything RIVALS has that ours doesn't (rooms/areas, interactive features, displays, signage, props, lighting,
  effects), with captures. Edward picks which to implement; build nothing from the list until he does (Edward, 2026-10-15).

## Overnight polish (Edward, 2026-10-15 night)
- Plan and progress: `notes/overnight_polish.md`. RIVALS = aesthetics blueprint (craft); theme = ours (sky military base, olive/cream).
  Every room must look different. Everything logically sound (checklist in the plan).
- The UI session (`local_f4630eda-86ab-4003-89fd-fb92f76724bc`) drives the primary monitor all night: no computer use without its
  OK. Studio MCP / Blender MCP only; saves and Import 3D are batched into pauses it agrees to.
