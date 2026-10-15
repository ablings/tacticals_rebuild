# RIVALS style guide for the Tacticals rebuild

Written 2026-10-14 from a read-only survey of `place 17625359962 RIVALS(1).rbxl` (Studio id 7341d80a…, nothing written or saved)
plus the RIVALS-replica vault notes (`How RIVALS Is Built`, `Iteration 5 - Review Rounds` material pass r17-23,
`Construction Styles - Mesh Kit vs Parts-First`). Reference sheet: `out/style/rivals_style_sheet.jpg` (12 labelled captures;
raw frames in `out/style/raw/`). Captures are edit-time renders and look darker than in play; judge **tone relationships**, not
absolute brightness, from them.

Numbers below are measured unless marked *(est.)* (estimated from captures).

---

## 0. The RIVALS look in one paragraph
A dark, clean sci-fi hangar: **near-black floors** (36-62 grey), **mid-grey walls** (88-124) with soft chamfered, curved mesh
shells, **plain stock metal** trims and pillars (67-108), and almost no colour except two accents used as **thin lines**:
gold/hazard-yellow (bands, rings, ceiling slashes, sign arrows) and purple (lane lines, one team). Light comes from a bright, warm
global sun/ambient with soft shadows, plus **Neon** fixtures (capsule wall lights, ceiling strips) rather than many real lights.
Surface richness comes from material variants (smooth concrete, concrete panels, fine corrugation) and a few tiling Texture
overlays, never from busy colour. Everything is readable at a glance: dark floor vs lighter wall, saturated lines only where
something is interactable or directional.

---

## 1. Global material setup (copy the method, own maps)

### 1.1 MaterialService base-material overrides (the hidden half of the look)
RIVALS overrides the stock look of the common materials (`Use2022Materials` = false, then per-material overrides):

| Base material | RIVALS override | What it does |
|---|---|---|
| Concrete | `Concrete2022` (StudsPerTile 10) | smooth, low-noise concrete instead of the speckled current default |
| Metal | `Metal 2022` (10) | plain satin painted metal, no scratch speckle |
| DiamondPlate | `Diamond Plate 2022` (10) | |
| Brick | `Brick 2022` (20) | |
| Rubber | `RubberSmooth` (10) | |
| all others | themselves | |

**Lesson from our replica (r19-r22):** without these overrides every plain Concrete/Metal part reads "granite/pitted". For Tacticals,
set our **own** plain-concrete and plain-metal variants as the Concrete and Metal overrides (we already have them:
`rivals_practice/tex/pbr/concrete_plain_*`, `metal_true_*` + `metal_full_metalness.png`, which may be reused per CLAUDE.md).

### 1.2 Environment MaterialVariants actually used on the map
(MaterialService holds ~230 variants; ~200 are weapon-skin variants and irrelevant.)

| Variant | Base | StudsPerTile | Pattern | Maps | Used on |
|---|---|---|---|---|---|
| Concrete-02a | Concrete | 10 | Organic | colour+normal+rough | **the default wall/ceiling/frame mass** (31% of visible area) |
| Concrete-01a | Concrete | 10 | Organic | colour+normal+rough | big hub floor slabs (62 grey), ceiling coffers |
| ConcretePanels-02a | Concrete | 20 | Regular | colour+normal+rough | wall plates with panel seams (32 parts) |
| Corrugated_02a | Concrete | 10 | Regular | **normal only** + rough | ribbed hall shells, light bands (106 parts) |
| Corrugated_01a | Metal | 16 | Regular | **normal only** + rough + metal | corrugated metal floor inserts, cladding (38) |
| Pearlescent_01a/b | SmoothPlastic | 0.75 | Regular | normal/rough/metal | glossy ceiling panels, sign plates, ad frames |
| Wood01a / WoodPlank01a | Wood/WoodPlanks | 10 | | | crates, pallets |
| Grass_01b | Grass | 20 | | | outdoor hills only |

Note: 238 Metal parts carry `Concrete-02a`, which never renders (base mismatch), so in practice **all trims, kerbs, struts and ledges
are plain (overridden) Metal**. Do not reproduce that mistake; just use plain Metal.

### 1.3 Material mix by visible surface area (Lobby, parts with Transparency < 0.9)
Plastic 151,153,163 15.5% (almost all = the Shooting-range grid walls) · Grass 17% (outdoor hills) · Concrete + Concrete-02a ~30% ·
Corrugated_02a ~6.5% · Metal (plain) ~6% · Neon ~3% · Concrete-01a ~3% · ConcretePanels ~1% · Glass < 1%.
Inside the hub (ignoring range and hills): **~70% concrete variants, ~15% metal, ~5% Neon, the rest plastic/glass dressing.**

