# Brief: House (Tacticals duel map, 1v1 / 2v2 / 3v3)

**Fantasy:** a gunfight through a big, lived-in modern suburban home on a sunny late afternoon: sofas, a kitchen island and
beds as cover, sun through every window, the street and the neighbours' houses outside. Layout and feel inspired by a
classic suburban test-site shooter map; every model, texture and word is our own.
**Landmark:** the double-height foyer with its tall feature window over the front door, the open-tread main stair and the
gallery railing above it (the place players screenshot, and the hinge of the fight).
**Loop:** spawn (A living room / B kitchen) -> one of three ground lanes (foyer front, cross hall middle, back hall / mudroom back)
or up your own stair (A: main stair from the foyer; B: back stair from the back hall) -> the landing and bedrooms above.
**Style:** Clean Modern Interior (vault Map Styles), suburban: warm white walls, pale oak floors, charcoal window frames, one
feature wall per room, soft furnishings in mid greys; the Tacticals olive / cream only as small accents (cushions, a print),
never on walls or floors (Warehouse 2 lesson: "this isn't the lobby"). Team colours (red / blue) stay team-only.
**Construction:** the modeler's Blender meshes for everything visible (shell, stairs, railings, doors, window frames + glass,
furniture, dressing, exterior). Studio Parts only for invisible helpers (collision proxies, barriers, spawns, light holders).
(Corrections 2026-10-26 / 2026-10-27: no visible Studio Parts unless the brief says "build it in Studio"; it doesn't.)
Plan, rooms, cover and fairness: notes/house_plan.md. Layout data: notes/maps/house_layout.json.

| Area | Job | Feeling | Accent | Ceiling |
|---|---|---|---|---|
| Foyer + gallery | arrive, the exposed hinge | bright, tall | sun shaft through the feature window | double height 26 |
| Living room (A) | spawn, sofa ambush on the stair foot | warm, soft | a deep-green velvet sofa cushion set | 13 |
| Kitchen (B) | spawn, island, pass-through | clean, skylit | the skylight glow, brass tap | 13, flat roof skylights |
| Dining room | open to the foyer | formal, bright | two pendants over the table | 13 |
| Back hall / mudroom / bathroom | back lanes | cluttered, cool | coat hooks, tiles | 13 |
| Landing + upper hall | top of both stairs | exposed, then narrow | bookcase by the landing | 12 |
| Bedrooms + bathroom | flanks, high ground | calm (master), busy (teen room) | bedding colours | 12 |

**Constraints:** no way out (window barriers + locked doors + HouseBounds backstop); doors held as specified (interior ajar 70,
ensuite closed, front + back locked); cover 3.4 / 8; spawns fair within 10 % (checker); MapInfo own Lighting; touches no other
map; no MaterialVariants (default materials + the modeler's baked textures).

## Viewing conditions (fixed before judging anything)
- Technology: the match places' own **ShadowMap (3)** (read offline from out/house/build.rbxl; every match place). Not changed:
  the map shares the place with Arena / Warehouse / Warehouse 2. Under ShadowMap only the sun casts shadows, so the sun through
  the windows is the main light; room lights are unshadowed fill.
- Lighting (MapInfo.Lighting, applied when House wins the vote): ClockTime 16.2, latitude 35, Brightness 2.6, exposure 0,
  Ambient (112,110,106), OutdoorAmbient (128,126,122), EnvDiffuse 0.45, EnvSpecular 0.25; Atmosphere density 0.24, offset 0.1,
  haze 1.2, glare 0.1, colour (205,214,224), decay (150,160,176); grade contrast 0.08, saturation -0.04, tint (255,250,244);
  bloom 0.3 / 22 / threshold 2.0 (starting values; tuned on the render).
- Post effects: the place's own Bloom / ColorCorrection / Atmosphere objects carry the MapInfo values (RoundManager.applyMapEnv);
  no DOF, no SunRays.
- Sky: the place's shared Sky (afternoon: it shows through every window; the exterior set's houses and trees fill most views).
- FOV: the game's default camera (70).
- Studio quality for captures: **EditQualityLevel 21** set by script before every capture (Corrections 2026-10-27).
- Lights: 34 (style card budget ~40, grade round 1): per room unshadowed ceiling downlights, one per ~400 sq studs (SpotLight 2.4,
  120 deg, range ceiling + 12), plus warm PointLights in the floor lamps and pendants (table lamps are art only). Tuned at quality 21:
  ground rooms median 86-166, bedrooms ~92-124 (calmer than the 138-light round: captures/house/lights_before_after.png).
