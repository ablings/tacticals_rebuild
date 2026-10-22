# r0 grade A: layout and proportion

**Method.** Our 1268x785 captures put the menus in a centred 16:9 frame, with a 36 px band above and below. y is measured inside that frame (y' = (y-36)/713); x is a fraction of the screen width. Design px = x·1920 or y·1080. Measured this way, most panels already match RIVALS to within ±0.01.

## Hub: 9/10
1. Daily Missions progress bars: 0.005 → 0.008H thick (5 → 8 px). Everything else already matches.

## Play: 9/10
1. Close X left edge: 0.872 → 0.887W (1674 → 1703 px). Gap to Ranked: 0.006 → 0.021W. The grid already matches.

## Kit: 7/10
1. Anchor the side panels and action bar to the screen bottom, not to the frame. On our capture they float 36 px up (right panel ends at 0.926, labels at 0.918 of the screen). RIVALS: 0.975 and 0.96, also on its 1.90:1 capture.
2. Action-bar step: 0.073 → 0.063W (140 → 121 px). Bar: 0.338–0.662 → 0.355–0.645W for 4 slots.
3. Selected-weapon slot: header-to-row gap 0.075 → 0.10H (81 → 108 px). Label centred at x 0.094W. Icon 0.13–0.17W wide and 0.10H tall, overlapping the end of the label. First list row: 0.70 → 0.735H.
4. Viewmodel: centre 0.53 → 0.45W, top 0.09 → 0.15H.

## Missions: 6/10
1. The Daily panel ends at 0.527H. RIVALS ends at 0.685H with a 7-day streak row: circles 0.045W (86 px), step 0.056W from x 0.335W, centred at y 0.615H.
2. Contracts top: 0.553 → 0.70H. Let the list run to the screen bottom and scroll. Ours stops at 0.83H, which leaves 0.17H empty.
3. Close X: x 0.715 → 0.733W, width 0.058 → 0.049W (111 → 94 px).

## Shop: 8/10
1. The tab row is left-aligned to the content (0.172–0.692W). Both RIVALS references centre it on x 0.495. Start the row at 0.235W (451 px). Optional, from Edward's recording: tabs 0.082W wide, step 0.09W, row 0.198–0.795W.

The content blocks and tiles already match.

## Codes: 6/10 (vs Tasks / Free rewards)
1. Panel: 0.25–0.75 → 0.285–0.715W (547–1373 px). Top: 0.278 → 0.19H (300 → 205 px), anchored to the top rather than centred.
2. Input width: 0.34 → 0.28W. Redeem width: 0.122 → 0.107W. Height of both: 0.078 → 0.063H (84 → 68 px).
3. Close X gap: 0.006 → 0.02W (12 → 38 px).

## Settings: 8.5/10
1. Tab step: 0.0655 → 0.0725W (126 → 139 px). Bar right edge: 0.561 → 0.60W. Selected pill: 0.061 → 0.071W.
2. Tab icons: 0.077 → 0.056H (83 → 60 px), top at 0.06H. Ours stick up 0.04H above the bar.

Everything else already matches to within ±0.005. Can't judge the section-header bars: there is no RIVALS Video-tab capture.

## Ranked by visible impact
1. Missions: streak row, and contracts running to the bottom
2. Kit: panels anchored to the screen bottom
3. Codes: panel width and top
4. Shop: centred tab row
5. Kit: action-bar step
6. Settings: tab step and icon size
7. Kit: selected-weapon slot
8. Close-X gap (Play, Missions, Codes)
9. Kit: viewmodel position
10. Hub: progress-bar thickness
