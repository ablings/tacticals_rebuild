# e8 grade C: interactivity and feel

Sources: the e8 captures and sheet, the code at 1fb5cea, `05_rank_ladder.jpg`, `news_panel.png`, `rv_playermenu.jpg`, rivals_rec t0152-t0156.

**What landed (all three):**
- Ranks: `hold` is AnchorPoint (0.5, 0.5) at (49, 46) (RankedScreen:213), so the 1.1 UIScale lift grows in place over the pillar.
- Player menu: `Menu` sets `_MenuOpen` and 0.94 on the opener row (PlayerCards:499-503). `CloseMenu` clears both (381-382). LobbyHud's MouseLeave keeps 0.94 while the attribute is set (1062). A one-click switch goes through `CloseMenu(true)` first, so the lit state moves to the new row.
- News: the bar is back to 10 px at 0.4 (Notify:270), the same as the inbox (184). One scrollbar style again.

**Still open:** the News and Leaderboard rows don't pop in, the Ranks rules end in a hard cut, Party hover and grid motion are unchanged, inbox rows aren't CanvasGroups, and the blur is still hard-coded 18 (Notify:215, 303).

## ranked: 10/10
No feel fixes left.

## ranks: 9/10 (was 8.5)
1. The rules still end in a hard cut at the modal's bottom. Target: a 24 px UIGradient fade (Transparency 1 -> 0) over the last 24 px of `Rules` (05_rank_ladder).
2. Small: the art's visible 88 px emblem now ends at y 90, and at 1.1 it ends at about 94. That puts it about 4 px under the ELO floor label (y 90, ZIndex 25 above it). Target: lift 1.08, or the label at y 94.

## rankedlb: 7/10 (unchanged)
1. Rows appear all at once. Target: `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.
2. Rows are `UDim2.new(1,-10,0.07,0)` in an automatic canvas (RankedScreen:284/290). Target: a fixed 56 px through toScale, tested with fake rows.

## party: 7/10 (unchanged)
1. Empty-slot hover only scales. Target: also tween BackgroundTransparency 0.35 -> 0.2 (t0155).
2. A tab change or search re-renders with no motion. Target: popIn the first 9 cards 0.03 s apart, and reset `grid.CanvasPosition` to zero on a tab change.

## playercard: 9.5/10 (was 9)
1. `CloseMenu` sets the row to 1 even when the cursor is still on it. This happens when you close by clicking the same row, and the row blinks dark until the next MouseEnter. Target: on close, use 0.94 if `row.GuiState == Enum.GuiState.Hover`, otherwise tween 0.94 -> 1 over 0.1 s.
2. The click-through Y still needs a 2-player test against `GuiService:GetGuiInset()` (rows are 40 px apart).

## inbox: 8/10 (unchanged)
1. popIn scales rows at full opacity. Target: CanvasGroup rows, GroupTransparency 1 -> 0 during the pop.
2. The blur is hard-coded 18 (Notify:215). Target: `Theme.blur`.

## news: 8.5/10 (was 8)
1. All blocks appear at once. Target: `Kit.popIn` per block 0.05 s apart, after a 0.15 s hero fade (the inbox's stagger at Notify:197-201).
2. The blur is hard-coded 18 (Notify:303). Target: `Theme.blur`.

## Top 8
1. News: the blocks stagger in after a hero fade.
2. Leaderboard: the rows stagger in at a fixed 56 px height.
3. Ranks: a 24 px fade at the bottom of the rules.
4. Party: empty slots brighten on hover; the grid pops in and resets its scroll on a tab change.
5. Inbox: CanvasGroup rows for a real fade-in.
6. Player menu: a soft row un-light on close, plus the 2-player click-through Y test.
7. `Theme.blur` in the inbox and News.
8. Ranks: keep the hover lift clear of the ELO label (1.08, or the label at y 94).

Remaining gap worth another round: yes
