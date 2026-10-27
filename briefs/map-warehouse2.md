# Brief: Warehouse 2 (Tacticals match map, 2026-10-27)

Work order: the Lead's plan, approved by Edward. Edward: "I love the look of it but it looks way too sci-fi, but the positioning
of all the parts and cover are good. I want this warehouse to have a garage opening on both ends. It should look like a GTA warehouse."

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
