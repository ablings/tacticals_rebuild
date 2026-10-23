# e9 grade C: interactivity and feel

Sources: the e9 captures and sheet, the code at 4dbe65e, `05_rank_ladder.jpg`, `news_panel.png`, `rv_playermenu.jpg`, rivals_rec t0152-t0156.

**What landed (all three):**
- News: the blocks are CanvasGroups at GroupTransparency 1 (Notify:278). After `Kit.open`, the hero fades over 0.15 s and each block fades in at 0.15 + (order-1)*0.05 s over 0.2 s (Notify:307-318). The last block is in by about 0.55 s.
- Ranks: a 24 px black UIGradient fade (1 -> 0) now sits at y 593-617 over the rules, x 30-842, clear of the scrollbar (RankedScreen:249-251). The e9_ranks capture shows the third rule line fading out.
- Player menu: clicking the same row now calls `CloseMenu()` and sets the row back to 0.94 (PlayerCards:445-447), so the row no longer blinks.

**Still open:** the Leaderboard rows don't pop in, Party hover and grid motion are unchanged, inbox rows aren't CanvasGroups, and the blur is still hard-coded 18 (Notify:215, 304) while `Theme.blur` is 24.

## ranked: 10/10
No feel fixes left.

## ranks: 9.5/10 (was 9)
1. Scrolled to the end, the last rule still sits under the fade. Target: a `UIPadding` with PaddingBottom 24 on `Rules`, so the last line can scroll clear of it (05).
2. The fade is opaque black, but the panel is BLACK at 0.08. That is near enough now. If the panel transparency changes, match the fade to it.

## rankedlb: 7/10 (unchanged)
1. Rows appear all at once. Target: `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.
2. Rows are `UDim2.new(1,-10,0.07,0)` in an automatic canvas. Target: a fixed 56 px through toScale, tested with fake rows.

## party: 7/10 (unchanged)
1. Empty-slot hover only scales. Target: also tween BackgroundTransparency 0.35 -> 0.2 (t0155).
2. A tab change or search re-renders with no motion. Target: popIn the first 9 cards 0.03 s apart, and reset `grid.CanvasPosition` to zero on a tab change.

## playercard: 9.5/10 (unchanged)
1. A close by clicking empty space still snaps the row from 0.94 to 1. Target: tween it over 0.1 s in `CloseMenu`.
2. The click-through Y still needs a 2-player test against `GuiService:GetGuiInset()` (rows are 40 px apart).

## inbox: 8/10 (unchanged)
1. popIn scales the rows at full opacity. Target: CanvasGroup rows, GroupTransparency 1 -> 0 during the pop (the same thing News now does).
2. The age chip is a sibling with its own centre anchor (Notify:198), so during the pop it scales around (745, y+51), not the row's centre, and drifts against the row. Target: parent the chip to the row at (686, 31).
3. The blur is hard-coded 18 (Notify:215). Target: `Theme.blur`.

## news: 9.5/10 (was 8.5)
1. Only `ImageTransparency` fades, so the hero's black `BackgroundColor3` shows as a black box for the first 0.15 s. Target: also tween BackgroundTransparency 1 -> 0, or set the background to 1.
2. The blur is hard-coded 18 (Notify:304). Target: `Theme.blur`.

## Top 8
1. Leaderboard: the rows stagger in at a fixed 56 px height.
2. Party: empty slots brighten on hover; the grid pops in and resets its scroll on a tab change.
3. Inbox: CanvasGroup rows for a real fade-in, with the chip parented to its row.
4. `Theme.blur` in the inbox and News (18 -> 24).
5. Ranks: 24 px of bottom padding on the rules, so the last line can clear the fade.
6. News: the hero background fades with its image.
7. Player menu: a 0.1 s un-light on a click-outside close.
8. Player menu: the 2-player click-through Y test.

Remaining gap worth another round: yes
