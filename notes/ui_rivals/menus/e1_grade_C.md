# e1 grade C: interactivity and feel

Sources: code listed in the brief, plus RIVALS frames t0285.4-t0286 (Ranked opens), t0155-t0156 (tile hover, scrollbar), `05_rank_ladder.jpg`, `rv_playermenu.jpg`, `news_panel.png`.

## ranked: 8/10
Cards pop in one after another, the bar fills, ELO counts up, PLAY squads hop on hover. Good.
1. Mode card hover 1.02 -> 1.05. RIVALS tiles grow about 8-10% (t0155.3 vs t0156.6).
2. Shade on popups (`popup()`): it appears at 0.35 in one frame -> tween it from 1 to 0.35 over 0.2 s while the panel pops. RIVALS fades its dim in about 0.6 s (t0285.4 -> t0286).

## ranks: 6/10
1. **Likely bug:** the panel `p` is a plain Frame inside the `shade` TextButton, so a click on the panel body can pass through and close it. Set `p.Active = true` (or put a sinking TextButton under the panel). Check it by clicking the rules text.
2. The ladder and rules are fixed -> one ScrollingFrame (1220 x 620 at 40,110) with a white bar 10 px thick. RIVALS' Ranked popup scrolls, with a visible white thumb (05_rank_ladder).
3. Emblems are static -> hover grows them 1.06 (bindButton silent:false on each column).

## rankedlb: 6/10
1. Rows are added all at once -> `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.
2. Scrollbar 6 px with the default colour -> 10 px, white, `ScrollBarImageTransparency` 0.2 (05_rank_ladder).
3. Same pass-through close risk as ranks.

## party: 6/10
1. The empty `+ Invite` slots have no bindButton, so they are dead on hover -> `Kit.bindButton(slot, {hover = 1.03})`, and the fill goes from 0.6 to 0.4 on hover.
2. A tab switch or a search key rebuilds the grid with no motion -> popIn the cards (0.03 s stagger, first 9), and keep the grid's CanvasPosition at 0 on a tab change.
3. The grid scrollbar is 6 px -> 10 px (t0155 thumb).

## playercard: 7/10
Slide-in, staggered rows and the instant white row hover match t0110/t0111.
1. It opens and closes with no sound (uses tweens, not Kit.open) -> `Kit.sfx("open")` in `Menu`, and `Kit.sfx("close")` in `CloseMenu`.
2. The clicked player-list row isn't held -> keep it highlighted while the menu is open (rv_playermenu: the "debits" row stays tinted).
3. Profile buttons under the card (X / Invite / 1v1) don't pop with the card, and on close they vanish in one frame -> popIn them with a 0.05 s delay, and Kit.close them with the card.

## inbox: 6/10
1. A click outside does nothing (`Dim` is a Frame) -> make it a TextButton that calls CloseInbox, like the ranked shade and the profile tint.
2. The dim appears at 0.45 in one frame -> tween it from 1 to 0.45 over 0.2 s. Blur is hard-coded to 18 -> use `Theme.blur`.
3. Rows are popped in as Frames, so they show at full opacity while scaling -> make them CanvasGroups, or fade in their text, so the pop reads.

## news: 4/10
This is the inbox code with a new label, so there is nothing to interact with. RIVALS' news is one scrolling article (hero 832 x 468) with a blue arrow under the X that pages to the next update (news_panel.png).
1. Add the blue arrow button (66 x 36 at X's x, 8 px below the X), which pages the updates with a 0.15 s slide.
2. Turn the body into a ScrollingFrame with a 10 px thumb (news_panel: thin bar beside the panel at 1384,120).
3. Remove the hidden time chips instead of leaving empty gaps.

## Top 8
1. Ranks / Leaderboard: the panel may close on its own click (`p.Active = true`).
2. News: arrow paging + a scrolling article.
3. Inbox / News: click outside closes; the dim fades in.
4. Ranked popups: the shade fades in, not a hard cut.
5. Player menu: open and close sounds; the clicked list row stays highlighted.
6. One scrollbar spec everywhere: 10 px, white, 0.2 transparency (ranks rules, leaderboard, party grid, inbox).
7. Party: empty slots react to hover; the grid pops in on tab switch and search.
8. Ranked mode card hover 1.02 -> 1.05; leaderboard rows stagger in.

Remaining gap worth another round: yes
