# Arena v2: layout plan (approved by Edward 2026-10-26; next: build it from Studio Parts)

Tacticals' second match map, "Arena" (was "Practice Range"; renamed by the systems session, build script `fix/map_arena.lua`).
**Plan only:** no place or code was touched. The layout is data (`notes/maps/arena_v2_layout.json`, made by
`tools/arena_v2_layout.py`), and every number below comes from `tools/arena_v2_check.py` (output in `notes/maps/arena_v2_checks.json` / `.txt`).
To rebuild everything: `python -I tools/arena_v2_layout.py && python -I tools/arena_v2_check.py && python -I tools/arena_v2_plot.py && python -I tools/arena_v2_section.py`.
A fresh reviewer re-ran and audited the checker (2026-10-26). Its findings are fixed below; see "Review".

**Edward's decisions (2026-10-26):** the asymmetry as planned (yes); decks **5** high ("5 is fine"); build from **Studio Parts**. Colour: no change asked, so all white + grid as now. This version (v2 of the data) has decks at 5 and ramps at 22.6°; all numbers below are re-checked at 5.

Kept from Edward's earlier calls: an open-roofed white box, no doors, no props or effects, everything white SmoothPlastic with the
training-room grid, 150 x 110 inside (walls 16), modes 1v1 / 2v2 / 3v3. New: the layout, the **window** piece and the **ramp + deck** piece.

![[arena_v2_plan.png]]
*Plan in studs (x east, y north). Darker = taller. Hatched = window opening. Green = deck +5 with its ramp (arrow = up). Orange =
deliberate open gaps (length, sprint time, cover-dash time). Dashed = key sight lines. A spawns west (blue), B east (red).*

## The idea in one paragraph
Three lanes (north, centre, south) run between two hidden spawn pockets. The **centre** is one big **twin window** wall across the middle:
each player reaches their own sill in about 3.9 seconds and fights through the openings. Each outer lane is closed on one side by a
**gate**, a twin window that touches the outer wall. Entering the enemy's half through a lane means vaulting a window or squeezing through
an 8.5-wide gap at the gate's inner end. Each side owns **one height and one window**, on opposite lanes: A has the **perch** in the
north-west and the **south gate**; B has the **north gate** and the **ledge** in the south-east. A high spot watches the lane the other
side's gate holds, so each height is answered by a window 50 studs away. In the middle of each outer lane an **island** splits the open
stretch into two **gaps** you have to decide to cross: in the north a pillar with a low wall running south, in the south a pillar with a
low wall running east. The halves have the same jobs but different shapes:
- a square perch with a parapet and a curb, against a long ledge with a wall standing on it;
- wall shields against a pillar-wall-pillar shield;
- pillar chains against wall chains.

Fairness comes from timing, not mirroring: every A/B timing pair is within 7 %. The high spots are deliberately **not** equal; see
"Asymmetry, stated openly".

## How a 1v1 round plays
1. **Spawn (0 s).** Both pockets are hidden from each other: 0 of 43,681 eye-height pairs see across. The first moment an enemy can see a
   spawn spot at all is 5.1 s, long after you've left it.
2. **First choice (0-3 s): centre, own lane, or other lane.**
   - Your own gate is the closest thing (2.8 s).
   - Your high ground's ramp top is 3.3 s; the middle sills about 3.9 s.
   - The enemy's high ground is more than twice as far (7.5-7.7 s), so it can't be rushed.
3. **Centre (about 3.9 s).** Both reach their sill within 0.03 s of each other. Crouched behind the 3.4 sill you're hidden; standing you
   shoot through a 10 x 6.6 opening. Pushing means vaulting through (0.34 s, very visible) or flanking round the ends.
