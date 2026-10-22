# 07 - In-world TV screens, duel pads, prompts (RIVALS feel audit, 2026-10-21)

Source note: `LobbyScreensController`, `LobbyScreensFX`, `LobbyTickers`, `LobbyLabels` are **Studio-only sources**. They are not in `deploy_ui.py`'s file lists; `pseudolobby/snapshot_hub.py` copies them out of the lobby Studio, and they only ship as after-match templates (`hub/manifest.json`, `deploy_ui.py` L126-175). Edit them in the lobby Studio, then re-snapshot. `PadUI`, `PadBoards` and `PromptsController` deploy from files.

## What RIVALS does
- **Interactability:** prompts are white cards with a black key square and one big verb ("Claim", "View") that sit right on the object (t0172, t0248, t0284). Walking near a reward TV pops up a callout card ("x3 Keys / Can unlock weapons!", t0176). The boards have a red **LIVE** pill (t0192, t0200, t0248).
- **Cleanliness:** the Duels TV has no sentences. Each row is avatar, score, eye icon, score, avatar (t0248). The pad wall shows one framed slot per plate with a big "0/2" / "1/1" count (t0296).
- **Kid-friendly:** the TVs lead with icons: a thumbs-up, a key "x3", a big play button with a "0/3" counter (t0172, t0264). Each TV has about one line of words. On a pad you get a bright floor plate, your avatar fills the slot (with level and streak badges), and a two-word "Challenge your friends [Invite]" strip above "[you] VS [...]" (t0296).

## Gap table
| Our element | RIVALS behaviour | Quality | Sev |
|---|---|---|---|
| All TVs, prompts and labels use yellow `255,212,0`, violet, Oswald/Gotham | (Look rule: ours should be field green / cream / olive, Montserrat + Builder Sans) | Clean | P1 |
| Prompt card: dark `DEEP` card, small text | White card, huge verb | Kid | P1 |
| Duels TV: names as text, rows rebuilt every 1 s | Avatars + scores, stable rows, LIVE pill | Clean/Inter | P1 |
| Pad board: 440x240 text panel, "TEAM A/B", status sentence | One slot card per plate, big "1/2", avatar | Kid/Clean | P1 |
| Likes bar / duel counts jump instantly | Bars fill, counters tick | Inter | P2 |
| TV copy: "ONE REWARD PER AD · ADS SHOW ONLY WHERE ROBLOX OFFERS THEM" | Icon + about 3 words | Kid | P2 |
| No callout card near reward TVs | Pop-in reward card (t0176) | Inter/Kid | P2 |
| PadBoards side panel still rebuilt every 0.25 s although PadUI hides it | n/a | Clean | P3 |
| Ticker / NPC bubble / PadBoards use Offset | (Scale rule) | Clean | P2 |

