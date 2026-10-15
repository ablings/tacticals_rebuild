# Hub sample, pass 1: RIVALS-style shell kit + own textures (Blender + PIL; no Studio yet)

Goal: the first room Edward approves the new look on. The hub hall (172 x 82, floor y 0, roof y 68-73, long walls on a ~13.75-stud
bay grid; see notes/layout.md) rebuilt as an own RIVALS-style mesh kit with Tacticals colours. Same footprint, doors and openings
as now: north 10w x 12h corridor gate to the Shop, south gate to the Armory, west riser/landing/stairs to Duels (y 4 -> y 16, 11-wide
door), east 22w x 18h tunnel to the hangar, catwalks y 31 and bridges y 27 (set dressing). Read notes/rivals_style.md (the style
rules, module sizes, palette table, texture shopping list), notes/layout.md, notes/hooks.md, notes/rooms.md, CLAUDE.md, and the vault
`roblox-build-workflow/6 Blender Modelling Method.md` and the visual-quality memory: assets must be well defined (bevels that catch
light, real sub-parts, colour splits), not flat boxes.

## Deliverables (this pass stops before Studio)
1. **Own textures** (`tex/`, PNG, own work, no RIVALS ids): from the style guide's shopping list, at least: smooth concrete (tiling,
   subtle), concrete with panel seams, corrugated/ribbed metal, metal floor grate/plate, a panel-line trim strip, a grime/AO overlay,
   hazard stripe (cream on near-black), floor lane marking. 512-1024 px, seamless, neutral grey (tinted in Studio), plus normal and
   roughness maps where they help. Reuse/adapt our replica tiles in `C:/Users/aroki/Documents/rivals_practice/tex/` where suitable.
   A contact sheet `out/hub1/tex_sheet.jpg`. Write `tex/textures.json`: file -> intended MaterialVariant / Texture use, StudsPerTile.
2. **Hub shell kit** in Blender 5.2 (the open "(Unsaved)" Blender window via the Blender MCP; save it as
   `C:/Users/aroki/Documents/tacticals_rebuild/kit/hub_kit.blend`; never call read_homefile). Generator `tools/hub_kit.py`.
   RIVALS module language: wall bay module (body + lower band + upper band split into separate meshes for colour), the olive accent
   band 3 studs tall at 7-10 above the floor, pilasters/columns with bevels, door frames for each gate (with the band crossing the door
   head), stair and riser pieces with nosings and kerbs, ceiling/roof panels and beams, catwalk and bridge sections with railings,
   Neon strip pieces (separate meshes) for floor rings/lines and ceiling lines, the central spawn disc (radius 12) as a hero piece in
   the style (rings, inlays, Neon lines), and a few sky-military-base props in the RIVALS manner (crates in military green
   (65,94,56) like RIVALS, cases, consoles). Bevel all edges (0.05-0.15), weighted normals, UVs for the tiling textures, Z-up export,
   < 20k triangles per mesh, split by material/colour. Author the shell IN PLACE in hub coordinates (1 Blender unit = 1 stud) so it
   imports at the right spot, plus repeated modules at the origin for instancing if that is cleaner.
3. Export `kit/hub_r1.fbx` with a 10-stud scale cube `K_Scale1` and an asymmetric marker `K_Marker1`. Blender preview renders
   (Eevee, warm-white key, the palette) of the hall and the hero pieces into `out/hub1/bl_*.png` plus a contact sheet.
4. Report `notes/hub1_kit.md`: pieces, triangle counts, colours/material per mesh, textures, how each part maps to the current hub
   parts, and what the placement script must do (hide the old shell meshes in Unique/Instances, keep every hook from hooks.md).

## Rules
Own geometry and textures only. Do NOT touch Roblox Studio this pass. No commits. Time-box ~2 hours.
