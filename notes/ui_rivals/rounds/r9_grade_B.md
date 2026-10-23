# r9 grade B: typography, readability, icons

All sizes are capture px from pixel bounding boxes (dp = ×1.51). c = digit cap height. [#n] = impact rank.

## Moved away from RIVALS
- **Kit counter grew too.** The 1.1 also hit the Kit counter: glyph 30×31 → 33×35, digits still 15 cap. Hub is now 29×31 / 13 and Shop 30×30 / 13, so Kit is the odd one out by 3–5 px.
- **Kit Contracts icon.** It's the same blank starburst as "Reward at Level 5" (20×20 both). In RIVALS (kuroko169 kit.jpg) Contracts has its own weapon-and-hand glyph.

## Landed
- **One tag spec.** Shop glyph 17×17 in a 35 tag (0.49), Kit 15×16 in 32 (0.50). They now match. Pass.
- **White tag glyph.** The colour is right, but it reads ghosted: thin white strokes (~1 px core) inside a gold edge, mean colour (191,179,104) on yellow. The digits beside it read clearly. The RIVALS key (t0055 "425", t0068 "5") is a solid, chunky white shape.
- **Hub counter.** 29×31 glyph, 13 cap. Pass (t0135 key ≈ 32 / 14).
- **Codes input.** Light fill (231) with grey placeholder (136, 2.9:1). This matches the white Settings value boxes. Pass.
- **Settings version.** 9 px tall, inset 9 / 10 px. Size and placement match t0139. Content and brightness don't (see below).

## Shop: 7.5/10 (+0.5)
- [#1] Tag glyph: thicken the strokes so the blades are ≥3 px and the handle rings are filled solid. Use the digits' own dark-gold outline (same width), not a separate thin edge (t0055).
- [#6] Pack art: flat counter-glyph stack (unchanged from r8).

## Kit: 7/10 (−0.5)
- [#2] Counter 33×35 / 15 cap → 30×30 / 13, the same as the Hub and Shop. Use one shared component scale, not per screen.
- [#3] Contracts icon: starburst → its own weapon silhouette (the claw used in Missions contracts would also do). It must differ from the Reward row.
- [#7] Action-row titles 11 cap vs "Level up now!" 9 (1.22) → 9–10. RIVALS' Contracts title is ≤ the Level row's (kit.jpg).
- [#10] Slot labels grey → #FFFFFF.

## Hub: 8/10 (+0.5)
- [#5] Widget ×N 36–42 px wide vs a 25 px glyph → glyph 30 or ×N cap 10 (tasks.png). Unchanged.
- [#12] Dock labels → #FFFFFF.

## Codes: 7.5/10 (+0.5)
- [#4] Disabled Redeem: white text on light green is 2.3:1 and still reads as enabled. Either grey the fill (~#4A4A4A, text 60%), or keep the green and add the dark-green text stroke that RIVALS' VIEW/Play buttons use (t0055).
- [#11] Subtitle 12 vs title 15 (0.8) → 10 (0.65); gift 36 → 42 dp.

## Settings: 7.5/10, unchanged
- [#8] Hierarchy is inverted. Row label cap 20 = description title 20. In RIVALS (t0139) the row is 16 and the title 23. Target: rows 20 → 16, title 20 → 23.
- [#9] Version "v0" → "Version N · uptime" format; text brightness +126 over the panel → about +60 (TextTransparency ≈ 0.5), as in t0139.

## Missions: 8.5/10, unchanged
- [#13] Streak glyph 35 → 40; card ×N tuck 3 px over the foot (still touching at y 364/365).

## Play: 8/10, unchanged
- [#14] Shield 1.45 → 2.5 c.

## Ranked
1. Tag glyph: thick, solid white, digit-matched outline (Shop + Kit)
2. Kit counter back to 30 / 13 (it regressed); one shared counter scale
3. Kit Contracts: its own icon, not the reward starburst
4. Codes disabled Redeem: readable disabled state
5. Hub widget glyph vs ×N
6. Pack art flat glyph stack
7. Kit action-row title size
8. Settings row 16 / description title 23
9. Settings version text and dimming
10. Kit slot labels white
11. Codes subtitle / gift
12. Dock labels white
13. Missions streak glyph / ×N tuck
14. Play shield
