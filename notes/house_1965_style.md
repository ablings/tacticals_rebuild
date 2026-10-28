# House: 1965 test-site restyle, per-room brief (for the modeler)

Map trainer, 2026-10-28. Style card: vault `03 Map Building/Map Styles/Test Site House.md` (read it first: era cues, palette,
wear, lighting, originality). References (study only, never in the game): `notes/ref/nuketown/contact_sheet.jpg`, list in
`notes/ref/nuketown/sources.txt`; numbers like [21] below are frames on that sheet.

## What does NOT change (hard)
- **Layout:** `notes/maps/house_layout.json` v1 as built. Every room, wall, opening, door, stair, window and spawn stays.
- **Every footprint in `notes/house_props.md`:** each piece keeps its layout id, its asset name (H_*), its W x H x D, its pivot
  (bottom centre of the collision union), its front (-Y) and its collision boxes, including the height bands
  (back 3.4 / arms ~2.5 / seat ~1.8 / mattress 2.4 / table 2.6). Low cover = **3.4 exactly**, tall = **8.0 exactly**.
  The restyle changes what the mesh looks like inside its box, never the box. Art that rises above its box is allowed only
  where house_props.md already allows it (taps, plant tops) or is noted below; re-run `art/house/tools/texel_pivot_check.py`
  and the coverage check after the rebuild.
- **Cover pieces get closed bases.** 1960s furniture stands on thin tapered legs, but our cover boxes are solid to the floor:
  every LOW or TALL cover piece gets a skirt, plinth or kick board down to the floor so no see-through gap sits inside a
  solid box. Legs may show only as short stubs below a skirt (≤ 0.3). Dressing (no collision) may have open legs.
- **Doors and windows keep their conventions** (hinge origin, `<WindowId>_Frame/_Glass/_BrokenGlass`, Shootable glass).
- **Team colours:** no red or blue room surfaces or large furniture (red / blue stay team-only). The reference's red
  enamel kitchen, navy drapes and wine stair runner are replaced below.
- **Own art only:** paint/generate every texture; no reference texture, poster, sign, logo, lettering or mannequin design.
  All words (stencils, labels, packaging) are our own; stencil font = our own.
- Texture density stays ≥ 22 px/stud with 1024 atlases (current floor in house_props.md).