---

## 2. Surfaces by role

Colours are RGB 0-255. "M" = MeshPart, "P" = Part.

| Role | Material + variant | Base colours (most used first) | Notes and typical sizes |
|---|---|---|---|
| **Walkable floor (hub)** | Concrete + Concrete-01a; Concrete + Concrete-02a; Metal (plain) ring pieces; Metal + Corrugated_01a inserts | 62,62,62 (main slab) · 36,35,36 (darkest rings/borders) · 75 · Metal 108,107,106 rings · corrugated 80,79,78 | Floor top at y -681. Big slabs 97x2x97 and 62x3x81 (meshes). Darker borders frame lighter centres; centre platform metal 48x3x48. Floor is always **the darkest large surface** in view. |
| **Floor (pads / bays)** | Metal 108,107,106 with a 20x20-stud panel-line **Texture** (Top, tint 81 grey, opaque) | 108 metal, texture tint 81 | 88 such parts (queue pad bases). Pad 15.75 x 12 framed by 0.38 x 0.5 Neon. |
| **Walls** | Concrete + Concrete-02a (mesh shells: CenterWalls, WingWalls, PadWalls, SensArch) | 120,120,122 · 112,111,113 · 107,107,108 · 94,94,95 · 88,87,89 · 79,79,80 | Per-material colour split on meshes: base / mid / top bands differ by 5-20 levels (e.g. 107 body, 88 lower kick, band 255,188,53). Wall pieces 19-31 wide x 9-25 tall; curved shells. |
| **Wall cladding / plates** | Concrete + ConcretePanels-02a (20-stud tile) | 102,102,103 · 88,88,89 · 83,89,95 | 24 Parts of 102 grey: flat plates over the mass for panel seams. |
| **Ribbed shells / bands** | Concrete + Corrugated_02a | 141,140,143 (lightest large surface) · 71,70,72 · 67,67,67 · 64,55,71 (purple-tinted variant) | Big curved hall ceilings/shells. Ribs come from a normal map only, so colour is set by Part.Color. |
| **Ceilings** | Concrete + Concrete-02a/-01a coffers; Pearlescent glossy panels; Concrete + Corrugated_02a | 112,111,113 · 100 · Pearlescent 69,64,74 | Coffers 13x3x26 and round drums 32-48 wide. Ceiling height 24-37 studs above floor (hub 37, market 27-29, weapons room 23). Recessed Neon strip lights (1.8 x 0.4 x 4.5). |
| **Doors** | Metal (plain) BayDoor/BlastDoor/CTADoor meshes; Concrete-02a jambs; door voids = **black Neon** (0,0,0 or 34,34,34) | Metal 72,72,72 · 89,89,90 · Concrete 79-94 | Bay door 24 wide x 32 tall; blast door 43 x 24; shop door/portal 38 wide x 16.5 high leaf with a **3-stud stripe** (255,188,53 Plastic) at its foot. Openings behind doors are unlit black Neon slabs, so closed doors read as deep openings. |
| **Door frames / arches** | Concrete + Concrete-02a outer (107-120); Metal inner lip (72-108, 0.5 thick reveal plates) | 107,107,108 · 115,115,116 · 120,120,122 · Metal 72 / 102 / 108 | Frames are big: 20 x 28 x 54, 12.8 x 20 x 39.5, 22 x 60 x 62. Two-tone: lighter concrete surround, darker metal reveal. Chamfers *(est.)* 0.5-1 stud on edges, large radii (4-6) on curved shells. |
| **Trims / skirting / kerbs / ledges** | Plain Metal | 108,107,106 (most) · 124,123,126 · 117,116,118 | Thin: 0.5-2 studs. Skirting/kick zones are the darker concrete split of the wall mesh (79-94). |
| **Accent band (hazard)** | Concrete-02a or Plastic, colour 255,188,53 | hazard yellow | **3 studs tall, 7-10 studs above floor**, running round the market/hall walls and across door leaves at the same height (one continuous datum line). |
| **Pillars / beams** | Plain Metal meshes (Supportbeam) | 67,67,67 · 76,76,76 | Support beams 3 x 57 x 30 (deep I-section ribs). Pillars in the hub are the concrete wall shells (Concrete-02a 94-120). |
| **Railings / barriers** | Metal + rope dressing (CarpetRope 245,178,43 gold posts / 159,55,62 rope) | | Few: RIVALS keeps players in by walls and clip parts rather than railings. Velvet-rope posts only at shop displays. |
| **Stairs / ramps** | Concrete-02a steps, Metal nosing *(est. from capture 3)* | step 88-110, nosing metal 108 | Wide shallow steps (capture 3). Ramps are wedges. |
| **Signs (big)** | Neon meshes (sign art) on a Plastic 44,44,45 backplate; Neon outline 252,250,255 or gold 163,135,51; purple 115,73,162 arrows | | DUELS / MARKET style: white Neon lettering, a coloured Neon outline/arrow, dark backplate, hung over an arch entrance. |
| **Signs (labels)** | SurfaceGui text on SmoothPlastic boards | board 39,39,39; text white / 58,58,58 / black | One font family (one Roblox font asset) at Medium/Bold/Heavy weights; no text stroke; transparent label background. Small white plates with black caps text ("UGC SHOP", "HOLOBAY 01") above doors. |
| **Signs (warning plates)** | SmoothPlastic + Pearlescent_01b small plates with a decal | 229,179,30 yellow, 225,70,93 red | 3 x 2.2 and 4 x 3 plates on pillars (capture 12). |
| **Floor graphics** | SurfaceGui / decal on the floor | KEEP CLEAR text 255,176,65 · stencil labels grey (CARGO ELEVATOR, WEST GATE) · white chevrons | Path arrows are thin Concrete meshes 2.5 x 5 (48-50 grey) or white decals. |
| **Wall lights** | Metal housing 108,107,106 + Neon capsule 161,155,140 | | WallLight 2.9 x 9 x 1.8: a vertical Neon capsule split by two dark metal straps (capture 8). ~38 placed; centre ~14 studs above floor (above the band) on wall piers. |
| **Range (training)** | Plastic 151,153,163 + 5x5 grid Texture (black, 0.75 transparency, all six faces) | | 1,259 of the 1,438 Textures. "Simulation" look: light grey boxes in the open sky. |
| **Dressing** | crates Wood01a; NosCrate SmoothPlastic **65,94,56 (military green!)**; barrels Metal | | RIVALS already has military-green crates in the weapons room; matches Tacticals. |
| **Camera blockers** | SmoothPlastic 139,39,79 thin planes | | Invisible-ish helpers; ignore. |

