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
