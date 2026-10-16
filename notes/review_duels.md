# Duels (arena deck): fresh-eyes review (2026-10-16 night)

Reviewer: a different agent from the builder. Studio 8ef4e21a only; nothing saved. Captures: `out/polish/duels/rv_*.png`
(the 8 standard cameras of `tools/polish_duels_capture.py`), contact sheets `out/polish/duels/rv_contact.jpg` (door, stairs,
pad1v1, pad2v2) and `rv_contact2.jpg` (pad3v3, back, energy, high).

## Logic (all pass, so no fix script)
- `check_polish_duels`: 0 clips (52 probes, 173 new parts); support: one lane segment 0.002 into a raised plate (known, top still
  0.058 proud, no z-fight); hooks: 6 pads ok; 0 new collidable parts, 0 new lights, 99 enabled lights in Edit; walk paths clear;
  PadBoards patched (cream/olive).
- Play walk: hub -> stairs -> Duels door (-98.4,19.0,-0.7) -> south pads (-121,-20) -> energy-wall gap -> west deck
  (-168.1,19.0,0.2) -> north pads (-114,26) -> back down to the hub (-65,2.6,0): all reached, no pit return.
- Console in Play: baseline only (MatchmakingManager MemoryStore, AssetCheck 1/1154 texture, UIBlox FoundationProvider warnings,
  ProfileService offline).
- The dark slab at the right of the pad1v1 view is the door wall's kick (`D_Walls__wall_kick`, camera ray), not a stray part.
- Signage is consistent: mode plates name PAD 01 / PAD 02 per mode, the briefing board faces the door, EXIT · HUB faces into the hall.

## Findings, prioritised (taste; none is a bug)
1. **Lane lines are the brightest thing in the room.** `Polish.Duels.Lanes` are full cream Neon 236,232,218 (0.25 wide); they render
   clipped white and out-shine the pad frames, so the eye follows the aisle instead of landing on the pads. The style guide sets lane
   Neon at about 180,177,166 (RIVALS keeps lane Neon mid-value). Dropping the lanes to ~170 would hand the lead back to the pads.
2. **Team B's olive frame reads lime green under the lamps** (Neon 90,106,42 next to the light shafts, pad2v2/pad3v3 views). It is
   distinct from cream, which is the point, but it is the one saturated green in a charcoal room. Try ~78,92,38 or a thinner frame.
3. **Team A cream frames + cream lanes + white chevrons all share one value**, so from the door (rv_door) the A pads merge with the
   aisle graphics. Point 1 fixes most of this.
4. **The mode plates are small and high** (hung under the rig, angled): from the aisle they read as tags, and the big Holo boards
   ("1V1 0/1 0/1") carry the mode instead. Fine in Play (PadBoards replaces the Holo boards), but the plates could be 1.5x.
5. **ARENA DECK board text is tiny from the door** (two lines under the title are unreadable at 40 studs). Keep only the title and
   "STEP ON A PLATE TO QUEUE".
6. Good: the light shafts and lamp pools sell the arena mood with zero new lights; the pits now read as real openings with the
   cream/near-black hazard rims; the room is clearly different from the cream Shop and the gunmetal Armory.

## Not touched
Nothing changed in Duels. The Holo `Beam` question stays open for Edward.
