# e1 grade B: LOOK (typography, panel finish, icons, readability, hierarchy)

All px = 1920x1080 design px (capture x 1.514).

**ranked 6/10** (ref 02_ranked_screen)
1. Mode-tile title "Ranked / 1v1": the text is drawn over the figure art and is hard to read. Target: 66 px two-line title centred in the tile (ref), and push the figures back with a dark bottom-to-top tile gradient so the text sits on a calm area.
2. ELO bar: the ends are empty. Target: a 64 px rank badge at each end, with "200 / Bronze 2" at 28/24 px stacked on the inside (ref). In placements, show "? / Placement" there. The second `?` diamond (left, 52 px) repeats the header badge: remove it.
3. Header subtitle at 23 px is too faint. Target: 26 px at 85% white. The "Placement match" strip is centred bold at 23 px: raise it to 30 px and add 40 px shield icons on both sides (ref 02).

**ranks 5/10** (ref 05_rank_ladder)
1. Tier name pills: black 17 px text on bright fills, and "Commander" spills out of its pill. Target: drop the pills and use RIVALS rising podium bars (width 108, height 120 -> 360 px in even steps, tier colour) with the italic threshold (32 px) above and the tier name (20 px italic) at the base.
2. Hierarchy: there is only one title. Target: 52 px "Ranked" title plus a left-aligned 34 px "Ranks" section head (ref).
3. Rules body at 23 px, tight 54 px leading. Target: 28 px, full-width bullets, scroll with a 6 px right scrollbar like ref.

**rankedlb 5/10** (no RIVALS LB ref in folder; judged against 05 modal)
1. There is no column header. Target: a 36 px header row "# / Player / ELO" at 22 px, 60% white.
2. Empty state is bare text. Target: a 96 px Warlord crest above the text, with the text at 30 px.
3. A full-height scrollbar shows on empty content. Hide it when nothing scrolls.

**party 4/10** (ref feel/rivals/playerlist)
1. Empty slots: "+ Invite" at 20 px, roughly 40% white on 10% plates, so they read as disabled. Target: 26 px, 80% white, a 32 px plus icon, and a 2 px 25% outline.
2. Own row: name 21 px / @handle 15 px. Target: name 26 px, handle 19 px, plus a device icon after the name like the playerlist.
3. The "Invite" tooltip is a cream box floating at x 1222, y 920, detached from everything. Anchor it to the hovered slot, or drop it.

**playercard 6/10** (ref rv_playermenu)
1. Row labels are 17 px. Target: 22 px, rows 54 px tall with 6 px gaps between them (ref).
2. Row icons: target 34 px white glyphs right-aligned at 20 px padding. Ours are fine, but on other players the card needs ref's colour-per-action rows (green Add Friend, purple Gift, red Block).
3. Header: target 30 px name and 64 px avatar.

**inbox 6/10** (no ref; judged against news_panel / tasks family)
1. Header: the title is left-aligned but the 2-line subtitle is centred. Left-align the subtitle under the title at 22 px.
2. The "1m ago" chip floats outside the card (x 424). Move it inside the card at the top right, 18 px.
3. Reward: the "x50" at 24 px collides with the scissor icon. Target: icon 48 px, "x50" 26 px beneath it with 4 px of clearance.

**news 4/10** (ref news_panel)
1. Structure: RIVALS news is a hero image (832x468 in ref) plus a right-aligned "UPDATE 24" (40 px) plus left-aligned headed bullet body. Ours is a stack of pills. Target: a hero image at the top and our entries as 40 px headings with 26 px bullets below.
2. Row 1's description overflows the pill edge. Text must wrap inside 24 px padding.
3. News reuses Inbox's megaphone, and the same book icon appears on every row. Give News its own icon, and give each entry its own icon or none. Add the blue next-page arrow (ref) under the X.

## Top 8
1. News: hero image plus heading/bullet body (news 1).
2. Ranks: podium ladder instead of black-on-colour pills (ranks 1).
3. Ranked tiles: keep the titles readable over the art (ranked 1).
4. Party empty slots: legible invite plates (party 1).
5. ELO bar end badges and labels; remove the duplicate `?` badge (ranked 2).
6. Body text min 26-28 px across Ranks, Party and the player card (ranks 3, party 2, playercard 1).
7. News row text overflow (news 2).
8. Inbox/News header alignment and per-menu icons (inbox 1, news 3).

Remaining gap worth another round: yes
