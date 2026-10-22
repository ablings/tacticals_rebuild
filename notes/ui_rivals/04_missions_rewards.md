# 04 - Missions / Codes / Rewards vs RIVALS (feel only)

## What RIVALS does
- **Interactable:** the claim is an event, not a re-render. Claimed tiles swap their item for a big green check (`t0100.4s`, pass track `t0141.6s`, `t0148.0s`), and a pill banner drops in with the reward thumbnail (`t0099.7s`, `t0104.8s`). A bobbing 3D "Watch now to claim" sign and the red Tasks badge pull you in from the hub (`t0140.0s`, `t0147.0s`). Item rewards get a full-screen live 3D model with its name and a white "where from" chip (`t0019.6s`, `t0020.5s`).
- **Clean:** every free-reward row is the same shape: a bold title, one grey line, a reward thumbnail, and ONE coloured verb button (Invite / Favorite / Join / Verify, `t0085.9s`). The emote claim opens a tiny modal: tile, name, one FREE button (`t0097.6s`).
- **Kid-friendly:** short verbs ("Play duels", "Win duels", `t0147.0s`). Each reward is a picture plus `xN`, not prose (`t0102.3s`). Day 7 is a hero tile twice the size (`t0102.3s`). The progress rule is spelled out with live numbers: "Win (6/25) rounds ... to level up" (`t0141.6s`).
- **Tracks:** free/premium rows, numbered steps, an underline per step, arrow paging, checks on claimed steps (`t0143.0s`).

## Gaps
| Our element | RIVALS behaviour | Quality | Sev |
|---|---|---|---|
| Missions CLAIM -> `ask` -> full `render()`; the card just becomes "CLAIMED" | Claimed tile pops a big check, banner + reward | Interact | P1 |
| Done / ready colour = `Tac.C.oliveHi` / `#FFD400` (yellow, same as `Theme.amber`) in Missions, hub widget, Codes, Notify | Clear "done" colour (their green) | Look/Clean | P1 |
| Ready card: static stripe; nothing draws the eye | Bobbing callouts, pulsing badge | Interact/Kid | P1 |
| Hub widget rows: titles truncated at 24 px ("Get 3 eliminations..."), no CLAIM on the hub | Short verbs, count, reward icon | Kid/Clean | P1 |
| Scissors pill `count.Text = commas(...)` jumps | Counters animate | Interact | P2 |
| Codes success = a status text line | Banner + reward reveal | Kid/Interact | P2 |
| "D-01" / "W-02" codes, IN PROGRESS strip, footer sentence | No ids, little text | Clean | P2 |
| Bars only fill on open; a re-render (claim, live data) snaps | Bars animate on change | Interact | P2 |
| Inbox: `CloseInbox` destroys instantly; rows appear all at once | Quick pop-out | Interact | P3 |
| Codes box: no focus ring, error doesn't move | Obvious feedback | Kid | P3 |