### 2.1 Texture objects (1,438 total, only 9 distinct images)

| # | Image kind *(described from in-place captures)* | StudsPerTile U x V | Transparency | Color3 tint | Face(s) | Host | Count |
|---|---|---|---|---|---|---|---|
| T1 | thin square grid lines (cross ticks at corners) | 5 x 5 (1.75 on sign titles) | 0.75 | black (white on dark parts) | all six | Plastic 151,153,163 range boxes | 1,266 |
| T3 | large panel-line / seam layout | 20 x 20 | 0 (0.9 when used as a dark overlay) | 81 grey (also 255,176,65 / 255,200,60 for gold-floored pads and bay-door undersides) | Top | Metal 108 pad floors, door sides | ~110 |
| T4 | 2 x 4 rectangular tile pattern | 2 x 4 | 0 | 59 grey | four sides | Metal 62 display walls | 24 |
| T5 | 3 x 3 grate/mesh pattern | 3 x 3 | 0 | 70-80 grey | Top / sides | black SmoothPlastic and dark Glass (grates, pit floors) | 20 |
| T2 | 4 x 4 ribbing | 4 x 4 | 0 | 83 grey | sides | garage door slats | 4 |
| T9 | 4 x 4 noise/grime | 4 x 4 | 0.9 | 152 grey | various | black metal | 4 |
| T6/T7 | fine grime/scratches | 0.5 / 0.75 | 0.75 | black | front/back | plastic 48,42,61 | 4 |
| T8 | louvre strip (light diffuser) | 0.625 x 1 / 0.94 x 1.5 | 0.5 | black | Bottom | Neon ceiling light lenses | 6 |

**How they are used:** a tint-able, mostly neutral line image over a flat-coloured part. The image is darkened with Color3 (grey 59-81)
rather than drawn dark, so one image serves many tones. Dark overlays sit at 0.75-0.9 transparency. Texture tiling is world-scale
(studs), so density stays constant whatever the part size. 22% of visible area carries an overlay (mostly the range grid).

