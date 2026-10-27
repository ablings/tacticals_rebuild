# Arena look test (surfaces only), 2026-10-26, Shadow PC, map builder (round 3)

Edward: "aesthetics should feel good too, the map shouldn't hurt your eyes, study the textures from RIVALS Arena".
Surfaces only: no layout change. Nothing in the Arena map is changed yet. Edward picks a bay, then the chosen recipe is ported
into `fix/map_arena.lua` (formerly `fix/map_practice_range.lua`, PRANGE2 block).

**Sheet:** `out/arena_lookdev/sheet.jpg` (force-added to git). Rows A-E + RIVALS; columns: player height at 10 and 40 studs,
into the sun, aerial, a close seam shot (sill and post on the floor). Every shot is at Studio quality 21, the PC look.

## For Edward, one line per bay
- **A (what the Arena has now):** the brightest (average 161-167, top 5% at 190), with very dark lines (69% darker than the
  surface up close) that don't line up from piece to piece. This is the one that tires the eyes.
- **B (RIVALS' exact greys):** dull and dark under our Arena lighting (average 96-103), and cool lavender, off our palette.
  RIVALS' greys only look light under RIVALS' brighter lighting.
- **C (our warm grey):** calm and warm (average 134-144, top 5% 161-164, 15% under A), but the grid fades at 40 studs.
- **D (C with darker lines):** the lines read at 40 studs, but they are harsh up close (38% darker).
- **E (C with a soft, wider line), recommended:** looks like C, with lines soft up close (16.5%) that still read at 40 studs (10.8%). Up close (about 7 studs) its grid corners show a small hatch.
  That is the closest to RIVALS, which is 11% near and 11% far. It uses our same grid image three times side by side, so no new
  upload is needed.

## Recommendation: E (D if the Texture count turns out heavy)
E has warm palette greys and a world-aligned grid made of three centred copies of our own image, each black at 0.85.
- It drops A's glare: average brightness 161 → 144 at 40 studs, the brightest 5% from 190 → 161, and line harshness up close
  from 69% to 16.5%.
- It keeps RIVALS' craft:
  - two tones, solid cover 13% darker;
  - Plastic only;
  - one grid on a world 5-stud lattice, so lines run on across pieces;
  - shell textured on its inner faces only;
  - no Neon or accents.
- It reads as Tacticals rather than as a RIVALS copy.
- Its lines carry as far as RIVALS' (10.8% vs 10.8% darker at 40 studs) and much further than C's (6.9%).
- **Cost:**
  - 3 Textures per face: about 1,300 in the Arena, against about 430 for C/D and about 485 for A today.
  - In a bay the extra Textures add triangles (+24 at 10 studs, about +190 at 40 studs and aerial), not draw calls (cost
    table below).
  - Not measured on a whole Arena copy or a phone. If that turns out heavy, take **D**: the same look at 430 Textures, with the
    harsher near line.
- The clean long-term fix is a second own grid image with a 4-6 px soft line. That gives E's look at C's Texture count without
  the small hatch where E's corner ticks overlap up close, but it needs an upload under Gunsy Funsy.

## Settings per bay
All five bays have identical geometry: the Arena's pieces at the Arena's sizes. That means a floor, an L of 16-high perimeter wall
(2 thick, with a 0.6 rim), a pillar 5x10x5, a wall 10x7x3 and a low wall 6x3.4x2. It also means a vault window (posts
8x7x3.5, sill 11 x 3.4 x 2.5) and a 6-high platform reached by a 20-long wedge ramp (with a 3.4 parapet). The floor top is at
0.6, as in the Arena. MapAudit: 0 FAIL in every bay (1 HOLE warn each: the rig's open floor edges).

| | A control (current) | B RIVALS values | C Tacticals warm | D = C + darker grid | E = C + soft wide line |
|---|---|---|---|---|---|
| Material | SmoothPlastic | Plastic | Plastic | Plastic | Plastic |
| Floor | 214,214,218 | 151,153,163 | **205,199,181** | 205,199,181 | 205,199,181 |
| Structure (box, window, ramp, platform) | box 226,226,230; rest 238,238,241 | 151,153,163 | **203,196,183** | 203,196,183 | 203,196,183 |
| Solid cover (pillar, walls, low walls, parapets; Cargo in the map) | 238,238,241 | 132,134,143 | **177,171,160** (0.874 × structure, RIVALS' 132/151) | 177,171,160 | 177,171,160 |
| Grid image | rbxassetid://86361987736184 (ours) | same | same | same | same, **×3**, offsets −0.04 / 0 / +0.04 studs (centred) |
| Grid Color3 / Transparency | 34,34,34 / 0.32 | 0,0,0 / 0.75 | 0,0,0 / 0.75 | 0,0,0 / **0.65** | 0,0,0 / **0.85** each |
| Tile / offsets | 5 × 5 / 0 (each part from its own corner) | 5 × 5 / world lattice x,z = 5k, y = 0.6 + 5k | same as B | same | same |
| Faces | Top + 4 sides of every part, both sides of the box, rims | floor Top; box inner face only; rims none; pieces Top + 4 sides; ramp slope (V 0) + 2 sides | same as B | same | same |
| Textures per bay | 70 | 46 | 46 | 46 | 138 |

**Colour:** the palette's warm grey 200,196,186, corrected by measuring the render.
- The open blue sky fills horizontal faces most. As is, the floor rendered neutral (R − B 0 where the palette at that brightness
  gives 10), and the walls rendered R − B 8 (palette ≈ 11).
- The render passes a nominal shift through about 1:1. +9 R / −9 B overshot the floor to R − B 19.
- R/B alone turned the floor slightly pink (G − B 5 against the palette's 7). Final:
  - floor +5 R / +3 G / −5 B (205,199,181);
  - walls and pieces +3 R / −3 B.
- Rendered result:
  - floor 152,149,142 (R − B 10, G − B 7): the palette's hue;
  - lit wall 164,159,150 (R − B 14): about 3 points warmer than the palette. That is close enough.

## Numbers (luminance 0-255, surfaces only)
How they were measured:
- **Surface pixels:** any pixel the bay changes against a background frame from the same camera with no bay in view (`G_*.png`).
  This mask drops the sky, the void under the horizon and the sun disc. RIVALS (an enclosed box) uses a colour sky mask.
- **Glare check:** p95, the brightest 5% of surface pixels.
- **Lines:** how much darker the darkest grid line is than the surface next to it (the deepest dip of a column or row profile).
  - The profile is compared with an 81-px running median, at least 4× the widest line. At 21 px, RIVALS' 18-px soft line wrongly
    read 5.7% instead of 10.9%.
  - "Near" = the pillar's sunlit face at 10 studs (RIVALS: the end slab at 10 studs).
  - "@40" = the pillar face 40 studs away (RIVALS: the end slab 40 studs away).

| Bay | 10 studs mean / p95 | lines near | 40 studs mean / p95 | lines @40 | into sun mean / p95 | aerial mean / p95 | seam mean / p95 |
|---|---|---|---|---|---|---|---|
| A | 167 / 192 | **69%** | 161 / 190 | 13.3% | 111 / 164 | 159 / 181 | 164 / 191 |
| B | 96 / 122 | 29% | 103 / 121 | 7.4% | 49 / 112 | 102 / 117 | 102 / 123 |
| C | 134 / 163 | 27% | 144 / 161 | 6.9% | 77 / 153 | 143 / 158 | 142 / 164 |
| D | 134 / 163 | 38% | 144 / 161 | 9.3% | 77 / 153 | 143 / 158 | 142 / 164 |
| E | 134 / 163 | **16.5%** | 144 / 161 | **10.8%** | 77 / 153 | 142 / 158 | 141 / 164 |
| RIVALS Arena (own file lighting) | 153 / 185 | 10.9% | 127 / 188 | 10.8% | 99 (≈95 without the sun halo) / 109 | 141 / 188 | 101 / 180 |

**Cost per camera** (triangles / draw calls, Stats.RenderBreakdown in Edit at level 21, measured by the round-2 grader with the
other bays parked, before the unseen ramp-back Texture was dropped). With all five bays present, the round-3 grader read
different absolute numbers (e.g. C 342 / E 148 tris at 40 studs, 10 draws each), so only the relative result holds: E adds no
draw calls. The real check is port step 5.

| View | A | B | C | D | E |
|---|---|---|---|---|---|
| 10 studs | 176 / 6 | 150 / 6 | 150 / 6 | 150 / 6 | 174 / 6 |
| 40 studs | 306 / 12 | 260 / 11 | 260 / 11 | 260 / 11 | 448 / 11 |
| aerial | 306 / 12 | 500 / 14 | 474 / 11 | 474 / 11 | 662 / 11 |

- **Phone-like quality check (Studio level 5, recorded in `phone.json`):** D near 39% / @40 9.3%; E near 16% / @40 10.0%. The
  same pattern holds (`P_*.png`). At level 5 there are no sun shadows.
- **Do the lines read at 40 studs?**
  - A: yes, but loud and misaligned.
  - B: yes, faintly.
  - C: weakly.
  - D: yes, but harsh up close.
  - E: yes, at RIVALS' strength, and soft up close.
  - RIVALS: yes. Its soft, wide lines (with corner crosses) stay even from near to far (11% → 11%). A hairline falls off steeply
    (38% → 9%).
- Into the sun, the shaded faces of C/D/E average 77 against RIVALS' ≈95; B's (49) go nearly black. That is lighting (exposure
  −0.55), outside this test.
- RIVALS was captured under its file's Studio-template lighting (Brightness 3, exposure 0, Soft), which is brighter than ours.
  It is a reference, not a target.

## Viewing conditions (practice/arena_lookdev.rbxl)
- **Studio EditQualityLevel 21 (PC look) for every capture.** It is written on the sheet and in `cams.json`.
  - Round 1 was shot at the session's default level 1: no sun cast shadows, and lighting that only settled around the editor
    camera.
  - The level is set per Studio process (this place and the RIVALS copy only). Both were set back to level 1 after the
    round-3 grade (PASS), so the saved Studio settings stay as they were.
- **Technology ShadowMap, LightingStyle Realistic, PrioritizeLightingQuality on.** These are the match place's values (read
  offline from `match_place_ref.rbxl` with `tools/read_technology.py` / `tools/rbxl_lighting_dump.py`). The saved file was
  re-read after saving.
  - The hand-written blank file opened as Soft with Outlines on. Both were set by script.
  - At level 21, Soft and Realistic differ on 1.7% / 0.6% of pixels at 10 / 40 studs (mean difference 0.42 / 0.23). Frames are
    in `S_soft_D_c10/c40_f1/f2.png`, numbers in `soft_vs_realistic.json`. With sun and sky only, LightingStyle barely matters.
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
- **Cameras:**
  - FOV 70 (`ui/set/CameraConfig.lua` Hip.FOV), 5.1 above the floor (HRP 3.0 + pivot 1.5 + 0.6).
  - The viewport is 1452 × 793, checked on every frame.
  - The editor camera is moved to each bay and given a 6 s settle before shooting.
  - A frame is kept only after two consecutive matching frames.
- Sun direction (−0.71, 0.64, 0.28), so the lit faces point −X. RIVALS sun (−0.56, 0.73, −0.40).

## Port recipe for fix/map_arena.lua (when Edward picks)
1. In the PRANGE2 block, the materials and colours:
   - SmoothPlastic → Plastic;
   - floor slab → 205,199,181;
   - box walls, rims, window posts and sills, ramps and platforms → 203,196,183;
   - pillars, walls, cargo, low walls **and parapets** (3.4-high solid cover) → 177,171,160;
   - spawn pads: keep a faint tint or move them to the warm family (outside this test).
2. Grid:
   - Color3 black, 5 × 5. Transparency: C 0.75, D 0.65.
   - For E: 0.85 on three copies, with the 2nd and 3rd copies' U and V offsets −0.04 and +0.04 (mod 5), centred on the lattice.
     The step = the image's seam line: 4 texels of 512 on a 5-stud tile = 0.039 studs.
   - Offsets from `tools/lookdev/grid_lib.lua` `worldOffsets(p, face, ANCHOR, 5)` with `ANCHOR = ORIGIN + (0, FLOOR_TOP, 0)`.
     Lines run at x, z = 5k from the map origin and y = floor top + 5k.
   - Face convention (tested): (0,0) = the face's top-left seen from outside; U runs right, V runs down; on Top faces the image's
     up is the part's +Z. Captures: `gt_front`, `gt_top`, `gt_side`.
   - WedgePart slope: V = 0 (its V runs along the slope). The diagonal RampEast's faces are off the world axes, so they stay 0.
3. Faces:
   - the floor slab: Top only;
   - the box walls: the inner face only (no outside, no rim);
   - every freestanding piece: Top + 4 sides;
   - ramps: slope + 2 sides (the back is the vertical end against the deck, never seen).
4. **Rims:** the live Arena has a corner ZFIGHT. `fix/map_arena.lua` inflates every rim 0.1 on both X and Z, so the rims overlap
   at all 4 corners. Inflate only across the wall thickness, and stop the E/W rims at the N/S rims (as in `bays.lua`). Run
   MapAudit after the port.
5. Measure E's cost once on an Arena copy (Stats.RenderBreakdown, and a phone in Play) before shipping it.
6. Lighting is out of scope. B's dullness shows the Arena lighting is darker than RIVALS' (Brightness 1.6 and exposure −0.55
   against 3 and 0); judge any lighting change with this sheet.

## Files
- Practice place: `practice/arena_lookdev.rbxl`, a NEW place.
  - It was written by `tools/lookdev/new_blank_rbxl.py`: Workspace + Lighting, nobody else's place copied.
  - Bays are in `Workspace.Lookdev.Bay_A`-`Bay_E` (z 0 / 200 / 400 / 600 / 800).
  - Earlier versions and the convention test rig are in `ServerStorage.LookdevOld` (the UNDO path).
- Scripts in `tools/lookdev/`:
  - `bays.lua` (+ `grid_lib.lua` prepended) builds the bays;
  - `dev_lighting.lua` sets up the lighting;
  - `capture.py` (cameras + quality level in `cams.json`), `metrics.py` (`metrics.json`) and `sheet.py` produce the shots,
    numbers and sheet;
  - `mapaudit_edit.lua` is MapAudit inlined for a read-only run in Edit;
  - `run.py` / `mcpcli.py` drive Studio.
- RIVALS: a read-only temp copy of `Documents/RivalsArenaMap.rbxl` (md5-identical,
  `%LOCALAPPDATA%\Temp\arena_lookdev_ref\`, file set read-only). Captured only, never saved. The original was not opened.

## Lessons (filed in the vault: Grid Test Chamber, "Our variant")
- **Studio's EditQualityLevel is part of the viewing conditions.**
  - At level 1 the sun casts no shadows and lighting only settles near the editor camera.
  - Shoot looks at level 21 (PC) plus one phone-like level, and write the level on the sheet.
  - The level is per process (`settings().Rendering`); set it back afterwards.
- **World-aligned texture offsets**:
  - offset = s · (face origin − anchor) mod tile, where the origin is the face's top-left seen from outside;
  - U runs right, V runs down, and Top faces' image-up = the part's +Z;
  - RIVALS' 3-high sill (V offset 2) agrees.
- **Pick greys by the render.**
  - RIVALS' 151 renders at ~100 under a darker match lighting.
  - With an open blue sky the floor lost ~10 points of R − B and the walls ~3, against the palette at the same brightness.
  - The walls' +3 R / −3 B lands them about 3 points warm (accepted). +1.5 / −1.5 would be exact.
  - Correct the floor separately, and check G − B as well as R − B: the render passes nominal shifts through about 1:1.
- **Line width sets the far read; transparency sets the near read.** A hairline (4 texels of a 512 tile) at 0.65 is 38% → 9%
  from 10 to 40 studs. Three centred copies at 0.85 give 16.5% → 11%. RIVALS' wide line gives 11% → 11%.
- **A line-dip measure needs a median window ≥ 4× the widest line.** Re-run at twice the window: the number must move less than 0.5 points.
- **Rigs floating in the void:** mask surfaces with an empty-scene background frame, not a sky colour test.
- **Capture pitfalls:**
  - A save that restores the window shrank the viewport (1452 × 793 → 812 × 675): check every frame's size.
  - Matching frames don't prove the lighting has settled after a long editor-camera jump: move the camera, wait, then shoot.

## Open
- Not ported. The Arena keeps look A until Edward picks.
- E's Texture cost (about 1,300 in the Arena) is not measured on an Arena copy or a phone.
- Live RIVALS lighting is still unknown (the file has template lighting).