## Ranked changes
1. **Claim moment.** `MissionsScreen.taskCard` CLAIM handler (L148): before `render()`, squash the button, pop a check 0->1.15->1 (Back), fly the reward to the HUD scissors pill, `Kit.sfx("reward")`. Re-render after 0.45 s. **M.** Shared: new `Kit.popIn(obj, delay)` + `Kit.flyTo(obj, targetAbsPos)`. *Look:* motion only; uses the cream check.
2. **Done = field green, not yellow.** Replace `Tac.C.oliveHi` (Missions L92/L119/L128/L129), `#FFD400` (hub L587/L620; Codes L39/L52; Notify `GREEN` L28). **S.** Shared: add `Theme.color.done = #8DBF5A` and stop aliasing `olive`/`gold` to `#FFD400` in the lobby. *Look:* field green is our primary; amber stays tutorial-only.
3. **Ready card pulls the eye.** In `taskCard` when `ready`: breathe the card's UIScale between 1.00 and 1.03 (Sine, 0.8 s), loop the CLAIM button's sheen, and lift the card on hover via `Kit.bindButton(card-hit, {hover=1.04})`. **S.** Shared: `Kit.breathe(obj)`. *Look:* no new colours.
4. **Hub widget: short verbs + claim.** In `LobbyHudController.refresh` (L577-602), use a `def.Short` label ("Get elims", "Throw gadgets"; fall back to `def.Text`) at 26 px. When `done and not claimed`, draw a green CLAIM pill in place of the check that opens Missions. Tween the bar fill from its old frac (key it on `lastRows`). **M.** `Short` goes in the Config (lead). *Look:* same glass card.
5. **Declutter the Missions cards.** Drop the "D-0n" label (L117) and the IN PROGRESS strip (the count says it), cut the footer (L196) to "Play matches to fill these up.", title 24 px Montserrat Heavy. **S.** *Look:* keeps the headings rule.
6. **Counting scissors.** In the HUD pill (L560), tween a NumberValue from old to new over 0.6 s, with a 1.12 scale pop on the pill. **S.** Shared: `Kit.countTo(label, from, to, t)`. *Look:* unchanged pill.
7. **Animate bars on every change.** In `MissionsScreen.render`, remember the last frac per `scope..i` and tween from it, not only on open (L250-255). **S.**
8. **Codes success reveal.** In `CodesScreen.redeem` (L50-53), on `r.ok`: the Redeem button squashes, the status line pops (`Kit.popIn`), and the new chip in `renderList` slides in. On failure, shake the box ±8 px. Field-green stroke on focus. **S.** *Look:* the dark box is kept.
9. **Item reward reveal.** When `Notify.Push` carries `reward.kind == "Item"`, show a centre card first (1.2 s): a live `ViewIcons.Viewport` spin, the name in Montserrat Heavy, and a cream "From Missions" chip (pattern of `t0019.6s`). Then the pill. **M.** *Look:* dark plate + cream; no uploads.
10. **Inbox motion.** `Notify.CloseInbox` (L201) should call `Kit.close(inboxRoot, destroy)`, and `buildInbox` should stagger rows in (0.03 s each, `Kit.popIn`). **S.**
11. **Reward-track pattern for the Daily Tasks / future Pass.** Build a `Kit.rewardTrack(steps)` (numbered tiles, underline per tile, green check on claimed, hero last tile like Day 7). Use it for the queued Daily Tasks streak first. **L.** Shared Kit. *Look:* tan tiles on a dark plate.
12. **Notify reward count.** `rewardBox` (L85-88) should count `×N` up from 0 while the pill drops. **S.** Uses `Kit.countTo`.

## Not verifiable from stills
- Claim-check easing; banner hold (ours 3.4 s, theirs ~3 s, `t0099.7s`-`t0103.6s`).
- Whether the hub sign bobs (inferred from `t0140.0s` vs `t0147.0s`).
- Pass-track paging motion; the reward fly-to-pill is our own proposal.
- Hover lift on the free-reward buttons (no cursor visible in the frames).

