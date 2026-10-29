# Brief: House, the world outside the windows (illusion pass)

Work order: Lead's plan approved by Edward (2026-10-29). Edward: "the house map looks like a floating object from the windows inside
the house ... make it feel like a complete map outside the windows when it actually isn't; then grade how well the illusion works."
Style: Test Site House (vault) + notes/house_1965_style.md. Method: vault `03 Map Building/Backdrops and World Illusion.md`.

- **Fantasy:** you are inside one house of a 1965 desert test town; out of every window the town, the test range and the mountains
  go on to the horizon under a hazy warm sky.
- **Landmark outside:** the steel instrument mast south (Mast_South, framed by the foyer window); a water tower as the second
  far-field silhouette north.
- **Scope:** ONLY non-colliding exterior art (HouseExterior + a new far-field model), Lighting / Sky / Atmosphere, and the house's
  outside dressing (foundation, porch, steps, driveway, yard). Never collision proxies, barriers, doors, windows, spawns
  (a systems task owns fix/house_wallcover.lua and cover/movement code).
- **Construction:** meshes from the modeler (Blender, kit list `briefs/kit-house-illusion.json`), placed by an installer
  (`fix/house_illusion.lua`); the sky is our own six images.
- **Layers** (distances from the house centre, world (-650, 1.2, -450)):
  - near 0-150: our porch / back stoop / driveway; the existing street, houses across, neighbours, fences, cars, dummies,
    poles, dry trees (modeler's 1965 set, unchanged);
  - mid 150-600: more test-town houses, test-site structures (water tower, bunkers, quonset hangar, observation stand,
    chain-link, pole lines running out), fading into haze;
  - far 600+: desert ground to the horizon (ground skirt ring out to ~4,000), a three-tier mesa / mountain ring, and a sky whose
    lower band matches the haze and ground.
- **Viewing conditions:** match place Technology ShadowMap (place-wide, not ours), the map's own Lighting from MapInfo (clock 15.5,
  latitude 35, bright 2.8, ambient 86/80/72, outdoor 170/160/140, Atmosphere 0.35 / 0.1 / haze 2.5 / glare 0.1 / (214,196,166) /
  (150,120,90), grade sat -0.14 tint (255,246,228), bloom 0.25), plus the new per-map Sky. FOV 70. Captures at EditQualityLevel 21
  (shipping PC) and 01 (lowest). Match places don't stream.
- **Palette outside:** desert ground (196,172,128)-(214,190,146), dry lawn olive (150,140,90), mesa rock tan-rust (176,132,96) near ->
  (196,170,140) far -> haze (214,196,166); sky horizon cream-tan (220,204,176), zenith pale dusty blue (150,170,190), never saturated
  blue. No red / blue team hues on big surfaces.
- **Constraints:** far field <= 6k tris, mid field <= 25k, <= 8 new textures; everything Anchored, CanCollide / CanQuery / CanTouch
  off, CastShadow off past the near field, no lights, particles or scripts. The far + mid field are only in Workspace while House is
  the loaded map (they would sit round the other maps of the same place).
- **Done when:** every window, standing and crouched, sweep / up / down, both floors, quality 1 and 21, and the 3v3 spawn rooms:
  no void, edge, seam, floating piece or repeated card; depth reads near / mid / far; the sky matches the ground.
