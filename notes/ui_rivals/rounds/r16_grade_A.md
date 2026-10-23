# r16 grade A: positioning and layout

**Method.** I pixel-diffed r15 against r16 in every section. Captures are 1268x713, and design px = capture px × 1.514. RIVALS frames are 1280x720, so I multiply them by 0.991 to compare. References: `rivals_rec` t0058 (Kit), t0068/t0070 (Shop), t0136 (Settings), t0177 (hub), and `rivals_normal/tasks.png`. Settled items I don't grade: the Play grid top (y 306), gloss, and the Kit row layout.

**Moved away from RIVALS:** nothing.

**Did the r15 fixes land?**
- **Settings header bars: LANDED.** Performance spans y 106–152 and Camera 291–337. That is 47 px, or 71 design px (it was 58 px). The text is centred within 1 px: Performance glyphs at 117–139 have their centre at 128, and the bar centre is 129. Everything below moved up 11 px, so the Horizontal slider now fits in the frame.
- **Shop special-offer banner: LANDED.** The frame runs x 211–704 with its top at 486 (it was 218–711, top 498). t0070 ×0.991 gives 210–704 with the top at 403. The gap to the right grid's top (497) is 11 px, the same as t0070 (11 px). Banner height is 213 px against RIVALS' 212 (×0.991). Note: my r15 target of 218 → 211 was set on unscaled numbers, and the scaled result matches.
- **Still open from r15:** Kit gaps, Shop right grid and X, Codes alignment, hub dock discs and Missions day circles. Their pixels are unchanged. The other diffs are background, mission names and the Kit render.

## Hub: 9.5/10
1. Dock disc tops: 627 → 634 px (0.879 → 0.889H, t0177).

## Play: 9.5/10
Settled. No fix needed.

## Kit: 9/10
1. Dotted rule to "Pistol": 31 → 46 px. Move Pistol from y 455 to 470 and push the list down by the same amount (t0058: 466→512).
2. "Pistol" to the first list row: 43 → 49 px (t0058: 512→562).
3. Right block from the level bar down: 4 px lower (bar at 466 → 470, rows at 585/626/667 → 589/630/671; t0058 Statistics bottom at 0.975H).

## Missions: 9.5/10
1. Day circles: 60 → 56 px diameter. Keep the 71.5 px step (tasks.png).

## Shop: 9.5/10
1. Carousel slide misaligned in the capture: the Operator KIT slide spans 249–704, and a 23 px strip of the previous slide sits at 211–234 (its green View edge is at 211–218). If the capture caught the slide mid-tween, recapture once it settles. If the slide is at rest, set its left edge to 211 so it fills the frame. t0070 shows a single slide filling 210–704.
2. Right grid: start x 761 → 738 px, tile 80 → 83 px, step 99 → 106 px (t0070: 745/853/960 ×0.991).
3. Pager dots: these sit at y ~709, 10 px under the banner, and the frame bottom clips them. t0070 has them 19 px below the banner (621 → 640) and fully visible. Move them to ~718 and make sure the scroll content leaves room for them.
4. Close X: 50x32 → 57x29 px. Counter y: 35 → 40 px (t0068).

## Codes: 9/10
1. Panel left: 361 → 351 px, to line up with Missions (351–898). The X moves from 932 to 923 with it.
2. Content inset: 19 → 28 px, the same as Missions.

## Settings: 10/10 (Video page)
The header bars now hug the text, and the tab bar, X, panel widths, 25 px sub-row indent and 92 px slider step still match t0136. Header-bar height itself can't be judged against RIVALS, because t0136 and kuroko169/settings.jpg have no such bars. 71 design px is a tidy fit.

## Ranked by visible impact
1. Shop: carousel slide misaligned (recapture or fix at rest)
2. Kit: dotted rule to selected gap (+15 px) and selected to list gap (+6 px)
3. Shop: right grid start, tile and step
4. Codes: line up with Missions and match the inset
5. Shop: pager dots clipped
6. Shop: X size and counter y
7. Kit: right block 4 px down
8. Hub: dock discs 7 px down
9. Missions: day circles 60 → 56

Remaining layout gap worth another round: yes
