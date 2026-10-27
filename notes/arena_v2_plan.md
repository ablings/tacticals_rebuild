# Arena v2: layout plan (for Edward's approval, nothing built)

Tacticals' second match map, "Arena" (was "Practice Range"; the systems session is renaming it, build script `fix/map_arena.lua`).
**Plan only:** no place or code was touched. The layout is data (`notes/maps/arena_v2_layout.json`, made by
`tools/arena_v2_layout.py`) and every number below comes from `tools/arena_v2_check.py` (output `notes/maps/arena_v2_checks.json` / `.txt`).
Rebuild everything: `python -I tools/arena_v2_layout.py && python -I tools/arena_v2_check.py && python -I tools/arena_v2_plot.py && python -I tools/arena_v2_section.py`.

Kept from Edward's earlier calls: an open-roofed white box, no doors, no props or effects, everything white SmoothPlastic with the
training-room grid, 150 x 110 inside (walls 16), modes 1v1 / 2v2 / 3v3. New: the layout, the **window** piece and the **ramp + deck** piece.

![[arena_v2_plan.png]]
*Plan in studs (x east, y north). Darker = taller. Hatched = window opening. Green = deck +4 with its ramp (arrow = up). Orange =
deliberate open gaps (length, sprint time, cover-dash time). Dashed = key sight lines. A spawns west (blue), B east (red).*

## The idea in one paragraph
Three lanes (north, centre, south) between two hidden spawn pockets. The **centre** is one big **twin window** wall across the middle: both
players reach their own sill in about 4 seconds and fight through the openings. Each outer lane is closed on one side by a **gate**, a
twin window that touches the outer wall, so entering the enemy's half through a lane means vaulting a window or squeezing through an
8.5-wide gap at the gate's inner end. Each side owns **one height and one window**, on opposite lanes: A has the **perch** in the
north-west and the **south gate**; B has the **north gate** and the **ledge** in the south-east. A perch watches the lane the other
side's gate holds, so each high spot is answered by a window 50 studs away. In the middle of each outer lane a small **island** (a
pillar with a low wall in the north; a low wall between two pillars in the south) splits the open stretch into two **gaps** you have to decide to cross. The halves have the same jobs
but different shapes (square perch with a parapet and a curb against a long ledge with a wall on it, wall shields against a
pillar-wall-pillar shield, pillar chains against wall chains), and fairness comes from timing, not mirroring: every A/B pair below is
within 8 %.

## How a 1v1 round plays
1. **Spawn (0 s).** Both pockets are hidden from each other: 0 of 43,681 eye-height pairs see across, so nobody is shot at the start.
2. **First choice (0-3 s): centre, own lane, or other lane.** Your own gate is the closest thing (3.0 s), the middle sills and your high
   ground about 3.5-4 s. The enemy's high ground is twice as far (7.8-8.1 s), so it can't be rushed.
3. **Centre (4 s).** Both reach their sill within 0.04 s of each other. Crouched behind the 3.4 sill you're hidden; standing you
   shoot through a 10 x 6.6 opening. Pushing means vaulting through (0.34 s, very visible) or flanking round the ends.
4. **North lane.** A goes up the ramp (3.4 s) and watches the lane from 4 up, or walks the lane: A's last cover is the pillar + low wall
   at x -18, then the **north gap** (14.8 studs, 0.6 s cover dash) to the island, then 20.7 studs (0.9 s dash) to B's gate. B holds the
   gate: crouch at a sill, peek through the opening down the whole lane. **The duel here is perch against gate, 50 studs apart**: the
   perch sees the gap and anyone vaulting the gate; the gate sees the perch's front and the gap.
5. **South lane.** The same jobs swapped: B on the ledge, A at the south gate. The south island is closer to B (10.3) than to A's gate
   (14.8), the north island closer to A (14.8) than to B's gate (20.7): each side has a short approach in one lane and a long one in
   the other.
6. **Rotations.** A moves north to centre through a 12.3 gap (pillar chain to the centre pillar), B moves south to centre through 10.3.
   Every rotation gap is watched by both the enemy's height and its gate: crossing it is a decision, not a walk.
7. **Closing the round.** The player who wins one lane can come in behind the other: through the gate (vault) or round the gate's inner
   end, then on to the enemy's sill or ramp. The ramps are on each owner's own side, so taking the enemy's high ground is the deepest
   push in the map.

