# e17 grade C: interactivity and feel

Sources: the e17 captures and the code at 5c5699a (Notify, PartyScreen, PlayerCards and RankedScreen diffs against 6f29542).

**What landed:**
- The inbox `pill()` is a CanvasGroup (Notify:95), so popIn's GroupTransparency fade now applies to the rows. The age chip is parented to the row, so it fades with it.
- PartyScreen `personCard` is a CanvasGroup, and the renderGrid filter is `IsA("GuiObject")`, so the cards still pop and now fade as well. The leader crown's top tips sit at the card's top edge (about 0-3 px inside), so check that the CanvasGroup doesn't clip them.
- The leaderboard crest holder `cHold` is a CanvasGroup, so the crest fades while it scales.
- The pinned own row pops in (`Kit.popIn(ui.ownRow, 0.2)` in fillBoard). **Only half landed:** `own` is still a plain Frame with AnchorPoint 0,0. It gets the 0.85 to 1 scale only, at full opacity, and it scales toward its top-left corner (RankedScreen:316).

**Still open:**
- `Theme.blur`: Notify:215 and 305 are still the literal 24, although the comments next to them say Theme.blur.
- The player menu still has no un-light on close.
- Party: the empty label still swaps its text with no crossfade.
- The leaderboard rows still use a Scale height of 0.07.

## ranked: 10/10
No feel fixes left.

## ranks: 10/10
The new 14 px Gap frame sits in the layout and has no motion side-effects.

## rankedlb: 9/10 (was 8.5)
1. Own row: Frame -> `CanvasGroup`, then `Kit.centreAnchor(own)` once in buildBoard, so it fades in and grows from its centre (803x64 at 40,526) like the rows above it.
2. Rows: Scale 0.07 -> a fixed 56 px through toScale, tested with 15 fake entries.

## party: 9.5/10 (held)
1. Empty label: when the text changes and the plate is already visible, fade TextTransparency from 1 to 0 over 0.15 s (PartyScreen:277).
2. Crown: if the CanvasGroup clips it, move it from Position 0.1 to 0.16 on the headshot (about 4 px lower).

## playercard: 9.5/10 (unchanged)
1. Close: `m.row.BackgroundTransparency = 1` (PlayerCards:382) -> `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})` (rivals_rec t0152-t0156).
2. The 48 px arrows recolour on hover correctly. The 2-player click-through test is still pending.

## inbox: 9.5/10 (was 8.5)
1. Blur: the 24 at Notify:215 -> `Theme.blur`.
2. Toast banner: it shares `pill()`, so it is now a CanvasGroup too, but its exit only slides ("slide back up and fade", Notify:133). Add `GroupTransparency` 0 -> 1 over 0.3 s on the exit, and enter from 1 -> 0 over 0.2 s.

## news: 10/10
Nit: the 24 at Notify:305 -> `Theme.blur`.

## Top 8
1. Leaderboard: the own row becomes a CanvasGroup with a centred anchor, so the pop fades and grows from the centre.
2. Notify: `Theme.blur` at 215 and 305 (the comments already claim it).
3. Toast banner: fade GroupTransparency on its enter and exit, now that it is a CanvasGroup.
4. Player menu: a 0.1 s un-light on close.
5. Party: crossfade the empty label when it changes between two empty tabs.
6. Party: check the crown's tips against the card's CanvasGroup clip.
7. Leaderboard: a fixed 56 px row height.
8. Player menu: the 2-player click-through test.

Remaining gap worth another round: yes (small: items 1-3 are one-line changes)
