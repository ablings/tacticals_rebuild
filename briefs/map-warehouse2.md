# Brief: Warehouse 2 (Tacticals match map, 2026-10-27)

Work order: the Lead's plan, approved by Edward. Edward: "I love the look of it but it looks way too sci-fi, but the positioning
of all the parts and cover are good. I want this warehouse to have a garage opening on both ends. It should look like a GTA warehouse."

## Round 6 (2026-10-27): Edward's changes (this section overrides the round 1-5 text below where they differ)
Edward, after seeing Warehouse 2: "Too many green accents this isn't the lobby this is a separate map you understand? I like some
green crates here and there but there is way too much green i also love the idea of the steel beam lights that the other
warehouse had and the enclosedness of it the door should be openable via scripts for animating/cutscene purposes but in game it
should remain closed but i like the idea of the exterior you made so when the door opens via cutscene its not something crazy
but it should be night time outside and the lights should really give the effect that the stakes are raised".

- **Fantasy now:** a 1v1 shoot-out at midnight, locked inside a freight warehouse. Enclosed, dark, tense: hard pools of warm
  light from bars on steel beams, real dark between them, black skylights with the moon and stars.
- **Night:** MapInfo.Lighting ClockTime 0, low Ambient / OutdoorAmbient, thin dark atmosphere, contrast up, saturation down,
  bloom on the light bars. The place's own sky renders black with a moon and stars at midnight: no new sky image.