## Advantage spots: what each wins, and its counter
| Spot | Reached (own side / enemy) | What it wins | Counter |
|---|---|---|---|
| **A perch** (NW, deck 4, 12 x 10) | 3.6 s / 7.9 s | Its **watch edge** (south, kick-curb) sees 30 % of the floor for crouched targets against 24 % from the floor in front of it: the north gap, the island and anyone crouch-walking or vaulting in the north lane. Its **duel edge** (east, 3.4 parapet) is a crouch spot facing B's gate | B's north gate sills (50 studs, sill against parapet). The island pillar hides the island's far side. The watch edge has no crouch cover: whoever peeks there is seen full height from the lane. The parapet hides the perch's own foot for ~11 studs. Taking it means going up A's ramp (7.8 s for B) |
| **B ledge** (SE, deck 4, 20 x 8) | 3.4 s / 8.1 s | Long open front (kick-curb) with a wall standing on the deck: two peek spots (west end 29 % of the floor crouched, east end 26 %). Sees the south gap, the island and A's gate. Sees its own foot (80 %) | A's south gate sills (50 studs). The wall under the ledge (x 10-20) is tall cover for attackers outside its view line. No crouch cover on the ledge. Ramp on B's side |
| **B north gate** (twin window, x 23) | 3.0 s / 5.7 s | Closes the north lane: crouch at either sill, peek through 10 x 6.6 openings at the whole lane and at A's perch. Its posts are 12 high: nothing sees over them | The perch sees anyone standing in the openings. A can flank round the gate's south end (8.5 gap) from the centre. Vaulting in from A's side puts A right on top of a crouched holder |
| **A south gate** (twin window, x -23) | 3.0 s / 5.9 s | The same for the south lane | The ledge, the gate's north end, vaulting |
| **Centre sills** (twin window, x 0) | 3.9-4.0 s both | The shortest fight. Two openings and three 12-high posts: you choose which opening to hold | The other opening, the lane rotations onto your flank, the enemy's high ground sees your fallback cover |
| **Islands** (north: pillar + low wall; south: pillar, low wall, pillar) | N 4.2 / 4.5 s, S 4.4 / 4.5 s | The only cover in the middle of each outer lane. Whoever holds it can cross to the enemy's gate | Seen from both the enemy's height and its gate. The crossing to it is a watched gap |

## Gaps (deliberate open crossings)
Cover dash (E) reaches 26 studs at 24 studs/s; sprint is 20/s. "Watched by" = the named spots that see the gap's middle at chest height.

| Gap | Length | Run / dash | Floor that sees it | Watched by |
|---|---|---|---|---|
| North gap A (A chain to island) | 14.8 | 0.74 / 0.62 s | 31 % | A perch, B gate, both sills |
| North gap B (B gate to island) | 20.7 | 1.04 / 0.86 s | 32 % | A perch, B gate, B ledge |
| South gap B (B chain to island) | 10.3 | 0.51 / 0.43 s | 26 % | B ledge, A gate |
| South gap A (A gate to island) | 14.8 | 0.74 / 0.62 s | 31 % | A perch (duel edge), A gate |
| Centre A (A chain to sill) | 10.0 | 0.50 / 0.42 s | 26 % | both sills, B gate |
| Centre B (B wall to sill) | 9.0 | 0.45 / 0.38 s | 23 % | both sills, A perch, A gate |
| Rotation A (north chain to centre pillar) | 12.3 | 0.61 / 0.51 s | 36 % | A perch, B gate |
| Rotation B (south chain to centre wall) | 10.3 | 0.51 / 0.43 s | 36 % | B ledge, A gate |

No gap is longer than one cover dash (26): every crossing can be done in one committed dash, and the longest (20.7, 0.86 s) is in
front of the gate that guards it.

