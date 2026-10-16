# N / S gate corridors (airlock bulkheads): fresh-eyes review (2026-10-16 night)

Reviewer: a different agent from the builder (the hub pass agent, before its own work). Studio 8ef4e21a only; nothing saved.
Captures: `out/polish/gates/rv_*.png` (the 10 cameras of `tools/polish_gates_capture.py`), contact sheet `out/polish/gates/rv_contact.jpg`.

## Logic
- `check_polish_gates`: 0 clips (64 probes), support bad 0, clearance with vs without polish identical (N 7.86 / 9.54 body / height
  12.11; S 8.17 / 9.80 / 12.11), SHOP sign OUTFITTERS, ARMORY unchanged, 0 new lights (99 enabled in Edit), 0 new collidable parts,
  Shop_Counter / GunWall_Kit / Armory_Dais prompts enabled, 4 walk routes clear.
- Corridor collision measured on its own (rays with RespectCanCollide, y 1-6): 9.60 wide at the ribs in both corridors.

## Clear bug, fixed (`fix/polish_gates2.lua`, UNDO-able)
1. **The N corridor junction box was walk-through.** `IndustrialProps.F_JunctionBox` (west wall, z 54, y 5.0-8.2, a features-kit
   prop) is non-colliding and stands 0.69 off the wall plate, 0.34 past the bulkhead ribs, so a player hugging the wall walked
   through a solid-looking box at shoulder height. It is a simple standalone model, but there is no flat spot in the corridor
   wall it fits (wall plate / recess / trim ledge / band / trim / door leaf bands are 0.5-2.5 tall; the box is 3.2), and moving it
   out of the corridor loses the dressing. Its body and lid trim now collide (Box hull, NotCover): collidable width there 9.54,
   the corridor minimum elsewhere 9.60. Nothing else changed. UNDO round trip tested (restore -> re-apply).

## Taste (not bugs; left for Edward / the lead)
2. The hub-side gate heads carry the hub's olive band, which reads lime from the hub (`rv_Nhub`, `rv_Nsign`): the hub pass
   (`fix/polish_olive.lua`) retunes it.
3. The two corridors are identical up to the last bay; that is the design (airlocks), and the destination bay + doorway frame
   preview each room well from the hub mouth (cream Shop, gunmetal Armory).
4. The status lights are small (1 stud) and sit above eye level; they read as dots from the hub. Fine as detail; bigger lenses
   would read as "go" from the hub if Edward wants a stronger cue.
5. The hazard sills read busy at the hub end (`rv_Nwall`: zebra stripes next to the cream floor lines). Acceptable at walking
   speed; a narrower stripe tile (3 x 1) would calm it.
6. The F_Intercom units at the hub mouths (x +-5.18, z +-47.5) are non-colliding too but sit within the gate reveal (0.4 deep, inside
   the 10.8 mouth), so nobody walks into them. Left.
