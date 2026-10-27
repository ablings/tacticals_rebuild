# Arena look test (surfaces only), 2026-10-26, Shadow PC, map builder

Edward: "aesthetics should feel good too, the map shouldn't hurt your eyes, study the textures from RIVALS Arena".
Surfaces only: no layout change. Nothing in the Arena map is changed yet. Edward picks A / B / C / D, then the chosen recipe is
ported into `fix/map_arena.lua` (formerly `fix/map_practice_range.lua`, PRANGE2 block).

**Sheet:** `out/arena_lookdev/sheet.jpg` (force-added to git). Rows A-D + RIVALS; columns: player height at 10 and 40 studs,
into the sun, aerial, a close seam shot (sill and post on the floor).

## For Edward, one line per bay
- **A (what the Arena has now):** the brightest (average 160, top 5% at 195). Near-white everywhere, with dark lines that don't
  line up from one piece to the next. This is the one that tires the eyes.
- **B (RIVALS' exact greys):** dull and dark under our Arena lighting (average 90-102), and cool lavender, off our palette. RIVALS'
  greys only look light under RIVALS' brighter lighting.
- **C (our warm grey):** calm and warm, close to RIVALS in brightness (127-142), never glaring (top 5% 161, 17% under A). The grid
  is faint at 40 studs.
- **D (C with firmer lines), recommended:** looks just like C, but the lines still read across the map at 40 studs.

## Recommendation: D
Warm palette greys and a world-aligned grid at Transparency 0.65:
- It drops A's glare: average brightness 160 → 142 at 40 studs, and the brightest 5% from 195 → 161. No near-white pixels anywhere.
- It keeps RIVALS' craft:
  - two tones, solid cover 13% darker;
  - Plastic only;
  - one grid on a world 5-stud lattice, so lines run on across pieces;
  - shell textured on its inner faces only;
  - no Neon or accents.
- It reads as Tacticals rather than as a RIVALS copy.
- C's 0.75 grid matches RIVALS' setting, but on our thinner-line image it reads only 5.3% darker at 40 studs (RIVALS 10.6%). D's
  0.65 gives 7.8% and stays quiet up close.

## Settings per bay
All four bays have identical geometry: the Arena's pieces at the Arena's sizes. That means a floor, an L of 16-high perimeter wall
(2 thick, with a 0.6 rim), a pillar 5x10x5, a wall 10x7x3 and a low wall 6x3.4x2. It also means a vault window (posts
8x7x3.5, sill 11 x 3.4 x 2.5) and a 6-high platform reached by a 20-long wedge ramp (with a 3.4 parapet). The floor top is at
0.6, as in the Arena.

| | A control (current) | B RIVALS values | C Tacticals warm | D = C + firmer grid |
|---|---|---|---|---|
| Material | SmoothPlastic | Plastic | Plastic | Plastic |
| Structure (floor, box, window, ramp, platform) | cover/window/ramp 238,238,241; box 226,226,230; floor 214,214,218 | 151,153,163 | **203,196,182** | 203,196,182 |
| Solid cover (pillar, walls, low walls; Cargo in the map) | 238,238,241 | 132,134,143 | **177,171,158** (0.874 × structure, RIVALS' ratio 132/151) | 177,171,158 |
| Grid image | rbxassetid://86361987736184 (ours) | same | same | same |
| Grid Color3 / Transparency | 34,34,34 / 0.32 | 0,0,0 / 0.75 | 0,0,0 / 0.75 | 0,0,0 / **0.65** |
| Tile | 5 × 5 | 5 × 5 | 5 × 5 | 5 × 5 |
| Offsets | 0 (each part tiles from its own corner) | world lattice x,z = 5k, y = 0.6 + 5k | same | same |
| Faces | Top/Front/Back/Left/Right of every part, both sides of the box | floor Top; box inner face only; rims none; freestanding pieces Top + 4 sides; ramp slope + back + sides | same as B | same as B |
| Neon / accents | none | none | none | none |

C/D colour = the palette's warm grey (200,196,186) + 3 R / − 4 B. The rendered lit wall came out at 165,159,149 (R − B = 16;
the palette's R − B is 14). The training-room lesson (+12 R / −14 B) was measured under **Future** in a closed room. Under the match
place's **ShadowMap** with an open sky, the blue shift is only a few points (first C at 178,174,164 rendered 143,140,133), so
measure before compensating.

## Numbers (surfaces only, sky masked; luminance 0-255)
Glare check = the brightest 5% of surface pixels (p95). Line contrast = how much darker a grid line is than the surface next to it.
The **@40** crop is the pillar's sunlit face 40 studs away (RIVALS: the end slab 40 studs away). The **@53** crop is the back wall
53.5 studs away, above the pieces.

| Bay | 10 studs mean / p95 | 40 studs mean / p95 | into sun mean / p95 | aerial mean / p95 | seam mean / p95 | lines @40 | lines @53 | lit wall RGB @53 |
|---|---|---|---|---|---|---|---|---|
| A | 160 / 195 | 160 / 184 | 121 / 166 | 129 / 176 | 154 / 187 | (on the edges, see note) | 9.4% | 180,180,185 |
| B | 90 / 120 | 102 / 122 | 55 / 110 | 99 / 115 | 92 / 121 | 6.2% | 4.2% | 116,119,134 |
| C | 127 / 161 | 142 / 161 | 84 / 152 | 120 / 155 | 130 / 161 | 5.3% | 3.7% | 165,159,149 |
| D | 127 / 161 | 142 / 161 | 84 / 152 | 120 / 156 | 130 / 161 | **7.8%** | 5.2% | 165,159,149 |
| RIVALS Arena (own file lighting) | 136 / 181 | 117 / 174 | 89 / 110 | 138 / 192 | 105 / 164 | 10.6% | | 120,133,159 |

- **Do the lines read at 40 studs?** A: yes, loud (59% darker up close) and misaligned. B: yes, faint. C: barely: 5% is visible
  on a flat lit face but lost on shaded or grazing faces. D: yes, clearly, without being loud up close (35% darker at 10 studs, on
  a hair-thin line). RIVALS: yes, and the strongest, helped by its thicker lines and corner crosses.
- A's @40 pillar crop measures 1.2% only because A's unaligned lines happen to fall on the pillar's edges, outside the crop.
- No surface pixel reaches 230 in any bay. The 1.2-1.6% "≥230" in the sun shots is the sun disc.
- Into the sun, C/D's shaded faces average 84, about RIVALS' 89. B's are 55: heavy and almost black.
- RIVALS was captured under its file's Studio-template lighting (Brightness 3, exposure 0, Soft). It is brighter than our Arena
  lighting, so its numbers are for reference, not a target.

## Viewing conditions (practice/arena_lookdev.rbxl)
- **Technology ShadowMap, LightingStyle Realistic, PrioritizeLightingQuality on.** These are the match place's values (read
  offline from `match_place_ref.rbxl` with `tools/read_technology.py` and the new `tools/rbxl_lighting_dump.py`). The saved file
  was re-read after saving.
- **Base lighting = match_place_ref's Lighting:**
  - Ambient 72,76,84; ShadowSoftness 0.12; ColorShift 0; Roblox's default Sky.
  - Atmosphere, Bloom and MapGrade, all Enabled.
- **On top of that, MapInfo.Lighting from fix/map_arena.lua** (what RoundManager's applyMapEnv applies when the Arena wins the
  vote):
  - ClockTime 15.2, latitude 40, Brightness 1.6, exposure −0.55;
  - Ambient 86,86,88, OutdoorAmbient 112,112,114, EnvDiffuse 0.25, EnvSpecular 0.2;
  - Atmosphere 0.26 / 0.05 / haze 1 / glare 0.1;
  - Grade contrast 0.14, saturation 0.05, tint 255,250,244;
  - Bloom 0.4 / 24 / 1.6.

  Script: `tools/lookdev/dev_lighting.lua`.
- FOV 70 (`ui/set/CameraConfig.lua` Hip.FOV). Cameras sit 5.1 above the floor (HRP 3.0 + pivot 1.5 + 0.6), at a 1452 × 793
  viewport. Every frame was kept only after two consecutive matching frames.
- Sun direction (−0.71, 0.64, 0.28), so the lit faces point −X. RIVALS sun (−0.56, 0.73, −0.40).

## Port recipe for fix/map_arena.lua (when Edward picks C or D)
1. In the PRANGE2 block, the materials and colours:
   - SmoothPlastic → Plastic;
   - floor, box, rim, windows (posts and sill), ramps, platforms and parapets → 203,196,182;
   - pillars, walls, cargo and low walls → 177,171,158;
   - spawn pads: keep a faint tint, or move them to the warm family. That is Edward's call; they are outside this test.
2. Grid: Color3 black; Transparency 0.65 (D) or 0.75 (C); 5 × 5. Offsets from `tools/lookdev/grid_lib.lua` `worldOffsets(p,
   face, ANCHOR, 5)` with `ANCHOR = ORIGIN + (0, FLOOR_TOP, 0)`, so lines run at x, z = 5k from the map origin and y = floor top
   + 5k.
   - The face convention is tested: a texture's (0,0) is the face's top-left seen from outside, U runs right and V runs down.
     On Top faces the image's up is the part's +Z.
   - Captures: `gt_front`, `gt_top`, `gt_side` in `out/arena_lookdev/`.
3. Faces:
   - the floor slab: Top only;
   - the box walls: the inner face only (no outside, no rim);
   - every freestanding piece: Top + 4 sides;
   - ramps (WedgePart): slope + back + 2 sides. The slope's V runs along the slope, so it stays 0.
   - The diagonal RampEast's faces are off the world axes, so `worldOffsets` leaves them at 0.
4. Lighting is out of scope here. B's dullness shows the Arena lighting is darker than RIVALS' (Brightness 1.6 and exposure −0.55
   against 3 and 0), so any later lighting change should be judged with this sheet.

## Files
- Practice place: `practice/arena_lookdev.rbxl`, a NEW place.
  - It was written by `tools/lookdev/new_blank_rbxl.py`: Workspace + Lighting only, nobody else's place copied.
  - Bays are in `Workspace.Lookdev.Bay_A`-`Bay_D` (z 0 / 200 / 400 / 600).
  - Earlier versions and the convention test rig are in `ServerStorage.LookdevOld` (the UNDO path).
- Scripts in `tools/lookdev/`:
  - `bays.lua` (+ `grid_lib.lua` prepended) builds the bays;
  - `dev_lighting.lua` sets up the lighting;
  - `capture.py` (cameras in `out/arena_lookdev/cams.json`), `metrics.py` (`metrics.json`) and `sheet.py` produce the shots,
    numbers and sheet;
  - `run.py` / `mcpcli.py` drive Studio.
- RIVALS: a read-only temp copy of `Documents/RivalsArenaMap.rbxl`
  (`%LOCALAPPDATA%\Temp\arena_lookdev_ref\RivalsArena_readonly_copy.rbxl`, file set read-only). Captured only, never saved.
  The original file was not opened.

## Lessons (filed in the vault: Grid Test Chamber, "Our variant")
- **World-aligned texture offsets**:
  - offset = s · (face origin − anchor) mod tile, where the origin is the face's top-left seen from outside;
  - U runs right, V runs down, and Top faces' image-up = the part's +Z;
  - RIVALS' 3-high sill (V offset 2) agrees.
- **Match greys to the lighting by measuring the render.** RIVALS' 151 renders at ~100-116 under a darker match lighting. The warm
  shift needed under ShadowMap with an open sky was only +3 R / −4 B, against +12 / −14 under Future in a closed room.
- **A thin-line grid image (2 px of 512) needs ~0.65 transparency** for its lines to read at 40 studs. RIVALS' 0.75 works for
  RIVALS because its image has thicker lines and corner crosses.
- **Capture pitfalls:**
  - screen_capture borrows the camera, but the lighting grid follows the *editor* camera. A bay 600 studs away rendered flat with
    no shading until the editor camera was moved there first.
  - A save that restores the window can shrink the viewport (1452 × 793 → 812 × 675). Check the image size on every capture.
  - A hand-written blank .rbxl's LightingStyle 0 opened as Soft with Outlines on: set them by script and read them back from the
    saved file.
- With sun + sky only, LightingStyle Soft and Realistic rendered the same numbers (it changes only local-light shadows).

## Open
- Not ported. The Arena still has look A until Edward picks one.
- If Edward wants RIVALS-strength lines (≈10% at 40 studs) without louder close-up lines, the next step is a second own grid image
  with 4-6 px lines and small corner ticks. That needs an upload under Gunsy Funsy.
- Cast shadows look soft in Edit captures at this sun angle. Check them in Play / the client before judging the shadow look.