## House-wide shell kit (replaces the modern white/oak shell)
| Element | 1965 look | Colours (base) | Ref |
|---|---|---|---|
| Wall, patterned | wallpaper above a chair rail; three own patterns: **Sprig** (small sage olive-leaf sprigs on cream), **Vine** (trailing dark-green vine on pale sage), **Diamond** (stepped diamond geometric for kitchens); tile ~4 x 4 studs | see per room | [04][10][11][21][27] |
| Wainscot | walnut boards 0 to 3.0 high + chair rail 3.0-3.3 (0.15 proud) | walnut (82,54,30), rail (58,40,24) | [04][11][22] |
| Crown + baseboard | dark walnut, crown 0.5 tall, baseboard 0.5 tall (0.1 proud) | (58,40,24) | [04][30] |
| Panelling | vertical knotty pine boards, 0.6 wide, full height | pine (168,114,58), knots (86,54,24) | [32] |
| Fieldstone | stacked rough stones 1-2 studs, deep mortar (normal map) | (118,108,92) / (86,78,66) / (142,132,112), mortar (70,64,54) | [02][03][22] |
| Ceiling | flat, yellowed white, faint water stain decal in one corner per floor | (222,214,190) | |
| Interior doors | flush birch slab, brass round knob, dark casing | birch (196,168,120), casing (58,40,24) | [09] |
| Front door | flush walnut with three small stepped lites, brass knob | (100,66,36) | |
| Back door (glazed) | wood-framed glazed door, white paint, 6 lites | (226,220,200) | |
| Windows | **white-painted wooden sash frames** with 2-over-2 muntins (replace the black aluminium); white sill inside; outside casing in the house's siding trim colour. **Masking-tape cross** (own decal, 0.2 wide tape strips, beige (214,196,150)) on ~1 window in 3, on the glass mesh so it breaks with it | frame (230,226,210) | [13][29] |
| Drapes | heavy solid drapes **pulled to the sides**, never across the opening (MapAudit WINDOW), rod above | mustard (198,160,58), bottle green (52,78,58) or gold (196,150,58) | [12][23] |
| Stairs | main stair: walnut treads and stringers, **moss-green runner** with brass rods (replaces the reference's wine runner); back stair: painted treads, rubber nosings | runner (82,98,58), rods (180,150,80) | [04][15] |
| Railings | turned walnut balusters + round handrail, same spacing/heights as now (bullets pass between balusters) | (82,54,30) | [37] |
| Wear (all rooms) | grime band 0-2 up every wall (tan (170,150,115) at ~20 %), dust on tops, scuffs along walking paths and at doorways, faded rectangles where frames hung, sand drifts at the outer doors and under 3-4 windows (art, ≤ 0.15 high, no collision) | | [39] |

## Rooms (ground floor)
### Foyer (FY, double height, the landmark)
- Walls: **Sprig** paper over walnut wainscot up both storeys of the void; crown at 26. The tall feature window over the front door
  gets two taped crosses and gold drapes pulled aside (it frames the instrument tower outside).
- Floor: oak strip parquet in a herringbone (dark, worn pale down the middle), FY_Runner as a **braided oval runner** in olive/cream/rust.
- FY_Pend (H_PendantLamp 1.8 x 4.05 x 1.8): **sputnik-style brass chandelier** with 6 short arms and bulb tips, same size, one PointLight.
- FY_Planter (H_Planter 3 x 3.4 x 3, low): **brick planter box** with a cap course; rubber plant (dark glossy leaves) as the art above.
- FY_Console (H_Dresser 2.3 x 6 x 3.4, low): **walnut telephone table** with a skirted base, rotary phone (own shape), a notepad.
- FY_Bench (H_HallBench_3, low, banded): **telephone bench / gossip bench**, walnut frame, olive vinyl seat, closed front.
### Cross hall (CH)
- Walls: Vine paper over wainscot. Floor: herringbone parquet continues.
- CH_Column (H_DisplayColumn 3 x 8 x 3, tall): **fieldstone-clad column** with a walnut-lined niche on each face (a vase, a clock).
- CH_Art (H_Frame_Botanical): **gold-framed small oil** of a desert flower (own painting).
### Back hall (BH) and Mudroom (MR)
- Walls: Vine paper; mudroom: painted lower walls in coffee brown (98,74,46) with pegboard above. Floor: **checker lino** cream/rust-tan.
  Sand fan inside the back door.
- BH_CoatTree (H_TallCabinet 3 x 8 x 2.12, tall): **walnut hall tree / coat cupboard** with a mirror panel, a coat and a hat on hooks (art on its face).
- BH_Washer (H_WashingMachine 2.6 x 3.0 x 2.52): **top-loading washer**, enamel white, chrome lid hinge, dial panel at the back.
- MR_Lockers (H_Wardrobe 6 x 8 x 2.5, tall): **painted wooden coat lockers** (cabinet green (92,110,80)), slatted vents, chalked numbers (our own).
- MR_Bench (H_HallBench_8, low, banded): **slatted pine bench** with boots and a gas-mask bag under it (art, inside the box).
- MR_Art (H_Frame_Geometric): a **civil-defence-style notice board** with our own pinned notes (own wording, e.g. a drill timetable).
### Living room (LR, team A spawn)
- Walls: the **west wall is fieldstone** (the room's feature, behind the media console); other walls coffee-brown paint above
  walnut wainscot [22]. Floor: wall-to-wall **gold-greige carpet** (186,150,70 flecked with 140,130,104). LR_Rug = **shag rug** in olive.
- LR_ShelfWall (H_ShelfWall 2 x 8 x 12, tall, team A spawn wall): **walnut built-in room divider** with books, records, a globe and
  a ceramic horse; both faces dressed; solid spine.
- LR_SofaStair (H_Sofa_Sectional 12 x 3.4 x 7.2, low, banded, ambush sofa): **skirted L-sectional in cream vinyl** (210,200,162)
  with tufted back, olive bolster cushions, a test dummy seated at one end (if dummies are approved, see below).
- LR_ChairA / ChairB / LR_Chair (H_Armchair 4.2 x 3.4 x 4, low, banded): **club armchairs in olive tweed** (118,112,70), skirted.
- LR_Media (H_TVConsole 8 x 3.4 x 2.02, low): **console TV + radiogram in walnut**, CRT screen and speaker cloth set in the front,
  all inside 3.4 (no TV above it any more).
- LR_Bookcase1/2 (H_Bookcase 6 x 8 x 1.6, tall): walnut **glass-front bookcases** (glass art only, solid back).
- LR_Sideboard (H_Dresser 6 x 3.4 x 2.3, low): **walnut credenza** with sliding doors, a decanter set and a lamp.
- LR_Screen (H_SlatScreen 6 x 8 x 2.04, tall): **spindle room divider** (turned walnut spindles over a solid core panel).
- LR_Coffee: kidney-shaped coffee table; LR_Side: round side table; LR_Lamp1/2: **tripod floor lamps with drum shades**;
  LR_Plant: philodendron in a brass pot; LR_Art1: **gold-framed desert landscape oil** (own); LR_Art2: own **abstract print** in mustard/olive/cream.
### Ground bathroom (GB)
- Walls: **square wall tiles to 4.5 high in mint** (176,204,182) with a black bullnose line, Sprig paper above; floor: small hex tiles white/black.
- GB_Tub (H_Bathtub 7 x 3.4 x 3.6, low): **built-in tub with a tiled apron and ledge to 3.4** (mint tiles), chrome taps (tap may rise to 4.1 as now).
- GB_Cabinet (H_TallCabinet, tall): painted linen cupboard (cream). GB_Vanity: **pedestal sink or small vanity in mint laminate**;
  GB_Mirror: **medicine cabinet** with chrome frame; GB_Toilet: mint toilet matching the tub; GB_ShowerGlass: **vinyl shower curtain**
  (pale yellow, own pattern) on a chrome rod, same box; GB_ShowerSet: chrome shower head + cross taps; GB_Towel: chrome rail, faded towel.
### Dining room (DR)
- Walls: **Sprig** paper over walnut wainscot; floor: **checker lino cream/rust-tan** [26][27]. Plate rail at 8.
- DR_Table (H_DiningSet x2, 16 x 3.4 x 6.67, low, banded): **walnut table, chrome-edged**, chairs = **vinyl-and-chrome dinette chairs**
  in mustard (204,150,40), backs at 3.4; the table **fully set** (plates, glasses, a roast under a cover) all inside the table box. Two dummies seated.
- DR_Cabinet (H_Bookcase, tall): **walnut china hutch** with glass doors (art), plates on display, closed base.
- DR_Sideboard (H_TVConsole as sideboard, low): walnut buffet with a fruit bowl and candlesticks.
- DR_Pend1/2: **opal glass globe pendants** on brass chains. DR_Art: gold-framed landscape; DR_Plant: rubber plant.
### Kitchen (KT, team B spawn)
- Walls: **Diamond** paper in mint-sage (192,202,158) with cream and tan; splashback band of square tiles in cream. Floor: **checker lino
  off-black/bone** [32] (different from the dining room's so the rooms read apart). Glass dome ceiling light.
- **Enamel colour: harvest gold (206,160,52)** on every cabinet door (replaces the reference's red [21]); chrome bar handles; grey laminate
  counters (138,134,118) with a ribbed chrome edge; a few doors left ajar (art).
- KT_CounterN (KitchenRun6, 24 x 3.4 x 2.46, low), KT_CounterE, KT_CounterPT: the same 4-wide modules re-skinned (base / sink with a
  chrome drainer / **freestanding-look range** with coil burners for H_KitchenHob); uppers + range hood in the same gold enamel.
- KT_Island (H_KitchenIsland 10 x 3.4 x 4.68, low): **enamel peninsula-style island** with laminate top and chrome edge; seating overhang kept.
- KT_Fridge (H_Fridge 3.6 x 8 x 2.86, tall): **rounded-top single-door fridge**, enamel white, chrome lever handle; a separate
  top freezer cabinet filling the box to 8 (the fridge itself ~6.5 tall, a walnut cabinet over it to 8).
- KT_Pantry (H_Pantry, tall): tall gold enamel broom/pantry cupboard. KT_TallUnit (H_OvenWall 12 x 8 x 2, tall, team B spawn wall):
  **built-in twin wall ovens in brushed steel** set in gold enamel, cupboards on the back face.
- KT_Screen (H_SlatScreen, tall): spindle divider (mirror of LR_Screen).
- KT_Bench (H_KitchenBench 10 x 3.4 x 3.5, low, banded): **diner booth in mustard-and-cream vinyl**, chrome trim [32]; a dummy seated (optional).
- Dressing swaps: KT_Coffee -> **percolator**; KT_Kettle -> **whistling kettle**; KT_Micro -> **toaster + bread bin** (no microwaves);
  KT_Bowl -> fruit bowl with wax fruit; KT_Plant -> potted herb; KT_Stool1-3 -> **chrome bar stools with olive vinyl tops**.
  Add on counters (art, inside the counter box): canister set, a radio, a cake under a glass dome, a calendar (own month page "1965").

## Rooms (upper floor)
### Landing (LD) and Upper hall (UH)
- Walls: **Vine** paper over wainscot; floor: greige carpet; flush dome light.
- LD_Bookcase (H_Bookcase, tall): walnut bookcase with encyclopaedias and a clock radio.
- UH_Linen (H_TallCabinet, tall): painted linen press (cream (226,220,200)).
### Master bedroom (MB) + ensuite (EN, closed)
- Walls: **Sprig** paper in its warm rose colourway (print (176,120,104) on cream), no wainscot (bedrooms get only a picture rail).
  Floor: gold carpet; MB_Rug: oval braided rug. Drapes bottle green.
- MB_HeadWall (H_HeadboardWall 14 x 8 x 1.5, tall): **walnut panelled bed wall** with a padded mustard headboard section and two
  built-in reading lamps; solid.
- MB_Bed (H_Bed_Double, low, banded): **walnut bed** with a **chenille bedspread** (cream with olive tufted pattern), skirt to the floor.
- MB_Wardrobe1/2 (H_Wardrobe, tall): walnut wardrobes with brass pulls. MB_Dresser (H_Dresser, low): **walnut lowboy** with a skirted plinth, a mirror art above it (on the wall, not on the box).
- MB_Chair (H_Armchair, low, banded): slipper chair in olive. MB_Night1/2: walnut nightstands; MB_Lamp1/2: ceramic table lamps with pleated shades;
  MB_FloorLamp: tripod lamp; MB_Plant: snake plant; MB_Art: landscape oil.
- EN (closed): pink-tile bathroom behind the closed door (only matters if the door ever opens).
### Bedroom 2 (BR2, teen / guest room)
- Walls: knotty pine panelling on the bed wall, mustard paint (198,160,58) elsewhere; floor greige carpet; drapes gold.
- BR2_Bed (H_Bed_Double, low): **maple spindle bed**, plaid spread (olive/cream/rust). BR2_Wardrobe, BR2_Bookcase: maple.
- BR2_Dresser (H_Dresser, low): maple dresser, closed base, a record player on top.
- BR2_Desk: **steel tanker desk** (grey-green (120,128,112)); BR2_Chair: wooden chair; BR2_Laptop -> **portable typewriter** (same box);
  BR2_Art: own pennant/poster in own words; BR2_Lamp: gooseneck lamp.
### Bedroom 3 (BR3, kid's room)
- Walls: **Vine** paper in a pale yellow colourway with a painted rocket frieze at chair-rail height (own art); floor: **carpet tiles in
  mustard and olive** [01] (replaces the reference's mustard/navy).
- BR3_Bed (H_Bed_Single, low): **maple spindle single bed** with a cowboy-print spread (own pattern). BR3_Wardrobe, BR3_Dresser: painted cream.
- BR3_Desk / BR3_Chair: small maple school desk + chair. Toys: BR3_Blocks -> **wooden alphabet blocks** (own letters), BR3_Ball -> rubber
  ball, BR3_Car -> **tin toy car**, BR3_Teddy -> worn teddy; add a **tin rocket** on the dresser. BR3_Art: own framed rocket drawing.
### Upper bathroom (UB)
- Same kit as GB in **butter yellow** tiles (232,214,140) with a black line (the two bathrooms read apart); UB_Tub built-in with tiled apron to 3.4.

## Garage and outbuildings (if any space in the exterior shows one)
The House has no playable garage. If the exterior shed or a neighbour's open garage is seen from a window: concrete floor with oil stain,
pegboard with tools, bikes on hooks, a workbench, paint cans, a hanging banner of our own design (not a flag with a symbol) [20][24].

## Test dummies (new dressing; needs the Lead's OK, they are not in house_props.md)
- New art-only pieces `H_Dummy_Sit`, `H_Dummy_Stand`, `H_Dummy_Lean`: faceless smooth head, **chalk grey (196,192,180)** body with
  visible joints, a stencilled number on the chest (our own font), simple period clothes (cardigan, skirt, suit jacket) in muted colours.
- No collision, CanQuery off. **Never shaped or coloured like a player:** taller and thinner than an R15 avatar, never standing in a
  doorway, an arch or on a first-look sight line from a spawn; seated on the sofa, at the dining table and in the booth; one leaning at
  the kitchen counter; one in BR2. Proposed 6 total. They sit inside existing furniture boxes or against walls between openings.

## Exterior seen from the windows (H_Exterior.fbx restyle)
- Ground: **tan desert** (196,170,128) with dry patchy grass (138,138,84) in the yards; mountains on a backdrop ring in haze.
- Neighbour houses: **1960s ranch and two-storey houses** in pastel siding (mint (170,206,182), butter (232,214,140), salmon (226,170,150))
  on fieldstone bases, white trim, shallow gable roofs (replace the modern cladding and butterfly roof).
- The house itself outside: white lap siding on a fieldstone base, a shallow gable roof (Lead's call: the shell's roof shape is not in
  house_props.md footprints, so it may change; the walls and openings may not).
- Street: worn asphalt, concrete curbs, **wooden power poles** with sagging wires (keep), picket fences, a trellis arch, a shed.
- Cars: **rounded 1960s sedan and station wagon** in faded pastels, a box delivery truck with our own company lettering.
- Trees: few, dry (desert willow, dead fruit tree), hedges kept but browner.
- Landmark: a **steel instrument mast** of our own design (lattice mast with a boxy cabin and antennae) about 300 studs north-east,
  framed by the foyer feature window and the landing.

## Lighting (for the builder; listed here so the modeler bakes the right emissives)
Hazy desert afternoon: Future, ClockTime ≈ 15.5, Atmosphere Density ≈ 0.35, Haze ≈ 2.5, Colour (214,196,166), Ambient ≈ 65 grey,
OutdoorAmbient (170,160,140), ColorCorrection Saturation -0.15, Tint (255,246,228). Practical lights: warm (255,200,140), lamp
shades and dome glass as separate meshes so they can glow; ≤ 40 lights per view.

## Modeler checklist
- [ ] Every H_* piece re-skinned inside its existing box; pivots, fronts and collision bands unchanged (texel_pivot_check 0 mismatches)
- [ ] Every cover piece has a closed base; no open-leg gap inside a cover box
- [ ] No red or blue surfaces larger than a book spine; olive / cream allowed and welcome
- [ ] All textures, patterns, posters and words our own; none traced from the references
- [ ] Wear decals on walls/floors as separate layers (so the builder can tone them); sand drifts ≤ 0.15 tall, art only
- [ ] Drapes clear of every window opening; tape crosses on the glass meshes
- [ ] New sheet `notes/house_1965_props_sheet.jpg` with the 5-stud human beside each piece, like house_props_sheet.jpg