## Implemented (group D)
2026-10-21, RIVALS pass. Not run in Studio: no Luau analyzer on this machine, so I only checked that blocks and brackets balance.
- **Claim moment:** `ui/pseudolobby/hub/MissionsScreen.lua:179-205`. Pressing CLAIM squashes the button by tweening bindButton's own UIScale to 0.88 and shows `Kit.busy` dots while `ctx.ask("ClaimQuest", scope, i)` (unchanged) waits for the server. On `r.ok` a cream check `Kit.popIn`s over the art, the scissors reward gets `Kit.pop` 1.3, `Kit.sfx("reward")` plays, and the cards re-render 0.65 s later. A failed claim re-renders straight away. A `claiming` guard stops double clicks.
- **Re-render hold:** `MissionsScreen.lua:60-71` (`renderSoon`, with a token so the latest call wins) and `:324`. `Screen.Refresh()` now waits for a claim's hold, so the server's data refresh can't destroy the card mid-pop. Open still renders at once.
- **Ready cards:** `MissionsScreen.lua:160-178`. The card is centre-anchored (same spot) and calls `Kit.breathe(card, 0.03, 1.6)`. A looping UIGradient sheen sweeps CLAIM (0.9 s sweep, 1.1 s pause). The hover lift moves the card up 6 design px by Position, in Scale. It is not a UIScale, because the breathe already owns the card's scale.
- **Declutter:** the D-01 / W-02 label is gone (`MissionsScreen.lua:130`). The IN PROGRESS strip is gone and the `prog / goal` count is kept (`:207`). The footer now reads "Play matches to fill these up." (`:251`).
- **Codes:** `ui/lobby/CodesScreen.lua:46-75`. An empty or failed code shakes the box with `Kit.shake`; it restarts from the stored Scale home (`:119`) so repeated shakes don't drift. A good code pops the status line with `Kit.pop` 1.25 (the line is now anchored left-middle in the same spot, `:110`) and punches the Redeem button's UIScale. Redeem shows `Kit.busy` while waiting, and a `redeeming` guard stops FocusLost + Activated from redeeming twice.
- **Inbox motion:** `ui/hud/Notify.lua:209-222`. `CloseInbox` now runs `Kit.close` on the root and fades the dim (named `Dim`, `:162`), then destroys it. `InboxOpen()` turns false at once, and reopening during the close builds a fresh inbox. Open already used `Kit.open`. The first 10 rows `Kit.popIn` with a 0.03 s stagger and are centre-anchored in the same spots (`:187-193`).
- **Top-right buttons:** `Notify.lua:292` adds `Kit.bindButton(btn, {hover = 1.1})`. The badge is centre-anchored in the same spot (`:289-291`) and `Kit.pop`s (1.35) when the unread count changes to a non-zero value (`:346-355`).

### Skipped / for others
- **The live hub corner (gear / Inbox / News + unread dots) is `ui/hud/LobbyHudController.lua` `buildCorner` (l.119-208), not `Notify.MountTopRight`.** No script calls `MountTopRight`. The live buttons only feed `Notify.OnUnread(corner.setUnread)`. That file belongs to group A / the integrator, so the hub corner needs the same two lines there: `Kit.bindButton` on each corner button and `Kit.pop(dot)` in `setUnread` when the count changes.
- **Two reward sounds:** the server's `RN.Send` banner also plays `Kit.sfx("reward")` in `Notify.nextBanner`. Kit's 0.04 s de-dupe only merges them when they land together. If they double up, drop the one in the claim handler.
- **Kit gaps (not added):** a bound button has no squash helper. `Kit.pop` on a bound button would add a second UIScale (Roblox applies only one per object), so I tween bindButton's UIScale directly. A `Kit.lift(card)` (position hover) and a `Kit.sheen(btn)` loop would save copies in other screens. `Kit.shake` reads the current Position as its base, so overlapping shakes drift (Codes works around this). Audit #1's `Kit.flyTo` was cut in the plan.
- **Not done this round:** audit #7 (bars animate on every change, not in the D list), #9 (Item reward centre card, M-size, risky), #11 (reward track, L) and #12 (count the ×N on banners).
- **No colour changes.** The done / ready yellow (`Tac.C.oliveHi`, `#FFD400` in Codes, `GREEN` in Notify) waits for Q1. The only new colour is the cream claim check (`Theme.color.cream`).
- **Existing tells seen, left for the integrator:** Builder Sans in CodesScreen (FB / FM) and Notify (FX / FB). UICorner + thin UIStroke on the Missions panels (`Kit.corner(2)` + `Kit.stroke(C.olive, 1, 0.8)`) and on `Kit.button` (corner 3 + 1.5 px stroke). The Missions panels' left `TacBar` and the title TacBar. New elements add no stroke, no left bar and no text. The CLAIM sheen only has a UICorner, to match the button.