## Ranked changes
1. **Palette and font swap on every world UI.** Files: `LobbyScreensController` L19-25, `LobbyScreensFX` L284-285 + L331, `LobbyTickers` L359, `LobbyLabels` L416 + L449, `PromptsController` L17-20. Size S. Theme needs real tokens, because `Theme.olive` is now `#FFD400`: add `Theme.world = {field = {#8DBF5A, #4C7A2E}, cream = #ECE6D2, olive = #6B7A3A, ink, live = red}` and `Theme.fonts.heading/body`. Keeps our look: this is what restores it.
2. **Bright prompt card.** `PromptsController.show` L77-92: cream card, ink key square, Montserrat Heavy verb at about 60 % of the card height, field-green hold fill, ±0.08 stud idle bob. Size S. Kit: none. Look: cream and green, not RIVALS white and blue.
3. **Duels TV as pictures.** `buildDuelsTV` L132-181: headshots on both sides plus a big score, and a red "LIVE" pill instead of the `liveDot`. Stop `clear(rowsF)` every second (L141, L179): keep the rows and update only the clock text. New rows slide in. Size M. Look: cream rows on ink, field-green mode badge.
4. **Pad boards as slot cards.** `PadBoards.drawBoard` L93-122: one card per plate with a big "count/total" numeral; the headshot fills the slot with a level badge; open slots pulse (reuse PadUI's `marks`); a joiner pops in. Drop the "TEAM A/B" labels (`teamRow` L68). Rebuild in Scale: the board is fixed px + UIScale (L107-111) and `label` uses TextSize (L44-49). Diff instead of `ClearAllChildren` (L102). Size M-L. Kit: `Kit.pop`. Look: cream and olive team edges stay.
5. **Animated counters.** Likes bar tween + count roll (`buildLikes` L216-224), `buildDuelsSign` L194-200 numbers pop on change, PadUI countdown pops each tick (L357-359). Size S-M. Kit needs `Kit.countTo(label, from, to, t)` and `Kit.pop(obj, scale)`. Look: motion only.
6. **Cut words.** L97, L153, L215, L241-245 (Controller); the `message()` ticker L370-375 to 3 items; PadUI L166 "Bring a friend onto your team" and L196 "Step off the plate to leave" become a key-hint icon. Use sentence case and at most 5 words. Size S. Look: same fonts, less text.
7. **Reward callout card.** A world billboard that pops in when the player is within about 12 studs of the Likes / Ad TV: key icon, "x3", one line, with a bob. Add it in `buildLikes` / `buildAd` (or `LobbyLabels`). Size M. Kit: a world variant of `Kit.tooltip` (L823). Look: cream card, field-green accent.
8. **Delete the dead side panel.** `PadBoards` L124-179 + the Heartbeat at L195-208: `PadUI` L84-90 disables it, but it is still rebuilt 4 times a second. Size S. Look: n/a.
9. **Offset to Scale.** `LobbyTickers` L383 + L408 (TextSize 42, `fromOffset` scroll: scroll a Scale X instead), `LobbyLabels` NPC bubble L446-450. Size S. Look: unchanged.
10. **LIVE pill + softer screen FX.** `LobbyScreensFX`: replace the blinking dot with the shared LIVE pill (from #3), and keep the scan line. The Ranked ticker colour (L331, violet) becomes cream. Size S. Look: ours.

## Could not verify from stills
- Whether RIVALS prompts or TV callouts bob, how fast they pop in or out, and any hover or press feedback in the world.
- Whether RIVALS counters roll or jump; Duels TV row transitions; pad slot pop timing; sounds.
- Whether the "Watch now to claim" TV (t0264) can be clicked or works through a prompt.
- Our own TVs: I found no current render of DuelsTV / Likes / Ad / Training in the sheets (`sheet_before.jpg` doesn't show them clearly), so the Controller gaps come from the code only. `LobbyScreensFX` depends on `LobbyMap.Signs.Screen_*` parts that I could not confirm exist.
- The duel frames (110-122 s) only show the match HUD; nothing about pads there.

## Implemented (group G)
Files only (`ui/hud/PromptsController.lua`, `ui/pads/PadBoards.client.lua`, `ui/pads/PadUI.client.lua`). None of this has been run in Studio yet, so check it there before deploying. It follows Edward's rules from this pass: no UICorner + thin UIStroke combo, no left accent bars, Oswald Bold for big words and Rubik for small text.

**Prompts (`PromptsController.lua`)**
- L18-25: fonts are now Oswald Bold (action word, key glyph) and Rubik Medium (object line); they were Builder Sans. `CREAM` / `INK` literals (= Theme cream / ink) are inline because this module also runs in the match places, so it doesn't require UIKit.
- L72-106 `show`: a solid cream card over a thick dark offset shadow block (DEEP, offset down and right), with the pointer under it. The old rounded dark card with its hairline stroke is gone, and so is the yellow left-edge bar. The key / button / TAP glyph sits in an ink square with cream text. The small object line ("TRASH CAN") goes on top and the action ("Change Weapons") is big under it; with no ObjectText, the action fills the card.
- L103-106 + L114: idle bob. A looping Sine tween moves `StudsOffsetWorldSpace` between 3.12 and 3.28; `hide()` cancels it through the conns list.
- L108: the hold track is now an ink track on the cream card. The hold fill colour (OLIVE = #FFD400) is unchanged because colour changes are on hold. Note: yellow on cream is low contrast, so it should become field green once Edward decides about the yellow.
- Unchanged: hold-to-activate, click / tap on the card, the Triggered punch, the gamepad / touch / keyboard glyphs (`keyText`), `KeepDefaultStyle`. There were no per-prompt special cases in code; Trash Can / Change Weapons is just Object / Action text (fix/trash_cans.lua) and shows as small / big.

**Pad boards (`PadBoards.client.lua`, 208 -> 178 lines)**
- L1-6: new header. L12: `Kit` from `ReplicatedStorage.UIKit.Kit`. L18-19: OSWALD is now Oswald Bold (it was Montserrat Heavy); BODY (Gotham) was only used by the side panel, so it is removed.
- L52-58 `label`: TextScaled inside Scale boxes. Before, it used TextSize on a fixed 440x240 px canvas + UIScale.
- L60-68 `brackets`: the board's existing corner brackets, now in Scale (thickness corrected for the 11:6 aspect).
- L74-92 `plateCard`: one card per plate, team A | VS | team B. Each card is a solid GUN2 fill over a dark offset shadow block, with a big "n/m" count in the team colour and a row of square headshot slots (UIListLayout + UIAspectRatioConstraint). An occupied slot gets the team colour behind the headshot; an empty slot shows "+". A team-colour strip runs along the bottom (not the left). The "TEAM A / TEAM B" text is gone.
- L94-105 `buildBoard`, L107-158 `drawBoard`: the board is built once per pad and rebuilt only when the mode, pad, team size or ranked changes. Otherwise it updates in place: slots change only when their uid changes, and a joiner's headshot gets `Kit.popIn` (L140). The count gets `Kit.pop` when it changes (L150), and the status line pops on each countdown tick (L156). This also fixes a leak: each redraw used to add a new `AbsoluteSize` connection.
- `headshot` now tags the image with its uid, so a slow thumbnail can't land on a slot someone else has taken.
- Side panel deleted (old L124-179 + the 0.25 s Heartbeat L195-208): the `PadQueueUI` ScreenGui, `drawSide`, the NEAR scan, the RunService / TweenService use. `ask` stays for the first `GetQueue`.

**PadUI (`PadUI.client.lua`)**
- L24-28: fonts. OSWALD is now Oswald Bold; BODY / BOLD are now Rubik Medium / SemiBold (they were Montserrat Heavy and Gotham SSm).
- L85-86: the `WaitForChild("PadQueueUI", 30)` guard is removed, since that panel no longer exists.
- L345-363: the VS / countdown label gets `Kit.pop` whenever its text changes, but not on a box rebuild.

**Skipped**
- Level / streak badge on the board headshots, pulsing open-slot marks on the boards, and cutting the PadUI copy ("Bring a friend onto your team", "Step off the plate to leave"). These are outside group G's list, or are copy decisions.
- Hold fill / brackets / team / ranked colours: no colour changes (comic yellow decision pending).
- Existing AI tells I saw but did not touch: in `PadUI.brackets` (L47-60), every PadUI panel and slot gets a UICorner + 1.5 px UIStroke "_Edge". The SQUAD UP strip has a 6 px left accent bar (`buildPadBox`, about L164). The JOIN buttons use the same UICorner + stroke via `brackets`. Fixing these restyles the on-pad box, so it needs its own pass.