- **Lights:** the 19 bell lamps are gone. Like the old Warehouse: 4 dark steel I-beams span the hall at n +-15 / +-45, hung
  from the purlins on rods, each with two long light bars (e +-20, ~12.5 up, warm white 255,238,214). Each bar: a PointLight
  (range 40, Shadows on: under ShadowMap the beams and bars throw the coarse light fans on the roof and floor) + a shadowed
  SpotLight pool down. Two wall bars per end (above the blockwork, corners) light the spawn side of the cover at each spawn.
  Measure: darkest 5 % of a frame near 0, middle 22-49 (the old map's frames); cover faces at both spawns readable.
- **Doors shut in play:** each 20 x 14 opening holds a closed roll-up curtain: `Warehouse2.Interactive.Door_S / Door_N`
  (tag `Warehouse2Door`, attributes Open / Moving / OpenHeight / RollTime / Bay / End), a `Shutter` part that collides, stops
  shots, carries NotCover and has no prompt. A script rolls it up by shrinking the Shutter from the bottom into the drum (top
  edge fixed behind the head: nothing pokes through the hood or the roof). Contract and reference code: `briefs/systems.md`
  "Warehouse 2 doors". The round start keeps them shut (DoorManager.CloseAll, once it knows Warehouse 2).
- **The outside stays** (what a cutscene shows): both yards, trailers, containers, fence, sheds, now lit for night (door
  floods and wall-packs, a lamp-post flood in each yard, a street lamp, one lit window). They are their own model,
  `Workspace.Warehouse2Exterior` (Indoor = false), so `Workspace.Warehouse2` is an indoor map (attribute Indoor = true) and
  MapAudit's SKY check runs on it.
- **Green:** olive (107,122,58) only on two crates (C03 / C04, point-symmetric twins in the side lanes, cream AMMUNITION
  stencil). Everything else olive or green is now grey, charcoal, black / cream, galvanised steel, wood or rust: the wall band
  (charcoal), LOADING BAY signs (south black plate / cream letters, north cream plate / black letters), 01 / 02 stencils
  (charcoal), chairs (grey), drums (black + rust), bollards (black with a cream band), trailers (north cream with a charcoal
  stripe, south charcoal with a cream stripe "RIDGEWAY HAULAGE"), the old green container (weathered white), fence screens
  (charcoal).
- **The two ends still differ with the doors shut:** BAY 01 black sign vs BAY 02 cream sign, 01 / 02 stencils, and different
  dressing by each door (south: pallet pile with cartons + pallet truck; north: pallets + tyre stack) - checked on the render.
- **Materials:** no MaterialVariants (the five WH2_* tiling variants are removed; Map Building Corrections 2026-10-12, Design
  Rules: texturing is done in Blender). Roblox default materials (Concrete, Metal, DiamondPlate, CorrodedMetal, Wood). If the
  corrugated walls / roof read flat, the fix is Blender-baked panels from the modeler, not variants.
- **Viewing conditions (round 6):** Technology ShadowMap (the match place's own; local lights cast coarse voxel shadows),
  LightingStyle Realistic, values in MapInfo.Lighting (build log), Atmosphere / MapGrade / Bloom enabled, the place's Sky,
  FOV 70, StreamingEnabled off. Captures at Studio quality 21.
- **Light budget:** 8 bars x (point + spot) + 4 wall bars + 2 door lights + 2 door floods + 4 wall-packs + 2 yard floods + 2
  street lamps = 32 lights; main hall lights shadowed.

## Rounds 1-5 (kept for the record)
## Fantasy, landmark, loop
- **Fantasy:** a 1v1 shoot-out inside a real, slightly grubby freight warehouse on the edge of town, afternoon sun through the roof.
- **Landmark:** the two big roll-up garage doors, wide open, each framing a bright loading yard with a parked trailer. They are the
  brightest things at each end and tell you where you are: south (team A's end) = BAY 01, olive "OLIVE LINE HAULAGE" trailer, grey
  and sand containers; north (team B's end) = BAY 02, cream "TACTICAL FREIGHT CO." trailer, rust and green containers; big
  stencilled 01 / 02 either side of each door.
- **Loop:** spawn at your end (A south-west, B north-east) → push through the lanes of crates, pallet stacks, concrete block walls
  and jersey barriers → fight in the middle → retreat to your end / your yard. Map vote picks it as "Warehouse 2", 1v1.

## Areas
| Area | Job | Feeling | Accent | Ceiling mood |
|---|---|---|---|---|
| Hall (81 x 114, plan identical to the Warehouse) | the fight | grounded, gritty, readable | olive on signs / bollards / trailer stripe, nothing else | steel portal-frame roof, eaves 18, ridge 24, skylight strips: tall and airy, sun patches on the floor |
| South yard (team A's back yard) | breathe, the exit that isn't one | relief, open sky | same | open sky, closed by a parked trailer, stacked containers and a screened fence |
| North yard (team B's) | same, point-symmetric | same | same | same |

## Layout constraints (the gameplay layer is not redesigned)
- Every cover piece (6 pillars 5x10x5, 10 crates 5x7x4, 4 walls 10x7x3, 12 low walls 6x3.4x2), both spawns and the 4 fire barrels /
  2 steam valves keep their plan position, size and cover role; collision = the same invisible `COLP_*` boxes in `CollisionProxies`.
- Garage openings 20 wide x 14 high, centred on each end wall (no cover piece within 2 studs). Yards 20 deep, closed to 12-17 high,
  NotCover (no climbing), with invisible OutOfBounds caps above; no way out, no long sight line out (only sky over the fence).
- Metrics (notes/warehouse_study/analyze.py) on the hall must match the old metrics.json within 5 %; the yards are reported separately.
- Model `Workspace.Warehouse2` (name read by the systems agent's ShootableManager / BotConfig), attribute `SteamFill = true`;
  registry folder `ReplicatedStorage.DuelMaps.Warehouse2`, DisplayName "Warehouse 2", Modes 1v1. Old Warehouse untouched.

## Style (Industrial Parts Warehouse card, made grounded)
Parts-first, own textures only (the hub's uploaded concrete / corrugated / grime / hazard tiles, group Gunsy Funsy).
- **Palette:** concrete floor (138,134,126) with joint lines; concrete block plinth (150,147,140); galvanised corrugated cladding
  (166,168,166); steel frame painted mid-grey (96,98,96); roll-up doors galvanised slats; plywood crates (168,136,96); precast concrete
  blocks and jersey barriers (176,171,161); floor paint cream-white (226,222,210); oil stains near-black.
  One accent: olive (107,122,58) / cream (236,232,218). **No neon strips, no glowing panels, no screens, no navy/blue trims, no
  yellow/orange** (Tacticals rule: hazard paint is black/cream).
- **Lighting (MapInfo.Lighting, applied when the map wins the vote):** afternoon sun (ClockTime 14.3, latitude 35, Brightness 2.2),
  warm-white high-bay lamps: a SpotLight pool under each (255,232,204; angle 80, range 24, brightness 1.6) plus a weak PointLight
  fill (0.2 / 20) for the cover sides; floor under a lamp ~1.8x the floor between lamps (measured). Lamp lenses a dim warm Neon
  (118,110,94) so the open doors, not the lamps, are the brightest things. Cool daylight through skylights and doors, light haze.
  (Round 2, 2026-10-27: grader round 1 found the hall evenly lit and the lenses outshining the doors.)

## Viewing conditions (fixed before judging)
- Technology **ShadowMap (3) as the match place ships** (Future would make the captures lie: local lights cast no shadows in the real
  game). LightingStyle Realistic. Only the sun casts shadows; lamps are unshadowed pools.
- Ambient (98,96,92), OutdoorAmbient (128,126,120), ExposureCompensation -0.15, EnvironmentDiffuse 0.35, EnvironmentSpecular 0.25.
- Post (the place's own objects, values per map): Atmosphere Density 0.18 Offset 0.1 Colour (206,210,212) Decay (110,114,124)
  Glare 0.1 Haze 1.8 (enabled); MapGrade ColorCorrection Contrast 0.12 Saturation -0.08 Tint (255,252,246) (enabled); Bloom
  Intensity 0.35 Size 22 Threshold 2.2 (enabled). No SunRays, no DOF.
- Sky: the place's single Sky (custom skybox 6444884337..., shared with every map). It renders a saturated royal blue at the
  zenith (yards, skylights); the map can't swap it: OPEN, needs a per-map Sky in RoundManager.applyMapEnv + an own pale sky.
- FOV 70 (the game's default; Settings has no FOV). StreamingEnabled off.
- Materials: the place's material set; MaterialVariants WH2_* created in MaterialService from our own uploads.

## Triangle / light budget
Match map: ≲ 150k tris per camera, ≲ 50 real lights (21 lamps x spot + fill, 4 yard floods = 46, none shadowed), 0 neon strips.
