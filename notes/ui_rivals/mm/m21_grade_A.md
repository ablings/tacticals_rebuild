# m21 grade A: positioning and layout

**Moved away from RIVALS:** no. The map is now the Warehouse, so most frame diffs against m20 are scene changes. The UI chrome in loadout, vote, kill, matchpoint and results is unchanged, so those grades and fixes carry over from m20. The only UI change on this lens is the kill-cam gun. No lobby-side captures, so those grades carry over from m17.

**m20 fix, the kill-cam gun anchored bottom-right near (98 %, 98 %) and drawn under the card words: partly landed.**
- Under the words: **landed.** "eliminated you with Pistol" reads in full in death and death2, and the text draws above the gun. The gun covers the right end of the plate, as RIVALS' gun does in t0212.
- Bottom: **landed.** The grip ends at y 97.8 %, against 97.8 % in t0212, with no clipping at the screen edge.
- Right edge: **missed.** The gun spans x 79.8-93.1 % and y 65.5-97.8 % (13.3 x 32.3 %). RIVALS' gun body in t0212 spans x 83.1-98.1 % (80.6 % counting the paper strip) and y 67.2-97.8 %. Our right edge is about 5 % (96 px) short, and our left edge now sits 3.3 % left of RIVALS' body, inside the card at y 76-81 %. The pose has a ~110 px empty band on the right, so the bounding box isn't sitting on the anchor.
- The card itself sits on t0212: plate x 59.5-94.6 %, y 76.2-88.5 %, against RIVALS' 59.4-94.7 %, 76.1-88.9 %.

**death2 9/10** (t0212)
- Kill-cam gun: shift it about 96 px right, to x 84.8-98 % (1628-1882 px), keeping the bottom at 98 % (1058 px). Equivalently, anchor the gun's projected screen-space bounds, not the model's pivot, at (98 %, 98 %).
- If it's wider after the shift, scale it about 1.1 so the width reaches about 15 % (288 px). That's RIVALS' body width without the paper strip.
- M key: straddle the Switch Weapons right edge at x 56.6-58.3 %. It's still inside the button (x 55.4-57.1 %). Carried over.

**death 9/10** (t0206)
- The same gun shift applies. The arc is settled.

**matchpoint 9.5/10** (t0122)
- Ribbon and its text about 7 px lower, at y 5.3-9.8 %. Carried over.

**loadout 8/10** (t0036)
- Slot row top: 25.7 % → 26.9 %, with even 0.6 % (11 px) gaps. Carried over (0.9 % pixel diff, no UI change).

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5 % → 69.1 %. Hotbar 27 px right (x 81.3-99.4 %). Carried over.

**results 9/10** (t0140)
- Stat labels 87.7 % → 87.1 %. Damage numbers 91.9 % → 90.6 %. Button gap 0.6 % → 0.9 %. Carried over.

**found 9/10** (t0022, no m21 capture)
- Bubble text inset about 10 → 20 px on each side. Carried over.

**vote 9.5/10, countdown / live 9/10, victory: nothing to fix** (the cutscene is settled). **searching 9/10, playmenu settled:** no m21 capture. **Mascot:** none (our game has none).

*Timing (unscored): the 0.0 s death shot already shows ROUND LOST and the killer card, as in m20. Studio slows the short holds about 6x, so the hold lengths aren't judged.*

## Top 8 by visible impact
1. Kill-cam gun about 96 px right, to x 84.8-98 %, bottom kept at 98 % (t0212).
2. Loadout slot row at 26.9 %, with even 0.6 % gaps (t0036).
3. Kill cap at 69.1 %, hotbar 27 px right (t0054).
4. Ribbon and its text about 7 px lower (t0122).
5. M key straddling the Switch Weapons right edge (t0212).
6. Results rows about 1 % higher, with a 0.9 % button gap (t0140).
7. Found bubble text inset 20 px (t0022).
8. Kill-cam gun scaled about 1.1 if it's still narrower than 15 % after the shift (t0212).

Remaining layout gap worth another round: yes
