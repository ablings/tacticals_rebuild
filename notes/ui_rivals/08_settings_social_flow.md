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

## Implemented (group F)
Done 2026-10-21 by the group F agent. Not run in Studio: no Luau analyser here, so this is a careful read only. Line numbers are as of this pass.

**ui/match/MatchFlowUI.client.lua**
- l.18: `UIKit.Kit` required under a pcall. Without it, every change below falls back to the old behaviour.
- l.61: fonts. `FX` (headings, timers, map names) is Oswald Bold now, was Montserrat Heavy. A new `FR` is Rubik SemiBold. `FB` (Builder Sans) is untouched on the old body text.
- l.153: honest loading. The fake 0-99 counter is hidden (`loadN` kept, not visible) and the `Kit.loadingDots` sit bottom-right. The words are in Rubik. At l.891 they are rechecked twice a second: "Waiting for opponent" until the other team list has a player or bot, then "Getting the map ready".
- l.321: map tiles use `Kit.bindButton(t,{hover=1.03})` (hover plus a press squash). l.661 does the same for loadout option tiles (`{hover=1.08}`, gamepad selection included).
- l.347 / l.362: a voter headshot that is new on a tile gets `Kit.popIn`, and the vote count gets `Kit.pop` when it changes.
- l.613: a loadout chip gets `Kit.pop` when a new pick lands in it.
- l.732: chips and both timers are centre-anchored, so the punches grow from their middle.
- l.740: `showFrame` plus `setPhase`. Loading, MapVote and Loadout / Switch now open with `Kit.open` and leave with `Kit.close`. The ScreenGui switches off 0.14 s later, so the close can play. A frame reopened mid-close comes back through the close's `done`.
- l.772: the backdrop tweens to its level over 0.18 s (to 1 when the flow ends) instead of snapping.
- l.875: the vote and loadout timers get `Kit.pulse` once per whole second in the last 3 s. There is no red flash because of the no-colour rule.
- Unchanged: votes, picks, the third pick readying you (`allPicked`), Switch Weapons and KitLocked, and the HUD hiding.

**ui/hud/PartyScreen.lua**
- l.28: the `F_HEAD` "YOUR PARTY" heading is Oswald Bold, was Montserrat Heavy.
- l.84: `actionButton` is 130x52 (was 88x34) with text at 24 (was 18). It has `Kit.bindButton`, and the sent tick is bigger and gets `Kit.pop`. Same gradients.
- l.133 / l.238: cards with buttons are 150 tall (was 108), with buttons at y 86 and a grid row step of 160 (was 118). Party-column cards stay 108.
- l.155: the kick X is `Kit.closeButton` at 44 px (was a 30 px red square with a "×" glyph). Its tan hairline UIStroke is removed because of the no corner + thin stroke rule. Note that it is dark at rest and warms red on hover, which is the shared helper's look and not the old solid red.
- l.305: the All / Friends / Lobby tabs have `Kit.bindButton`.

**ui/hud/PlayerCards.lua**
- l.35: the `F_HEAD` font is Oswald Bold, was Montserrat Heavy.
- l.262: View Profile and View Avatar draw `FlatIcons` "account" in bone, turning to ink on hover like the glyph did. FlatIcons has no plus, duel, eye or block art, so Invite, Add Friend, Challenge, Spectate and Block keep their glyphs.
- l.316: menu rows use `Kit.bindButton(b,{hover=1.03})` instead of the hand-made click pop. They share one UIScale named `PopScale`.
- l.339: rows stagger in with `Kit.popIn(b, 0.04 + i*0.04)` as the panel slides out. Duel invites and requests are untouched.

**ui/intro/LoadingScreen.lua**
- l.82: `FONT` is Oswald, was GothamSSm. It covers the % number, DEPLOYING (now Bold) and PRESS ANY KEY. The status line is Rubik Medium (`FONT_BODY`). The logo art, slash and shatter are untouched.

**Skipped, and why**
- TouchControlsController press squash (audit item 12) is not in the group F list and touch input is fragile, so it is left. Its fonts are Builder Sans only and were left alone.
- NameplatesController has nothing in the group F list. It uses Builder Sans only, so no change was needed.
- LoadingScreen MaxTextSize 15/16 to 22/26 (audit item 10) is not in the group F list.
- Phase fades are scale-only, plus the backdrop fade. The phase frames were not wrapped in CanvasGroups, because the map and item ViewportFrames and the large text would render soft or blurry inside a CanvasGroup.
- There is no red flash on the timers because of the no-colour-change rule.
- Builder Sans body text in these files was not switched to Rubik: the instruction named Montserrat and Gotham. It is left for the integrator's font pass.

**Kit notes (missing or worth knowing)**
- `Kit.pop` / `popIn` use a UIScale named `PopScale`, `breathe` uses `BreatheScale` and `bindButton` takes the first UIScale. Two UIScales on one object don't multiply, so I pre-made one `PopScale` for both (PlayerCards rows). Kit could make `motionScale` reuse an existing UIScale.
- `Kit.open` / `close` always play the open / close sfx, so match-flow phase swaps now make those sounds. A `silent` option would help.
- `Kit.close`'s delayed `Visible = false` is not cancelled by a later `Kit.open`. Callers have to re-show the frame in `done`, as MatchFlowUI does.
- FlatIcons needs plus, duel, eye and block drawings for the remaining player-menu glyphs.

**Existing AI tells seen (not restyled)**
- PartyScreen l.286: a 10 px olive left-edge accent bar beside "YOUR PARTY".
- PartyScreen `personCard` and the empty slots, and the PlayerCards menu panel: UICorner + 1.5 px UIStroke.
- MatchFlowUI `ink()`: a 1.5 px white UIStroke on cornered tiles, boxes and timers.
- `Kit.closeButton` itself: corner + 1.5 px tan stroke.
- Builder Sans body text throughout (MatchFlowUI `FB`, PartyScreen / PlayerCards `F_NAME` / `F_SUB` / `F_NUM`, Nameplates, Touch).