4. **North lane.**
   - A goes up the ramp and watches the lane from 5 up, or walks it. A's last cover is the pillar + low wall at x -18.
   - Then comes the **north gap**: 14.8 studs (0.6 s cover dash) to the island, watched by B's gate.
   - From the island it's 20.7 studs (0.9 s dash) to B's gate, watched by A's perch.
   - B holds the gate: crouch at a sill, peek through the opening down the whole lane.
   - **The duel here is perch against gate, 50 studs apart.** The perch sees B's crossing and anyone vaulting the gate; the gate sees
     A's crossing and the perch's front.
5. **South lane.** The same jobs, swapped: B on the ledge, A at the south gate. A's crossing (gate to island, 14.8) is watched by both
   ledge peeks; B's crossing (chain to island, 13.9) is watched by A's gate.
6. **Rotations.** A moves from the north lane to the centre through a 12.3 gap; B moves from the south lane to the centre through 10.3.
   Each is watched by the enemy's gate and the enemy's sill, so crossing is a decision, not a walk.
7. **Closing the round.** The player who wins one lane can come in behind the other: through the gate (vault) or round the gate's inner
   end, then on to the enemy's sill or ramp. The ramps are on each owner's own side, so taking the enemy's high ground is the deepest
   push in the map.

## Advantage spots: what each wins, and its counter
"Crouched floor seen" = % of the floor where a crouched head would be visible from the spot's peek position. Compare a spot on the floor just
in front of the deck.

| Spot | Sprint to it (own side / enemy) | What it wins | Counter |
|---|---|---|---|
| **A perch** (NW, deck 5, 12 x 10) | 3.4 s / 7.6 s | Its **watch edge** (south, kick-curb) sees 24.3 % crouched floor, against 18.8 % in front of it (+5.5), and watches B's crossing to the north island. Its **duel edge** (east, 3.4 parapet) is a crouch spot facing B's gate | B's north gate sills, 50 studs (sill against parapet). The island pillar hides the island's far side. The watch edge has no crouch cover: whoever peeks there is seen at full height. The parapet hides the perch's own foot for about 14 studs (only 3 % of it is seen from the duel edge). Taking it means going up A's ramp (7.5 s for B) |
| **B ledge** (SE, deck 5, 20 x 8) | 3.3 s / 7.8 s | A long open front (kick-curb) with a wall on the deck; two peek ends. West end 26.2 % crouched floor (front 24.2), east end 26.8 % (front 22.4). Sees most of its own foot (77-83 %). Watches A's crossing to the south island **and** B's own rotation line | A's south gate sills (50 studs). The wall under the ledge (x 10-20) is tall cover for attackers, outside its view line. No crouch cover on the ledge. Its ramp climb is more exposed than A's (3-10 % of A's half sees it, against 2-6 %) |
| **B north gate** (twin window, x 23) | 2.8 s / 5.5 s | Closes the north lane: crouch at either sill, peek through 10 x 6.6 openings at the whole lane and at A's perch. Its posts are 12 high: nothing sees over them | The perch sees anyone standing in the openings. A can flank round the gate's south end (8.5 gap) from the centre. Vaulting in from A's side lands A right on a crouched holder |
| **A south gate** (twin window, x -23) | 2.8 s / 5.7 s | The same, for the south lane | The ledge, the gate's north end, vaulting |
| **Centre sills** (twin window, x 0) | 3.86 s / 3.89 s | The shortest fight. Two openings and three 12-high posts: you choose which opening to hold | The other opening; the lane rotations onto your flank |
| **Islands** | N 4.1 / 4.3 s, S 4.2 / 4.3 s | The only cover in the middle of each outer lane. Whoever holds it can cross on to the enemy's gate | Seen from the enemy's height and gate; the crossing to it is a watched gap |

### Asymmetry, stated openly
- **A's perch gains more view** (+5.5 points of crouched floor, against +2.0 and +4.4 for the ledge's two ends).
- **B's ledge has no blind foot.** It sees its own foot, while A's parapet edge is blind at its foot. It also watches two of A's lines:
  the south crossing and the line into the centre.