### 2.2 Decals, SurfaceGuis, Beams, particles (Lobby only)
~60 real Decals (warning stickers, footprints, logos, floor arrows), 156 SurfaceGuis (all live text), 94 Beams (light shafts and
hologram cones over pads), 131 ParticleEmitters (ambient sparkles at displays, hit effects).

---

## 3. Accents: where purple and gold appear

### 3.1 Inventory
| Accent | Where | Form | Count / share |
|---|---|---|---|
| **Gold Neon 163,135,51** | floor ring segments round the hub centre, pad frames (team 2), pad badges, ceiling slashes in the market (capture 5), sign arrows | Neon, 0.38 x 0.5 strips on floor; ring meshes | 57 parts, 6% of Neon area |
| **Hazard yellow 255,188,53** (non-neon) | 3-stud wall band at 7-10 studs; door-leaf stripe; pad-edge hazard tape | Concrete-02a / Plastic paint | ~20 parts, long runs |
| **Gold/orange text 255,176,65** | KEEP CLEAR floor text, gold-tinted panel texture on pad floors | SurfaceGui text, Texture tint | 5 + 9 |
| **Purple Neon 115,73,162** | corridor lane lines (both edges of the walkway into the hub), pad frames (team 1), centre floor ring segments, DUELS sign | Neon 0.38 wide x 0.5 tall strips, ring meshes | 52 parts, 4% of Neon area |
| **Bright purple 193,70,255 / 151,76,255 / 207,84,255** | display cones, hand-lamp SpotLights (5) | Neon + light colour | a few |
| **White Neon 252,250,255** | logo, pad logos (Inner/Outer rings), sign lettering | Neon | 86 parts (10% Neon area) |
| **Lamp Neon 161,155,140** | all wall-light capsules and ceiling strips | Neon | 59 parts |
| **Black Neon 0,0,0 / 34,34,34** | voids behind doors, vents, pits | Neon (unlit, pure black) | 35 parts, **44% of Neon area** |

**Proportion:** gold/yellow ~60%, purple ~40% of the coloured accent elements. Together they cover **under 2% of visible area**:
the accents are lines, never fills. Purple = "go this way / team 1"; gold = "datum line, sign, attention, team 2".

**Neon thickness/brightness:** floor lines 0.38 wide x 0.5 tall (recessed so ~0.1 shows above floor *(est.)*); ceiling slashes ~0.5-0.7;
lamp capsules 1.2-1.5 wide. Neon colours are mid-value (115-163), not 255, so they glow without blowing out; only white sign text is
full 252. No Bloom effect is used (only a neutral ColorCorrection), so glow strength is controlled purely by Neon colour value.

### 3.2 Mapping to Tacticals (decided per use)
Rule of thumb: **olive is the only saturated colour in the Tacticals palette, so olive takes RIVALS' gold/yellow role (the
dominant accent, ~60%)**; **cream takes the purple role (lines and direction, ~40%)**, because cream lines on a near-black floor read
like airfield/helipad runway markings (sky base theme) and give the highest floor contrast.

| RIVALS use | RIVALS colour | Tacticals colour | Why |
|---|---|---|---|
| Wall hazard band (3 studs @ 7-10) | 255,188,53 paint | **olive 138,156,74** (Concrete-02a-equivalent, painted) | A saturated band on grey walls is the main colour datum; cream would read as a plain light stripe. Olive band = military livery. |
| Door-leaf stripe (3 studs) | 255,188,53 | **olive 138,156,74** | Same datum line as the wall band. |
| Gold floor rings, ceiling slashes, sign arrows | Neon 163,135,51 | **Neon dark olive 107,122,58** | Neon brightens its colour: olive 138,156,74 as Neon goes lime; 107,122,58 Neon should read as olive. **Test in Studio** and step down if it still reads lime. |
| Purple lane lines (corridor edges) | Neon 115,73,162 | **Neon cream 236,232,218** at reduced value **≈ 180,177,166** | Runway lines. Full cream Neon would blow out (RIVALS keeps lane Neon mid-value); start at ~180 and tune. |
| Team pads (team 1 / team 2) | purple / gold Neon frames | **cream frame / olive frame** | Two teams must stay distinct: light vs saturated. |
| Big signs | white Neon letters, purple/gold outline + arrows | **cream Neon letters (≈ 220), dark-olive Neon outline, cream arrow** | |
| KEEP CLEAR / floor warning text | 255,176,65 | **cream 236,232,218** at 0.2 transparency | Warning text must out-contrast the floor; olive on 36-62 floor is too low-contrast. |
| Hazard tape (black/yellow diagonals) | yellow/black | **cream/near-black (10,12,10)** | Keeps warning legibility; olive/black is too low contrast for tape. |
| Warning sign plates | 229,179,30 / 225,70,93 | **cream plate with near-black text**; keep a red plate for "danger" only (RIVALS also uses red) | |
| Pad-floor gold-tinted panel Texture | tint 255,176,65 | olive-tinted (107,122,58) | |
| Purple display-light SpotLights | 207,84,255 | **warm white 255,241,208** or dark olive | Coloured light is rare; do not add olive light by default. |
| Lamp Neon | 161,155,140 | **unchanged** (or warm grey 200,196,186 at value 160) | Neutral, not an accent. |
| Military crates | 65,94,56 | dark olive 107,122,58 or keep 65,94,56 | Already on theme. |

