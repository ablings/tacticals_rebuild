# Extra lobby menus: grader brief (shared by the 3 graders)

The task: make our Roblox game's (Tacticals) secondary lobby menus look, sit and feel like RIVALS. Our palette is
deliberate (dark plates, tan / field-green accents); judge layout, proportions, typography, hierarchy, icons, missing pieces,
motion and finish, not colours. Scissors is our currency.

## Our captures (this round)
`C:\Users\aroki\Documents\tacticals_rebuild\notes\ui_rivals\menus\<round>_<menu>.png`, 1268x713 (16:9). Give pixel fixes in
1920x1080 DESIGN px (capture px x 1.514). `<round>_sheet.jpg` is a contact sheet.

| Menu | What it is |
|---|---|
| ranked | Play > Ranked: our ranked screen (placements state) |
| ranks | Ranked > Ranks: the rank ladder + rules |
| rankedlb | Ranked > Leaderboard (Warlord top 200, empty in Studio) |
| party | the party / invite screen |
| playercard | clicking yourself in the player list: the small player menu |
| inbox | the inbox (top-right corner menu > Inbox) |
| news | the news panel (corner menu > News) |

## RIVALS references (under `C:\Users\aroki\Documents\tacticals_rebuild\notes\`)
- Ranked: `ref_rivals_ranked\` (01 play-menu ranked tile, 02 ranked screen, 03 contract, 04 payout, 05 rank ladder, 06-08 rules).
- Player menu / profile: `ui_rivals\night1\kuroko169\rv_playermenu.jpg`, `rv_profile_streak.jpg`, `ui_rivals\rivals_normal\profile_card.png`.
- News: `ui_rivals\rivals_normal\news_panel.png`.
- Party / player list: `rivals_rec\tNNNN.Ns.jpg` around 150-165 s (player list); `ui_rivals\feel\rivals\` (playerlist, nameplate).
- Inbox: RIVALS has no inbox; judge it against its panel family (news_panel, tasks).
- If a reference doesn't exist for a menu, say so and judge against the closest RIVALS panel; don't invent one.

## Code (for the feel lens, read-only)
`ui\ranked\RankedScreen.lua`, `ui\hud\PartyScreen.lua`, `ui\hud\PlayerCards.lua`, `ui\hud\Notify.lua` (inbox), the news code
in `ui\hud\LobbyHudController.lua`, kits `ui\rivals\Kit.lua`, `ui\lobby\Kit.lua`.

## Settled
No gloss / sheen overlays (house rule). The Leaderboard is empty in Studio (no players), so judge its frame, not its content.

## Report
Write `menus\<round>_grade_<LETTER>.md`, under 500 words: per menu a score /10 on your lens and at most 3 concrete fixes
(element, current -> target, design px, the RIVALS frame used); then the top 8 across menus. End with
"Remaining gap worth another round: yes/no". Edit no other file.