- **B's climb is more visible.** Its ramp is seen by 3-10 % of A's half, against 2-6 % for A's ramp.
- **Spawn sight comes earlier on A.** The first enemy sight of a spawn spot is 5.1 s for A (B looking through A's south gate), 5.8 s for B.
- **Approaches.** A's island approaches are 14.8 (north) and 14.8 (south); B's are 20.7 (north) and 13.9 (south).

These trade-offs are deliberate, and Edward approved this asymmetry (2026-10-26). All timing pairs are within 7 %.

## Gaps (deliberate open crossings)
A cover dash (E) reaches 26 studs at 24 studs/s; sprint is 20 studs/s. **Watched by the enemy** means an enemy spot that sees at least half of
the crossing line (7 points, chest height), with the share it sees.

| Gap (who crosses) | Length | Run / dash | Watched by the enemy |
|---|---|---|---|
| North gap A (A chain to island) | 14.8 | 0.74 / 0.62 s | B north gate 100 % |
| North gap B (B gate to island) | 20.7 | 1.04 / 0.86 s | A perch 100 % |
| South gap B (B chain to island) | 13.9 | 0.69 / 0.58 s | A south gate 100 % |
| South gap A (A gate to island) | 14.8 | 0.74 / 0.62 s | B ledge east 71 %, west 57 % |
| Centre A (A chain to sill) | 10.0 | 0.50 / 0.42 s | B north sill 100 %, B north gate 100 %, B south sill 57 %, B ledge east 57 % |
| Centre B (B wall to sill) | 9.0 | 0.45 / 0.38 s | A sill 100 %, A south gate 86 % |
| Rotation A (north chain to centre pillar) | 12.3 | 0.61 / 0.51 s | B north gate 100 %, B sill 86 % |
| Rotation B (south chain to centre wall) | 10.3 | 0.51 / 0.43 s | A south gate 100 %, A sill 86 % |

No gap is longer than one cover dash (26), so every crossing can be done in one committed dash. The longest, 20.7 at 0.86 s, lies in
front of the gate that guards it. The farthest any floor spot is from cover is 13.0, half a cover dash.

## Checks (plan view, `tools/arena_v2_check.py`)
| Check | Result |
|---|---|
| Overlaps; gaps between pieces must be 0, up to 1.5 (cover chain) or at least 4 (a lane), never 1.5-4 | **0 overlaps, 0 snag gaps** (66 pieces, 90 parts) |
| Unwanted climbs: a top 0-5.6 above where you stand; 3.5 of clear landing along the whole length of each low wall and sill; low walls met END-ON (6 deep, so they get climbed) | **0** chains. Every deck edge has a parapet, curb, ramp or the box wall, and no wall or pillar top is in climb reach of a deck. 21 low walls have a free end and can be stood on (eye 8.0, whole body showing); none has a wall, parapet or deck within 3.5, so nothing chains upward |
| Spawn pocket to spawn pocket line of sight (whole pockets on a 1-stud grid, eye to eye and eye to chest; the reviewer re-did it with exact geometry) | **0 of 43,681** |
| Named spots that see the enemy's pocket; the holder's side of every window, with the eye sampled along the whole opening | **0** (three pillars, one on A's side and two on B's, close the 100-stud lines from each gate to the far pocket's edge) |
| Spawn camp: the first time an enemy can stand somewhere that sees a spawn spot | A 5.1 s, B 5.8 s (rounds start with both in their pockets, so both have long since left) |
| Exposure: % of the floor each spot sees at eye height (eye 4.6 to chest 4.0) | min 3.4 / **mean 25.0** / max 36.6 (RIVALS Arena: 9.5 / 26.5 / 39) |
| 10-stud bands along the long axis | **spread 4.8** from x -55 to 55. The bands holding the spawn shields are 24.3 (A) and 22.7 (B), and the pockets 16.4 (hidden on purpose). Counting the shield bands the spread is 6.7, just over the 6-point guide: the area right at B's pocket exit is a little safer, which is harmless |
| Sight lengths (visible floor pairs) | median 38, 90th percentile 81, max 159; 6.7 % over 90 (corner diagonals through window openings) |
| Floor covered by pieces | 13.2 % (RIVALS 17 %; Tacticals' pieces are smaller and the floor is bigger) |
| Reachability | every standable cell reachable from both spawns; ramps are the only way onto the decks |
| Highest eye + hop | 5 + 4.6 + 2.2 = 11.8, under the 16 walls |
| Ramps | both 5 up over 12 (22.6°), 8 wide, 0.6 s sprinting / 1.2 s walking |
| Windows | opening 3.4-10; vault head apex 7.4-7.8, so 2.2+ under the lintel; every sill has clear landings. No holder's side of any window sees the enemy's pocket; the gate sills only see their own side's pocket |

### Timing, sprint from the 1v1 spawn spot (A against B; must be within 10 %)
Paths on a 0.5-stud, 16-neighbour grid (any-angle error at most 2.8 %), with vaults, drops and ramps; sprint 20 with no stamina limit.

| To | A | B | Diff |
|---|---|---|---|
| Middle (nearest own sill) | 3.86 s | 3.89 s | 1 % |
| Own high ground, ramp top | 3.25 | 3.30 | 2 % |
| Own high ground, first peek spot | 3.43 | 3.32 | 3 % |
| Own gate | 2.84 | 2.75 | 3 % |
| Enemy high ground (its ramp top) | 7.73 | 7.45 | 4 % |
| Enemy gate | 5.50 | 5.67 | 3 % |
| North island | 4.07 | 4.34 | 7 % (A's short lane) |
| South island | 4.24 | 4.31 | 2 % |

The 2v2 / 3v3 spots (4 apart in each pocket) are within ±0.2 s of these.

## Ramp rules for Tacticals (why the old 6-high perches were wrong)
Tacticals has no jump: JumpHeight is 0, and Space hops 2.2, vaults or climbs. Eye 4.6, standing 5.2, crouched 3.2 (crouch height is an
assumption; measure it in Play). A player in cover holds the root 0.85 from the face. **CLIMB** (CoverConfig): Space climbs onto anything
whose top is up to 2.6 above the root (5.6 above the feet on the default R15 rig), when the cover is more than 5 deep **along your
approach** or is head-high.

![[arena_v2_sections.png]]

1. **Height: 4-5 up, never 5.4 or more (Edward picked 5).** The eye (9.6 at 5) then sits between the wall tops (7) and the pillar tops
   (10): it sees over walls and never over pillars or windows. 5 is the ceiling: at level pitch the third-person camera (feet + 5.1 = 10.1) only grazes
   the pillar tops. Looking down lifts the camera by about 8 x sin(pitch), so it can peek a little over pillars, but shots come from
   the muzzle at eye level (9.6). At 5.4 the eye reaches the pillar tops, and from 6 (the old perches, eye 10.6) it sees over
   every piece in the map.
   - Measured at four floor spots (eye raised in place, crouched targets; `tools/arena_v2_height_sweep.py`): 0 to 3.4 up adds 4-8
     points of floor seen; 3.4 to 5 adds 0-6 more (seeing over walls); above 5.4 the eye clears the pillars as well.
   - Edward chose 5 over 4 (2026-10-26): the perch's watch edge gains +5.5 points over the floor in front of it.
2. **Height does not break a hugged low wall.** The crouched player is 0.85 behind the far face of a 2-deep wall, so every line to them
   has to clear the edge nearest to them. One stud of body shows only within 0.85 x (eye - 2.2) / 1.2 studs: 5.2 from a deck-5 eye,
   still only 6.0 from a deck-6 eye.
   - Height wins the floor **between** cover: crouch-walkers, gap crossers, vaulters. So a high spot belongs where it looks onto a gap,
     not onto a cluster of low walls.
   - This holds only while a crouched head stays under the 3.4 low-wall top; measure that in Play.
3. **Every deck edge stops the climb.** A deck up to 5.6 high (5 is) can be climbed from the floor anywhere, unless the edge has one of:
   a 3.4 parapet; a **1-high kick-curb** (0.5 deep: the climb's edge ray at deck + 0.6 hits it, and its head-height probe makes the deck
   read as tall cover); a ramp; the box wall; or a tall piece against it.
   - Nothing within 3.5 of a deck may have its top 0-5.6 above the deck. At deck 5 that includes a 10 pillar (5 above) as well as a 7
     wall: keep every pillar and wall at least 4.5 from a deck (the cover system detects 3.5 from the waist, and you can stand about
     1 past the edge; the checker uses 4.5), or stand it on the deck itself.
   - Ramps get `NotCover`, so CoverController never snaps to or climbs them.
   - **Low walls met end-on are climbable too.** A 6-long low wall approached at its end reads 6 deep (over the 5 limit), and Space
     climbs on top. A low wall with a free end is therefore a standable top at 3.4: nothing within 3.5 of it may have its top 0-5.6
     above that (a 7 wall, a parapet, a deck), or the climb chains up to an eye of 11.6.
   - Fix by capping the end with a pillar (its top is 6.6 above the low wall, out of reach) or keeping walls 4+ away. Standing on a low
     wall puts your eye at 8.0 with your whole body showing: allowed, and its own punishment. (Found by the map trainer from the code.)
4. **Choose each edge's job.** A **watch edge** gets a kick-curb: a 3.4 parapet hides the floor in front of the deck for about 14 studs at deck 5
   and cancels the height. A **duel edge** (a long sight line to a defended spot) gets the 3.4 parapet: a crouch spot up high, the same
   game as a low wall. Each deck has one watch edge.
   - Standing on the 1-high curb (if a hop can land on a 0.5-deep ledge) would put the eye at 10.6, over the pillar tops. Measured, it
     adds only 1-2 points of floor. Check it in Play; if it works and matters, make the curb a wedge (sloped top) so nobody can stand on it.
5. **Cover on the deck is tall.** A curb edge gives no crouch cover, so put a pillar or a wall on the deck (peek its edges), or accept that
   whoever peeks is seen at full height. That exposure is the price of the view.
6. **Ramp: 5 up over 12 (22.6°), 8 wide, rising along a wall.** It takes 0.6 s sprinting, 1.2 s walking: gentle enough to sprint, short
   enough that the climb is a brief exposure (keep it under about 25°; a 15 run gives 18.4° where there's room). 8 wide lets two pass in 3v3. The foot and the ramp sit on the owner's side, behind cover,
   so the climb is seen by at most 10 % of the enemy's half.
7. **Ways up and down.** Up: the ramp only. Down: the ramp; hop the curb and drop; or vault the parapet and drop (the vault refuses only
   when something is in the way, not when there's no floor, so it carries you off the deck). No deck is a dead end.
8. **Placement relative to the spawns.** Your own ramp top is about 3.3 s from your spawn and the enemy's about 7.6 s, more than twice as
   far, so it can't be rushed at the start. Each high spot faces the lane held by the enemy's window, so it always has an answer from
   50 studs.
9. **A counter for every high spot:** a window or sill that sees it at range; tall cover inside its view for the attacker; a blind foot
   (parapet edges) or a full-height peek (curb edges); and the owner's ramp to push.

## Window rules for Tacticals
1. **Size.**
   - **Sill 3.4** (low-wall height): crouched behind it you're hidden, standing you shoot over it.
   - **Opening 10 wide x 6.6 high** (3.4 to 10); **lintel 10-12**; **posts 5 wide** (tall cover: peek their edges).
   - Frame 20 long x 3 deep x 12 high. A twin window is 35 long: post, opening, post, opening, post.
   - It's the tallest piece in the map and the landmark of each area.
2. **Vault clearance.** A running vault puts the root 1.8 above the sill (5.2) and the head at about 7.4-7.8, so the lintel at 10 leaves
   2.2 or more. The vault is driven by CFrame, so a lintel can't physically stop it; the clearance is for looks. Sill depth is 3; it must
   be 5 at most, or Space climbs instead of vaulting.
3. **Clear landings.** At least 3.5 of open floor on both sides of every sill, along its whole length, so the vault is never refused (a
   refused vault turns into a climb onto the sill).
4. **Spacing.** Openings at least 5 apart (one post). Nothing taller than 3.4 within 3.5 of a sill face, so the crouch spot and the landing
   stay clear.
5. **What a window looks onto.** Every window looks down a lane at a gap, and at the enemy's high spot about 50 away. A window that looks at
   a wall is wasted. The holder's side of a window must not see the enemy's spawn pocket; the checker samples the eye along every opening and
   fails the plan if it does (it caught two such lines here, now closed by pillars).
6. **Where.** Across the middle (both sides use it) and as lane gates touching the outer wall (one side holds it). A gate always leaves a
   way round its inner end (8.5 wide here), so the vault is a choice, not the only door.

## Taken from RIVALS Arena, changed for Tacticals because ...
| RIVALS Arena | Arena v2 | Because |
|---|---|---|
| Halves are a 180° turn of each other; the left and right flanks differ (ramp flank, window flank), which is why it feels asymmetric | Same jobs on opposite diagonals (perch + gate against gate + ledge), but every piece group has a different shape, the two heights play differently, and fairness is checked by timing (all pairs within 7 %) | Edward asked for "different but fair". A real turn would make the halves identical from each spawn |
| Window frame 20 x 15 x 5, opening 10 x 7 over a 3 sill | 20 x 12 x 3, opening 10 x 6.6 over a **3.4** sill; twin windows 35 long | The sill must be Tacticals' low-wall height (crouch cover). 12 high is above every other piece, the same rule as RIVALS' frames standing above its perch eye. Thinner, because Tacticals' walls are 3 |
| Corner frames close the side lanes except through the window | Twin-window gates close the outer lanes, with an 8.5 gap round the inner end | Vaulting is a real choice in Tacticals (0.34 s, very visible); a second way round keeps a lane from becoming a single door |
| Centre: a canopy on four pillars | Centre: one twin window across the middle | Edward wants big windows. The centre fight becomes sill against sill through two openings |
| Perch 15 up, 45° ramp, no rail | Deck **5** up, **22.6°** ramp, a kick-curb or parapet on every edge | Tacticals' cover is 3.4 / 7 / 10 tall, not 20, so the eye must stay under the pillar tops (deck under 5.4; Edward picked 5). With no jump and a 5.6 climb, a bare edge could be climbed. A gentle ramp keeps sprinting smooth |
| Full cover 20 high, all pieces 5 thick, 5-stud grid | Tacticals' own pieces: pillar 5 x 5 x 10, wall 10 x 3 x 7, low wall 6 x 2 x 3.4; 0.5 grid | Edward: keep Tacticals' cover pieces (the tutorial sizes CoverController is tuned for) |
| Lanes 10 wide, everything 10 apart | Gaps 9-21 studs, all under one cover dash (26) | Tacticals moves cover to cover with E (up to 26 studs at 24/s), so a gap's length is a crossing time, not just a width |
| An end slab hides each start (0.1 % start-to-start sight) | A 20-long shield in front of each pocket (A: two walls; B: pillar-wall-pillar) plus pillars closing the long diagonals (A one, B two); 0 % | Same idea, checked over whole pockets for 3v3 |
| 90 x 130 box, walls 30 | 150 x 110, walls 16, open roof | Edward's footprint and box. 16 is above the highest eye + hop (11.8) |
| Two greys, no accent | White + training grid (Edward's call) | |

## 2v2 and 3v3
- Spawn spots are 4 apart in each pocket (A: (-70, -4 / 0 / 4), B: (70, -1.5 / 2.5 / 6.5)); the spawn checks cover the whole pocket.
- Every advantage spot holds two players: the perch is 12 x 10, the ledge 20 x 8 with two peek ends, and each gate and the centre have two
  openings. With three players a natural split is one per lane, with the height, the gate and the centre each held by one.
- The ramps are 8 wide, so two can pass. Nothing else changes. 150 x 110 is roomy for 1v1 (every spot is 3-4 s from spawn) and right for 3v3.

## Building it (after approval)
- Replace the layout block in `fix/map_arena.lua` with one generated from the JSON (pieces, parts, ramp wedges; world = ORIGIN + (x, z, -y)).
  Keep the grid textures, MapInfo and Lighting, and the MatchSpawns markers (SpawnA at (-70, 0), SpawnB at (70, 2.5), both facing the middle).
- Set `NotCover = true` on the ramps, the box and the curbs (1 high: never cover). Decks and parapets are normal cover.
- Then a fresh lap in Play at player height, measuring the assumptions:
  - every vault, every end-on low-wall climb, both ramps and the drop-offs;
  - **the crouched head height** (must be under 3.4);
  - whether a **2.2 hop plus Roblox's step-up** reaches a 3.4 top or a 5 deck edge, and whether you can stand on a 0.5-deep curb;
  - the gaps timed with a cover dash.
- After the lap, a `roblox-map-grader` round.
- **Construction: Studio Parts** (Edward, 2026-10-26: "yes studio parts"), as v1. That is the "build it in Studio" line the
  Map Building Corrections require. Plain Blocks and Wedges: collision = the visual, axis-aligned, on the 0.5 grid.

## Review (fresh reviewer, 2026-10-26)
Confirmed: every number in the first draft, the spawn line of sight (re-done with exact geometry), and the climb, curb, vault-arc,
parapet-drop and NotCover claims against CoverController.

Fixed after the review:
- The south lane had no B spot watching A's crossing. The south island is now a pillar + low wall, and the ledge's peek spots are at its curb.
- The text said every rotation was watched by the enemy's height. It is watched by the enemy's gate and sill (corrected).
- The B ledge's weaker view is now stated openly.
- "Watched by" is split by team and sampled along each whole gap line.
- Paths use a 16-neighbour grid; an 8-neighbour grid's error of up to 8 % is as large as the 10 % rule.
- Added: named spots against the enemy pocket, the spawn-camp time, landing probes along the whole wall, and drop-offs from the ramp sides.
- Added the end-on low-wall climb check (also reported by the map trainer).

Still assumptions: the crouched head height and the hop + step-up (both are on the Play lap).

**Round 2 (fresh re-check after Edward's answers, deck 5): no blocking issues, 1 major, 7 minor; all fixed.**
- Major: B's own north gate (north opening, B's side) saw a corner of A's pocket, about 100 studs away. The checker had tested one eye
  per sill. Fixed: `A_PocketN_P` moved to (-45, 16) and `A_Mid_W` to (-40.5, 7.5). The checker now samples the eye along every opening and
  fails when the holder's side sees the enemy's pocket. That caught the mirror line from A's south gate, now closed by a second pillar
  on B's side (`B_PocketS_P2`).
- Minor, all fixed:
  - stale 10.8 corrected to 11.8;
  - stale comments in the generator and the checker;
  - wall count in the kit list (plus the wall standing on B's ledge);
  - climb reach from a deck widened to 4.5;
  - standing on the curb noted, and added to the Play lap;
  - the camera claim limited to level pitch;
  - the height sweep is now a script;
  - the missing Centre A watcher added.

## Edward's answers (2026-10-26)
1. **Asymmetry:** yes, as planned (same kinds of spot on opposite lanes, different shapes and strengths, fair by timing).
2. **High-ground height:** 5 ("5 is fine"). Applied: decks 5, ramps 5 over 12 (22.6°); every check re-run at 5 (0 errors, 0 warnings).
3. **Construction:** Studio Parts ("yes studio parts"). No colour change was asked: all white + training grid, as v1.

Next step: build it into `fix/map_arena.lua` from the JSON, then the Play lap and a grader round (see "Building it").