---

## 4. Lighting

### 4.1 RIVALS Lighting (read 2026-10-14)
| Property | Value |
|---|---|
| Technology / LightingStyle | (scripts cannot read Technology; CLAUDE.md survey: LightingStyle Realistic, PrioritizeLightingQuality on). Set Future by hand and check. |
| Brightness | 3 |
| Ambient | 121,121,121 (0.475) |
| OutdoorAmbient | 198,198,193 |
| ColorShift_Top | 255,217,184 (warm) |
| ColorShift_Bottom | 170,126,213 (purple) |
| EnvironmentDiffuseScale / SpecularScale | 1 / 1 |
| ExposureCompensation | -0.15 |
| GlobalShadows | on · ShadowSoftness 0.5 |
| ClockTime | 12 · GeographicLatitude 23.5 |
| Fog | FogEnd 2500 (effectively off; Atmosphere does the haze) |
| Atmosphere | Density 0.255 · Offset 0.2 · Color 140,196,231 · Decay 92,60,14 · Glare 0 · Haze 1.82 |
| Sky | CelestialBodiesShown **false** (no sun/moon disc), StarCount 3000, SunAngularSize 21 |
| Post | one ColorCorrection, all zero (neutral). **No Bloom, no SunRays, no DepthOfField.** The Blur/ColorCorrection pairs named "GlowyBackground… - Teleporting/MainGui/…" are UI-state effects toggled by scripts; ignore. |

### 4.2 Local lights (69 in the Lobby)
| Type | Count | Colour | Brightness | Range | Angle | Shadows | Where |
|---|---|---|---|---|---|---|---|
| SpotLight (truss spotlights, BaseCylinder) | 14 | 255,228,174 / 255,241,208 warm | 1.5-2.5 | 30-60 | 81-120 | 5 on, 9 off (8 disabled) | hub ring truss, pointing at the centre and displays |
| SpotLight (hand lamps) | 10 | 255,201,126 warm / 207,84,255 purple | 1.5-2 | 36 | 120 | off | display props |
| SpotLight (red alarm) | 4 | 255,32,84 | 3 | 30 | 120 | **on** | hallway red beacons |
| SpotLight (fixture attachments) | 4 | 255,246,233 | 3 | 24 | 90-120 | on | |
| SpotLight (fans) | 3 | 255,244,211 | 0.2 | 25-52 | 90 | on | rotating fan shadows |
| SpotLight (pad) | 1 | white | 3 | 25 | 90 | off | |
| SurfaceLight | 26 (19 on) | 255,240-254,213-251 near-white | 0.2-1.2 | 20-60 | 60-180 | 1 on | inside ceiling light panels and wall light boxes: room fill |
| PointLight | 6 | warm white / one red antenna | 0.2-1 | 20-67 | | 1 on | TVs, boards, shield prop |

So: **few real lights, all warm-white (CCT ~4500-5500 K), mostly shadowless, brightness 0.2-3, ranges 20-60.** Shadow-casting lights
are reserved for a handful of feature moments (truss spots on the hub centre, red alarm beacons, fan gobo). Neon does the
"lots of light fixtures" job visually (lamp capsules, ceiling strips); SurfaceLights hidden in those fixtures add the actual fill.

### 4.3 What makes the look
1. **Bright global light on a dark set:** Brightness 3 + 0.47 ambient + warm ColorShift_Top lights mid-grey walls evenly; the
   near-black floor keeps it from looking washed out. Shadows soft (0.5), never inky, because ambient is high.
