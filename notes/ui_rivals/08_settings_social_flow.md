# 08 Settings / social / flow vs RIVALS (UI audit, 2026-10-21)

Area: Settings, party + player cards, notifications, loading / teleport, match flow, touch, nameplates.
Frames are in `notes/rivals_rec/`. The contact sheet labels run ~18 s ahead of the frame times.

## What RIVALS does
- **Interactability**
  - The player menu (`t0110.0s` -> `t0111.0s`, `t0130.0s`) slides out with its rows filling in. Each row has a white icon on a coloured end-cap.
  - The Ranked card scales up from small (`t0285.4s` -> `t0287.0s`). Mode select closes through a blurred fade, not a hard cut (`t0291.9s`, `t0292.0s`).
  - The "Favorite Reward" banner drops in at the top centre (`t0105.0s`, `t0108.0s`).
  - Hovering another player shows a "Double tap to view profile" pill (`t0135.0s`).
- **Cleanliness**
  - Settings uses an icon tab strip and one row per setting (icon, name, stepper, %, slider). A detail panel on the right explains the selected row. Reset is its own card (`t0135.7s`, `t0137.0s`, `t0139.0s`).
  - The player list is a plain name / score column with no extra chrome (`t0150.3s`, `t0157.8s`).
- **Kid-friendly**
  - Locked Ranked shows a checklist: one short line per requirement, each with a progress bar, a count and a green tick (`t0287.0s`).
  - The queue pad shows "Challenge your friends [Invite]" as one obvious next step (`t0294.9s`).
  - Menu rows are big, with one verb each (Party Invite, Add Friend, Challenge, Send Gift, Block).

## Gaps
| Our element | RIVALS behaviour | Quality | Sev |
|---|---|---|---|
| Match flow phase swaps (Loading / MapVote / Loadout / Switch) are instant `Visible` flips | Panels pop in; screens leave through a fade or blur | Interact | P1 |
| Party card `1v1` / `Invite` buttons are 88x34 design px, with no hover or press, and the kick X is 30x30 | Chunky buttons with one verb each, all reacting to input | Kid / Interact | P1 |
| Map tiles and loadout tiles grow on hover but don't squash on press; picked chips and voter heads appear with no motion | Every tap gets a response | Interact | P1 |
| Loading counter is fake (`os.clock()*25`, capped at 99) and parks on "99" | Progress is shown honestly, or the screen just moves on | Kid / Clean | P2 |
| Vote and loadout timers count `10.0` flat, with no last-seconds cue | Counters animate | Interact | P2 |
| Player menu rows use text glyphs (`+ » ◎ →`) and change colour on hover only | Icon end-caps; rows lift | Clean / Interact | P2 |
| Top-right Inbox / News / Settings show a tooltip only; the unread badge is static | Buttons grow; badges pop | Interact | P2 |
| Inbox close destroys it instantly (`Notify.CloseInbox`) | Pop-out | Interact | P2 |
| Loading-screen status / % text is capped at 15-16 px | Readable at a glance | Kid | P2 |
| Settings reset needs a double-click, but the first click gives no sign | Says "Double tap" (we do too) | Kid | P3 |
| Touch buttons change colour on press, no squash | Can't verify from the clip | Interact | P3 |

## Ranked changes
1. **Phase transitions in match flow.** `ui/match/MatchFlowUI.client.lua` `setPhase` (l.697-746): wrap `loading` / `vote` / `lo` in CanvasGroups and run `Kit.open` on show / `Kit.close` on hide. Fade `back` instead of snapping it. **M**. Kit: none (already requires UIKit.Kit at l.212). Look: motion only.
2. **Press squash on match tiles.** `buildMaps` (l.304-305) and `optionTile` (l.628-631): swap the hand-made hover tweens for `Kit.bindButton(t, {hover=1.04/1.08})`. **S**. Kit: none. Look: unchanged.
3. **Party buttons readable for kids.** `ui/hud/PartyScreen.lua` `actionButton` (l.84-88): size 88x34 -> about 130x52, text 18 -> 24, add `Kit.bindButton`. Kick X (l.149): use `Kit.closeButton` at about 44 px so it gets our square dark X with the tan hairline. Bind the tabs (l.287-291). **S**. Look: field-green and tan gradients kept.
4. **Pick / vote pop.** Add **`Kit.pop(gui)`** (UIScale 0.6->1, Back, 0.18 s) in `ui/lobby/Kit.lua` next to `Kit.open` (l.861). Call it on voter heads (`refreshVotes`, l.327), on `tile.count` changes (l.335), and on the loadout chip when `refreshChips` (l.581) sets a new item. **S**. Kit: new helper. Look: motion only.
5. **Honest loading.** `MatchFlowUI` l.147 / l.818: drop the fake 0-99 counter. Show `Kit.loadingDots` plus the plain words "Waiting for opponent" or "Getting the map ready". **S**. Look: our logo stays the hero.
6. **Timers that react.** `MatchFlowUI` heartbeat (l.808, l.814): at 3 s or less, tick red (`Theme.color.red`) with a 1.15 scale pulse each whole second. Add **`Kit.pulse(obj, scale)`**. **S**. Look: our red; Montserrat kept.
7. **Player menu rows.** `ui/hud/PlayerCards.lua` `ACTION_GLYPH` (l.261) and the row build (l.296-303): use cream flat icons from `Kit.ICONS` (add `friend`, `party`, `duel`, `profile`, `block` art via codex) in a coloured end-cap. Add `Kit.bindButton(b,{hover=1.03})`. Stagger the rows 0.03 s each at open (l.326-331). **M**. Kit: ICONS entries. Look: cream icons.
8. **Top-right buttons + badge.** `ui/hud/Notify.lua` `MountTopRight` (l.260-277): `Kit.bindButton(btn,{hover=1.1})`; `Kit.pop(badge)` when the unread count rises (`refresh`, l.288). **S**. Look: unchanged.
9. **Inbox close.** `Notify.CloseInbox` (l.201-204): `Kit.close(inboxRoot, destroy)`. **S**.
10. **Loading-screen text size.** `ui/intro/LoadingScreen.lua` l.176-181: raise `MaxTextSize` 15/16 -> about 22/26. The status should use simple words ("Loading map...", not asset jargon). **S**. Look: same font and colours.
11. **Reset hint.** `ui/set/SettingsScreen.lua` reset handler (l.465): on the first click, shake the button and change the line to "Click again to reset" for 0.4 s. **S**.
12. **Touch press squash.** `ui/touch/TouchControlsController.lua` InputBegan / Ended (l.197-230): UIScale 0.92 on down, back to 1 on up. **S**. Look: unchanged.

Shared needs: `Kit.pop`, `Kit.pulse` and new `Kit.ICONS` entries in `ui/lobby/Kit.lua`. `ui/matchplace/Theme.lua` needs no token changes, but note `INK_YELLOW` / `Theme.color.gold` (#FFD400) is still the selected-tab colour in the loadout. That differs from the field-green / tan direction, so Edward should confirm it.

## Not verifiable from stills
- Hover / press timing and easing on RIVALS buttons, and any sound on match-found or notifications.
- RIVALS' map vote and loadout screens: Edward spectated a duel (`t0111.7s`-`t0120.6s`), and no vote or loadout appears in the recording.
- RIVALS' teleport / loading screen between places: none captured.
- Nameplate behaviour with distance, and RIVALS' touch press feedback (no mobile capture).
- Whether the Settings detail panel animates beyond the text swap.