## Checks (plan view, `tools/arena_v2_check.py`)
| Check | Result |
|---|---|
| Overlaps; gaps between pieces 0, up to 1.5 (cover chain) or at least 4 (a lane), never 1.5-4 | **0 overlaps, 0 snag gaps** (64 pieces, 88 parts) |
| Unwanted climbs (a top 0-5.6 above where you stand; low walls and sills must have 3.5 clear behind so Space vaults; low walls met END-ON, which read 6 deep and get climbed) | **0** (every deck edge has a parapet, curb, ramp or the box wall; no wall or pillar top in climb reach of a deck; 20 low walls have a free end and can be stood on (eye 8.0, fully exposed), but none has a wall, parapet or deck within 3.5, so nothing chains upward) |
| Spawn pocket to spawn pocket line of sight (whole pockets, 1-stud grid, eye to eye and eye to chest) | **0 of 43,681** |
| Exposure: % of the floor each spot sees at eye height (eye 4.6 to chest 4.0) | min 3.3 / **mean 26.9** / max 40.9 (RIVALS Arena: 9.5 / 26.5 / 39) |
| 10-stud bands along the long axis | outside the spawn pockets **spread 4.0** (rule 6); pockets 17.5-18.2 (hidden on purpose) |
| Sight lengths (visible floor pairs) | median 40, 90th percentile 83, max 162 (a corner diagonal threading the centre's south opening); 7.2 % over 90 |
| Farthest floor spot from cover | **13.0** (mean 5.0): every spot is within half a cover dash of cover |
| Floor covered by pieces | 12.9 % (RIVALS 17 %; Tacticals' pieces are smaller and the floor is bigger) |
| Reachability | every standable cell reachable from both spawns; ramps are the only way onto decks |
| Highest eye + hop | 4 + 4.6 + 2.2 = 10.8, under the 16 walls |
| Ramps | both 4 up over 12 (18.4°), 8 wide, 0.6 s sprinting / 1.2 s walking; the climb is seen by 2-6 % (A) and 5-11 % (B) of the enemy's half |
| Windows | opening 3.4-10; vault head apex ~7.4, 2.6 under the lintel; every sill has clear landings |

### Timing, sprint from the 1v1 spawn spot (A vs B, must be within 10 %)
| To | A | B | Diff |
|---|---|---|---|
| Middle (nearest own sill) | 3.94 s | 3.98 s | 1 % |
| Own high ground, ramp top | 3.44 | 3.44 | 0 % |
| Own high ground, first peek spot | 3.59 | 3.44 | 4 % |
| Own gate | 3.02 | 2.97 | 2 % |
| Enemy high ground (its ramp top) | 8.08 | 7.78 | 4 % |
| Enemy gate | 5.72 | 5.85 | 2 % |
| North island | 4.22 | 4.54 | 8 % (A's short lane) |
| South island | 4.37 | 4.54 | 4 % |
The 2v2 / 3v3 spots (4 apart in each pocket) are within ±0.2 s of these.

## Ramp rules for Tacticals (why the old 6-high perches were wrong)
Tacticals has no jump (JumpHeight 0; Space hops 2.2, vaults or climbs). Eye 4.6, standing 5.2, crouched 3.2. A player in cover hugs at
0.85 from the face. **CLIMB** (CoverConfig): Space climbs onto anything whose top is up to 2.6 above the root, i.e. up to **5.6 above
your feet**, when the cover is too deep to vault (more than 5) or is head-high.

![[arena_v2_sections.png]]

1. **Height: 3.4-4 up, never 5.4 or more.** The eye then sits between the wall tops (7) and the pillar tops (10): it sees over walls a
   little and never over pillars or windows. At 5.4 the eye reaches the pillar tops and from 6 (the old perches, eye 10.6) it sees over
   every piece in the map. Measured at four floor spots (eye raised in place, crouched targets): 0 to 3.4 up adds 1-7 points of floor
   seen, 3.4 to 5 adds 0-7 more (seeing over walls), and above 5.4 the eye clears the pillars as well. 4 is a deliberately modest
   choice (question 2).
2. **Height does not break a hugged low wall.** The crouched player is 0.85 behind the far face of a 2-deep wall, so every line to them
   has to clear the edge nearest to them: one stud of body shows only within 0.85 x (eye - 2.2) / 1.2 studs, which is 4.5 from a
   deck-4 eye and still only 6.0 from a deck-6 eye. Height wins the floor **between** cover: crouch-walkers, gap crossers, vaulters.
   So a high spot belongs where it looks onto a gap, not onto a cluster of low walls.
3. **Every deck edge stops the climb.** A deck up to 5.6 high can be climbed from the floor anywhere unless the edge has a 3.4
   parapet, a **1-high kick-curb** (0.5 deep: the climb's edge ray at deck + 0.6 hits it), a ramp, the box wall, or a tall piece
   against it. Nothing within 3.5 of a deck may have its top 0-5.6 above the deck (a 7 wall next to a 4 deck can be climbed onto from
   the deck; a 10 pillar next to it clears by only 0.4). Ramps get `NotCover` so CoverController never snaps to or climbs them.
   **Low walls met end-on are climbable too:** CoverController measures depth along your approach, so a 6-long low wall approached at
   its end reads 6 deep (over the 5 limit) and Space climbs on top. A low wall with a free end is therefore a standable top at 3.4:
   nothing within 3.5 of it may have its top 0-5.6 above that (a 7 wall, a parapet, a deck), or the climb chains up to an eye of 11.6.
   Cap both ends with tall pieces (as on the south island: pillar, low wall, pillar) or keep walls 4+ away. Standing on a low wall
   puts your eye at 8.0 with your whole body showing: allowed, and its own punishment. (Found by the map trainer from the code.)
4. **Choose each edge's job.** A **watch edge** gets a kick-curb: a 3.4 parapet hides the floor in front of the deck for ~11 studs and
   cancels the height. A **duel edge** (a long sight line to a defended spot) gets the 3.4 parapet: a crouch spot up high, the same game
   as a low wall. Each deck has one watch edge.
5. **Cover on the deck is tall.** On a curb edge there's no crouch cover, so put a pillar or a wall on the deck (peek its edges), or
   accept that whoever peeks is seen at full height. That exposure is the price of the view.
6. **Ramp: 4 up over 12 (18.4°), 8 wide, rising along a wall.** 0.6 s sprinting, 1.2 s walking. Gentle enough to sprint without
   the camera bobbing, short enough that the climb is a brief exposure. 8 wide lets two pass in 3v3. The foot and the ramp sit on
   the owner's side, behind cover: the climb is seen by under 11 % of the enemy's half.
7. **Ways up and down.** Up: the ramp only. Down: the ramp, hop the curb and drop, or vault the parapet and drop (the vault takes you
   off the deck). No deck is a dead end.
8. **Placement relative to the spawns.** Own ramp top about 3.4 s from your spawn, the enemy's about 8 s: twice as far, so it can't be
   rushed at the start. Each high spot faces the lane held by the enemy's window, so it always has an answer from 50 studs.
9. **A counter for every high spot:** a window or sill that sees it at range, tall cover inside its view for the attacker, a blind
   foot (parapet edges) or a full-height peek (curb edges), and an enemy ramp you can push.

## Window rules for Tacticals
1. **Sill 3.4** (= low-wall height: crouched behind it you're hidden, standing you shoot over it). **Opening 10 wide x 6.6 high**
   (3.4 to 10). **Lintel 10-12.** **Posts 5 wide** (tall cover, peek their edges). Frame 20 long x 3 deep x 12 high; a twin window is 35
   long (post, opening, post, opening, post). It's the tallest piece in the map and the landmark of each area.
2. **Vault clearance.** A running vault puts the root 1.8 above the sill (5.2) and the head about 7.4: the lintel at 10 leaves 2.6. Sill
   depth 3 (at most 5, or Space climbs instead of vaulting).
3. **Clear landings.** At least 3.5 of open floor on both sides of every sill, so the vault is never refused (a refused vault turns
   into a climb onto the sill).
4. **Spacing.** Openings at least 5 apart (one post). Nothing taller than 3.4 within 3.5 of a sill face, so the crouch spot and the
   landing stay clear.
5. **What a window looks onto.** Every window looks down a lane at a gap, and at the enemy's high spot about 50 away. A window that
   looks at a wall is wasted. A window that sees a spawn pocket is not allowed (the spawn check covers it).
6. **Where.** Across the middle (both sides use it) and as lane gates touching the outer wall (one side holds it). A gate always leaves
   a way round its inner end (8.5 wide here), so the vault is a choice, not the only door.

## Taken from RIVALS Arena, changed for Tacticals because ...
| RIVALS Arena | Arena v2 | Because |
|---|---|---|
| Halves are a 180° turn of each other; the left and right flanks differ (ramp flank, window flank), which is why it feels asymmetric | Same jobs on opposite diagonals (perch + gate against gate + ledge), but every piece group has a different shape, and fairness is checked by timing (all pairs within 8 %) | Edward asked for "different but fair". A real turn would make the halves identical from each spawn |
| Window frame 20 x 15 x 5, opening 10 x 7 over a 3 sill | 20 x 12 x 3, opening 10 x 6.6 over a **3.4** sill, twin windows 35 long | The sill must be Tacticals' low-wall height (crouch cover). 12 high is above every other piece, the same rule as RIVALS' frames over its perch eye. Thinner because Tacticals' walls are 3 |
| Corner frames close the side lanes except through the window | Twin-window gates close the outer lanes, with an 8.5 gap round the inner end | Vaulting is a real choice in Tacticals (0.34 s, very visible); a second way round keeps a lane from becoming a single door |
| Centre: a canopy on four pillars | Centre: one twin window across the middle | Edward wants big windows. The centre fight becomes sill against sill through two openings |
| Perch 15 up, 45° ramp, no rail | Deck **4** up, **18.4°** ramp, kick-curb or parapet on every edge | Tacticals' cover is 3.4 / 7 / 10 tall, not 20: the eye must stay under the pillar tops (deck under 5.4). With no jump and a 5.6 climb, a bare edge could be climbed. 18.4° keeps sprinting smooth |
| Full cover 20 high, all pieces 5 thick, 5-stud grid | Tacticals' own pieces: pillar 5 x 5 x 10, wall 10 x 3 x 7, low wall 6 x 2 x 3.4; 0.5 grid | Edward: keep Tacticals' cover pieces (the tutorial sizes CoverController is tuned for) |
| Lanes 10 wide, everything 10 apart | Gaps 9-21 studs, all under one cover dash (26) | Tacticals moves cover to cover with E (up to 26 at 24/s), so gap length is a crossing time, not just a width |
| End slab hides each start (0.1 % start-to-start sight) | A shield 20 long in front of each pocket (A: two walls, B: pillar-wall-pillar); 0 % | Same idea, checked over whole pockets for 3v3 |
| 90 x 130 box, walls 30 | 150 x 110, walls 16, open roof | Edward's footprint and box. 16 is above the highest eye + hop (10.8) |
| Two greys, no accent | White + training grid (Edward's call); decks and ramps can carry a faint olive tint if wanted (question 3) | |

## 2v2 and 3v3
- Spawn spots 4 apart in each pocket (A: (-70, -4 / 0 / 4), B: (70, -1.5 / 2.5 / 6.5)); the spawn check covers the whole pocket.
- Every advantage spot holds two: the perch is 12 x 10, the ledge 20 x 8 with two peek ends, each gate and the centre have two openings.
  With three players a natural split is one per lane, with height, gate and centre each held by one.
- The ramps are 8 wide so two can pass. Nothing else changes; 150 x 110 is roomy for 1v1 (all spots about 3-4 s from spawn) and right for 3v3.

## Building it (after approval)
- Replace the layout block in `fix/map_arena.lua` with one generated from the JSON (pieces, parts, ramp wedges; world = ORIGIN + (x, z, -y)).
  Keep the grid textures, the MatchSpawns markers (SpawnA at (-70, 0), SpawnB at (70, 2.5), facing the middle), MapInfo, Lighting.
- Ramps and the box: `NotCover = true`. Curbs: `NotCover = true` (1 high: never cover). Decks and parapets are normal cover.
- Then a fresh lap in Play at player height: every vault, every climb refusal, both ramps, the drop-offs, and the gaps timed with a
  cover dash; and a `roblox-map-grader` round.

## Open questions for Edward
1. **How asymmetric?** This plan gives both sides the same kinds of spot on opposite lanes (one height, one gate each) with different
   shapes, so it's fair by timing. RIVALS' Arena is actually a 180° turn; it only looks asymmetric because its two flanks differ. Is
   this the asymmetry you want, or should the two sides own different kinds of spot (for example A gets both heights, B gets all the
   windows), which is more different but harder to balance?
2. **High-ground strength.** Measured: the perch's watch edge sees about 6 points more crouched floor than the floor in front of it, and
   no height can break a hugged low wall. That's
   deliberately modest (the old 6-high perches saw over everything). Keep it modest, or go up to 5 (still under the pillar tops) for a
   bit more?
3. **Parts or Blender, and any colour?** The current map is Studio Parts. The vault's rule is to model in Blender unless the brief says
   "build it in Studio". Build v2 from Parts in Studio like v1? And all white as now, or a faint olive on ramps and decks so the way up reads?