2. **Warm top, tinted bottom:** surfaces facing up get warm, surfaces facing down get the ColorShift_Bottom tint (the faint purple
   in RIVALS' ceilings/undersides ties the purple accent into the whole room).
3. **Saturation lives only in the Neon lines and props**; the architecture is neutral grey.
4. **No bloom:** clean, crisp edges; Neon glow is the engine's own.
5. **Atmosphere haze with a blue sky colour** gives depth through openings and makes the outdoor sky read bright.

### 4.4 Recommended Lighting for Tacticals
Copy RIVALS exactly except the bottom tint:

```
Lighting.Technology            = Future   (set by hand; check it)
Lighting.Brightness            = 3
Lighting.Ambient               = 121,121,121
Lighting.OutdoorAmbient        = 198,198,193
Lighting.ColorShift_Top        = 255,217,184
Lighting.ColorShift_Bottom     = 167,173,152   -- sage (palette), replaces purple 170,126,213
Lighting.EnvironmentDiffuseScale = 1 ; EnvironmentSpecularScale = 1
Lighting.ExposureCompensation  = -0.15
Lighting.GlobalShadows         = true ; ShadowSoftness = 0.5
Lighting.ClockTime             = 12 ; GeographicLatitude = 23.5
Lighting.FogEnd                = 2500
Atmosphere: Density 0.255, Offset 0.2, Color 140,196,231, Decay 92,60,14, Glare 0, Haze 1.82
Sky: own skybox, CelestialBodiesShown false
ColorCorrection: all 0 (or omit); no Bloom, no SunRays, no DoF
```
*Why sage:* the bottom shift tints every downward face; RIVALS ties it to its secondary accent. Sage (167,173,152) is the softened,
desaturated sibling of olive, so ceilings and undersides pick up a faint green-grey that unifies the olive accents without turning
the room green. If ceilings look muddy, fall back to warm grey 200,196,186 (neutral) — do not use full olive 138,156,74 (too green).
For the **floating sky base**, keep RIVALS' blue Atmosphere colour: the sky outside should stay bright and blue as contrast to the
dark hangar floors.

Local lights for Tacticals: follow RIVALS' budget (about 1 real light per 1,500-2,000 stud² of floor, ~60-90 total for a lobby of
Tacticals' size; Tacticals already has 83). Warm white 255,228-246,174-233; shadows only on 10-15 feature lights; SurfaceLights inside
every Neon fixture for fill (0.5-1.0, range 40-60).

---

## 5. Readability rules RIVALS follows
1. **Floor darkest, walls mid, ceilings mid-dark.** Floors 36-62, walls 88-124, ceilings 69-112. Walkable = dark, boundary = lighter.
   The only large light surfaces are ribbed shells (141) high up and the training range (151-163).
2. **Directional lines on the floor:** thin Neon lane lines on both edges of each walkway lead into the hub; white chevrons point
   into queue areas; stencilled floor labels name the destination (CARGO ELEVATOR, WEST GATE).
3. **Interactable = framed in Neon.** Queue pads have a 0.38 Neon frame in the team colour, a light logo decal in the middle, a
   Beam cone above and a SurfaceGui board (10 x 14) naming the mode. Displays have Neon halo rings on the floor + a spotlight.
4. **Entrances are signed from afar:** a big Neon sign (white letters, coloured outline/arrow) hangs over each area arch; small
   white label plates name individual doors/bays.
5. **One datum line:** the 3-stud hazard band at 7-10 studs runs round the halls and across doors, so the eye reads room shape and
   door positions at once.
6. **Text style:** one sans font family, Medium/Bold/Heavy weights, no stroke, white on dark boards or black on white plates; all
   caps for labels.
7. **No colour fills.** Accents never cover a wall or floor; they are 0.4-3 studs wide.
8. **Voids are pure black Neon**, so openings and pits read as depth, not as unfinished geometry.

---

## 6. Palette table: RIVALS role -> Tacticals

| Role | RIVALS RGB | Tacticals RGB | Note |
|---|---|---|---|
| Main floor slab | 62,62,62 | **62,62,60** | keep near-neutral; tiny warm shift |
| Floor borders / darkest rings | 36,35,36 | **36,36,34** | |
| Floor metal ring / pad base | 108,107,106 | **108,107,104** | |
| Corrugated floor insert | 80,79,78 | **80,79,76** | |
| Wall body (light) | 120,120,122 · 112,111,113 | **120,119,115 · 112,111,107** | warmed 4-7 toward warm grey so cream/olive sit naturally |
| Wall body (mid) | 107,107,108 · 94,94,95 | **107,106,102 · 94,93,89** | |
| Wall kick / lower split | 88,87,89 · 79,79,80 | **88,87,83 · 79,78,74** | |
| Panel plates | 102,102,103 | **102,101,97** | |
| Ribbed upper shells | 141,140,143 | **141,140,134** | |
| Ceiling | 112,111,113 / Pearlescent 69,64,74 | **112,111,107 / 66,68,62** | pearlescent shifts from violet-grey to olive-grey |
| Door leaves | 72,72,72 · 89,89,90 | **72,72,70 · 89,89,86** | |
| Trims, kerbs, skirting (metal) | 108,107,106 · 124,123,126 | **108,107,104 · 124,123,119** | |
| Pillars / beams | 67,67,67 · 76,76,76 | **67,67,65 · 76,76,73** | |
| Hazard band / door stripe | 255,188,53 | **138,156,74 olive** | |
| Gold Neon (rings, slashes, arrows) | 163,135,51 | **107,122,58 dark olive (Neon)** | test for lime cast |
| Purple Neon (lanes, team 1) | 115,73,162 | **≈180,177,166 cream (Neon, tuned down from 236,232,218)** | |
| Bright purple display neon | 193,70,255 | **236,232,218 cream** | |
| White Neon (logos, letters) | 252,250,255 | **236,232,218 cream** | |
| Lamp Neon | 161,155,140 | **161,157,145** | |
| Void Neon | 0,0,0 / 34,34,34 | **10,12,10 near-black** / 34,34,34 | |
| Floor warning text | 255,176,65 | **236,232,218 cream** | |
| Hazard tape | yellow/black | **cream / 10,12,10** | |
| Label board | 39,39,39 | **39,40,37** | |
| Label text | 255 / 58 / 0 | **236,232,218 / 58,58,55 / 10,12,10** | |
| Range / training plastic | 151,153,163 (cool) | **200,196,186 warm grey** or **167,173,152 sage** for the training floor | grid texture over it |
| Military crate | 65,94,56 | **107,122,58** or keep | |
| Warning plate (danger) | 225,70,93 | keep a red ~200,60,60 for danger only | the one non-palette colour, as in RIVALS |
| ColorShift_Bottom | 170,126,213 | **167,173,152 sage** | |
| Atmosphere colour | 140,196,231 | **140,196,231** (keep) | |

---

## 7. Texture shopping list (own images only)
Already made and reusable from `rivals_practice/tex/pbr/` (own work; `make_tiles.py`, `make_tiles2.py`): concrete_plain, concrete_smooth,
concrete_floor (sealed, trowel streaks), concrete_panels, concrete_corrugated, corrugated_fine, metal_true (+ metalness), metal_rib,
grime_overlay, grate_mesh; `hallway_tex/hazard_diag_*`. Lessons from the replica material pass: colour maps near-white so Part.Color sets
the tone; no pit specks; grime overlays small (4 studs) and faint (0.95); metal needs a metalness map; read back every variant's maps
in Studio after binding.

| # | Texture | Size | Tiling | Use | Recipe |
|---|---|---|---|---|---|
| 1 | **Plain concrete override** (colour/normal/rough) | 1024² | MaterialVariant 10-14 studs | MaterialService override for Concrete; all wall masses | Reuse `concrete_plain_*`. If regenerating: numpy fBm (4 octaves, low amplitude ±6 levels around 235), normal from height at strength 0.5, roughness 0.75-0.85; no specks. |
| 2 | **Plain satin metal override** (+ metalness) | 1024² | 10 studs | MaterialService override for Metal; trims, kerbs, pillars, doors | Reuse `metal_true_*` + `metal_full_metalness.png` (~0.92). Very faint brushed streaks (1-px horizontal noise blurred along x). |
| 3 | **Concrete with panel seams** | 1024² | 20 studs (one tile = 4 panels of 10 x 10 *(est.)*) | ConcretePanels role: wall plates, cladding | PIL: near-white base + fBm; 4-px dark seam grooves on a 2x2 layout with one offset horizontal seam; normal map from seam height (groove depth ~1 mm look), 4 bolt dots per panel corner. Reuse `concrete_panels_*` as start. |
| 4 | **Fine corrugation (normal-only)** | 512² | 10 studs, ~16 ribs per tile | Corrugated_02a role: ribbed upper shells, bands | numpy sine profile along one axis -> normal map; colour map omitted (Part.Color shows through); rough 0.7. Reuse `corrugated_fine_*`. |
| 5 | **Corrugated metal sheet** | 512² | 16 studs, ~8 deep ribs | Corrugated_01a role: floor inserts, hangar cladding | Trapezoid profile (flat top 40%, slope 10%) -> normal + metalness 0.9; faint vertical drip streaks in roughness. |
| 6 | **Sealed hangar floor concrete** | 1024² | 20 studs | main floor slabs (dark 36-62) | Reuse `concrete_floor_*`: low roughness (0.45-0.6) with trowel arcs in roughness, so the warm sun gives a soft sheen; colour near-white. |
| 7 | **Panel-line floor overlay** (Texture object) | 1024², alpha | Texture StudsPerTile 20 x 20, Top face, opaque lines tinted ~81 grey | pad floors, bay floors, centre platform | PIL on transparent: 3-4 px light lines forming a large panel layout (2 big + 4 small rectangles, a few rivet dots), lines white so Color3 sets their tone. |
| 8 | **Square grid overlay** | 512², alpha | 5 x 5, all faces, 0.75 transparency, black | Training area (sky "simulation" boxes) | PIL: 2-px lines on the tile border + small cross ticks at corners; white lines (tinted by Color3). |
| 9 | **Metal floor grating** | 512², alpha | 3 x 3 studs | grates over dark pits / drains, over black parts | PIL: diamond or bar grating (bars 6 px, gaps 18 px) in white with transparent holes; reuse `grate_mesh.png` idea. Host part near-black, Texture tint 70-80. |
| 10 | **Panel-line trim strip** | 1024 x 128, alpha | 8 x 1 studs | door reveals, wall plates at band height, display walls (the 2x4 pattern role) | PIL: horizontal recessed line top and bottom + short vertical breaks every 2 studs + small stencil ticks. |
| 11 | **Grime overlay** | 512², alpha | 4 studs, 0.92-0.95 transparency, black | plastic/metal props, lower wall kick zones only | Reuse `grime_overlay.png`: blurred fBm masked by a vertical gradient (dirt at the bottom), max alpha 60%. Never on hazard bands or floors. |
| 12 | **Hazard tape (cream / near-black)** | 512 x 128 | 4 x 1 studs | pad edges, lift edges, KEEP CLEAR zones | PIL: 45° diagonal stripes, stripe width 32 px, cream 236,232,218 and near-black 10,12,10, slight edge wear from noise. Start from `hallway_tex/hazard_diag_*`. |
| 13 | **Ceiling light louvre** | 256², alpha | ~0.6 x 1 studs, 0.5 transparency | Bottom of Neon ceiling strips | PIL: evenly spaced 3-px dark bars across the lens. |
| 14 | **Floor stencil labels and chevrons** | 1024 x 256 per label, alpha | decal / SurfaceGui | floor destination labels (e.g. TRAINING, ARMORY, DUELS), chevrons | Own text in a built-in Roblox font via SurfaceGui (live, crisp) rather than images; chevrons as PIL white arrows with stencil gaps. |
| 15 | **Pad logo** (team pad centre) | 512², alpha | decal | queue pads | Codex image gen or PIL: Tacticals' own emblem in flat cream, stencil style. Own art only. |

Uploads: images through Creator Hub under the **Gunsy Funsy** group (CLAUDE.md), then MaterialVariants created in Tacticals_rebuild's
MaterialService. Never use any RIVALS asset id.

---

## 8. Quick build checklist (per room)
1. Floor: dark sealed concrete (36-62) with darker border bands; panel-line overlay on special zones.
2. Walls: concrete mass 94-120 with a darker lower split (79-88) and the **olive 3-stud band at 7-10 studs**; panel plates for variety.
3. Trims, kerbs, reveals: plain metal 108.
4. Ceiling 24-37 studs up, coffers + recessed Neon strips with louvre texture; ribbed shells lighter (141).
5. Doors: metal leaves, olive stripe at band height, black Neon voids behind, white label plate above, big Neon sign for main areas.
6. Floor lines: cream Neon 0.38 x 0.5 lane lines into the hub; dark-olive Neon rings round focal points.
7. Lights: Neon capsule wall lights every ~12-16 studs *(est.)* centred ~14 studs up (above the band), SurfaceLight fill, a few shadowed warm spots on the hero.
8. Check: floor clearly darker than walls; accents only as lines; no colour fills; nothing lime or purple left.
