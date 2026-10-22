# 06 Leaderboards: in-world boards + corner player list (RIVALS feel audit, 2026-10-21)

Source note: `ui/pseudolobby/hub/LeaderboardScreen.lua` is **not in `ui/deploy_ui.py`**: it is a snapshot from
`ui/pseudolobby/snapshot_hub.py` (Studio-only source); edit in Studio, then re-snapshot. Board data: `scripts/pseudolobby/server/LobbyLeaderboard.lua` -> `ReplicatedStorage.LobbyTopWins` (wins only, top 10).

## What RIVALS does
- **Interactable, boards:** four chunky icon tabs under each board (flame / elims / trophy / level) switch the category; the board
  also cycles itself (Win Streaks t0193 -> Most Eliminations t0205-t0211 -> Most Wins t0215 -> Highest Level t0219-t0225) and the
  list scrolls through to #100 (t0205 shows #11-16, t0225 #81-85). A red **LIVE** tag sits on the title (t0193, t0273).
- **Clean, boards:** one category per board, big title, #1 is a hero row (large avatar, big name, big stat badge, t0211/t0215/t0219),
  then even rows: rank, avatar, display name, @user, stat badge on the right.
- **Kid-friendly, boards:** the icon tells you the category without reading (flame, trophy, burst); titles are 2 plain words.
- **Player list (t0166, t0193, t0247, t0270, crop `plist`):** compact translucent black panel under the gear, 1 row = name + device
  icon + one big number; your own row carries your badge; X to hide and a column-icon button top right. Duel invites
  ("VS / Join") stack right under the list (t0193), so the list is also the social hub.

## Gap table
| Our element | RIVALS behaviour | Quality | Sev |
|---|---|---|---|
| Hub board: 1 category (wins), top 10, no tabs | 4 icon tabs + auto-cycle + scroll to #100 | Interact. | P1 |
| Hub board: #1 is only a stroke + yellow "#1" | #1 hero row, large avatar + badge | Clean / Kid | P1 |
| Board stat is text "12 WINS" | Icon badge with the number | Kid | P2 |
| Board font GothamSSm, grey-blue panels | (our look) Montserrat Heavy / Rubik, olive + cream | Clean | P2 |
| Board numbers snap on `value.Changed` | LIVE tag; lists move | Interact. | P2 |
| Board has no "you" | (not seen) your own rank line | Kid | P3 |
| Player list rows rebuilt by destroy/recreate, no motion | rows steady; feels live | Interact. | P2 |
| Row hover = 3% tint only | (we want) lift/grow per brief | Interact. | P2 |
| Own row not marked | own row shows badge, easy to find | Kid | P2 |
| Mode / X buttons: no `Kit.bindButton` | everything reacts | Interact. | P2 |

## Ranked changes
1. **Category tabs + auto-cycle on the hub board.** Add 4 tab buttons (Wins / Streak / Kills / Level; icons `Kit.ICONS.trophy/streak/level`
   + a kills glyph) in `LeaderboardScreen.lua` (row build loop L24-38); cycle every ~8 s, pause 20 s after a tab is clicked; slide/
   fade the rows on switch. Needs server: `LobbyLeaderboard.lua` publishes `LobbyTopStreak/Kills/Level` (PublicStats already exposes
   WinStreak, StatKills, Level). **L**. Kit: none (SurfaceGui). Look: tabs in field-green gradient on olive, cream icons.
2. **#1 hero row.** Row 1 spans full width at ~1.6x height, avatar 2x, name in Montserrat Heavy, stat badge large; rows 2-10 a
   single column below with a ScrollingFrame for more. `LeaderboardScreen.lua` L24-38. **M**. Look: cream name, green ring.
3. **Restyle board to our tokens.** Replace GothamSSm with `Theme.font.display` / Rubik, the grey-blue `#1A1E26` gradient with the
   olive lobby panel, keep `#FFD400` only for rank 1. Convert `fromOffset` to Scale (`Kit.toScale(root, Vector2.new(940,580))`).
   `LeaderboardScreen.lua` L4-22. **S**. Shared: require `UIKit.Theme` (ReplicatedStorage). Look: this *is* the look fix.
4. **Stat as icon badge + count-up.** Replace "N WINS" text (L33-34, L46) with icon + number; tween numbers from old to new value on
   change. **S/M**. Kit: propose `Kit.countUp(label, from, to, t)` in `ui/lobby/Kit.lua`. Look: cream number, dark outline.
5. **LIVE tag + row pop on update.** Small red pill "LIVE" pulsing on the header (L18-20); rows whose name changed pop (UIScale 0.9->1 Back).
   **S**. Look: red is already our notify red.
6. **Player list: diff rows instead of rebuild.** In `LobbyHudController.lua` `buildList` (L658-716) keep rows by UserId, tween
   Position on re-sort, pop-in new players, fade out leavers. **M**. Kit: none. Look: unchanged panel.
7. **Own row highlight.** In `buildList` row creation (L675-677) give `p == player` a field-green left bar + 0.85 green tint.
   **S**. Look: field green #8DBF5A.
8. **Real hover on rows + buttons.** Rows: lift (UIScale 1.02) + brighter tint on MouseEnter (L680-681); wrap `lbHide`/`lbMode`
   (L323-325) in `Kit.bindButton`. **S**. Look: no colour change.
9. **"You are #N" footer on the board.** Ask the OrderedDataStore for the viewer's rank (server, `LobbyLeaderboard.lua`) and draw
    a pinned footer row. **M**. Look: green bar like change 7.

Scale note: the player list is built in design px then `Kit.toScale(root)` (L382) / per row (L715): compliant. The board is a
fixed 940x580 SurfaceGui in Offset: not compliant with the Scale rule, fixed by change 3.

## Could not verify from stills
- Whether RIVALS' board tabs are clickable in-world or only cycle (no click seen); cycle period (~6-10 s estimate).
- Any number tick/count-up or row animation on RIVALS boards or list; hover effects on list rows.
- Our board's current in-game look (not visible in `sheet_before.jpg` state 1); judged from code only.
