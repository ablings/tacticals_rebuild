# e18 grade C: interactivity and feel

Sources: the e18 captures and the code at d80b6a0 (the Notify and RankedScreen diffs against 5c5699a).

**What landed (all three):**
- The leaderboard own row is now a `CanvasGroup`, and `Kit.centreAnchor(own)` runs in buildBoard (RankedScreen:318-322). `Kit.popIn` (lobby Kit:957) now fades GroupTransparency from 1 to 0 over 0.18 s and scales it from 0.85 to 1 from its centre. The headshot's UICorner and the 32 px rank sit inside the group, and the capture shows nothing clipped. Done.
- The toast banner now fades in and out. On enter, GroupTransparency goes 1 -> 0 over 0.2 s next to the 0.35 s Back slide. On exit, it goes to 1 inside the same 0.3 s Quad-In tween as the slide up, and the holder is destroyed at 0.32 s, so the fade finishes first. Done.
- Notify's blur: `BLUR` is read once from `UIKit.Rivals.Theme` through FindFirstChild, falls back to 24 inside a pcall, and is used at both sites (inbox 223, news 313). Notify deploys to `ReplicatedStorage.UIKit`, so `script.Parent.Rivals` is the right path. Done.

**Still open (carried over):** the player menu has no un-light on close; the party's empty label has no crossfade; the crown's tips haven't been checked against the clip; the leaderboard rows are still Scale 0.07 high; the 2-player click-through test is still pending.

**New nit:** the leaderboard's new 52 px Warlord `TitleBadge` (RankedScreen:303) is static. It arrives with the panel's open scale, which is acceptable.

## ranked: 10/10
No feel fixes left.

## ranks: 10/10
The Gap is now 6 px. It is a layout change only and has no motion side-effects.

## rankedlb: 9.5/10 (was 9)
1. Rows: Scale 0.07 -> a fixed 56 px through toScale, tested with 15 fake entries so the pitch and scroll can be judged.
2. Optional: give the title badge the crest's treatment, a CanvasGroup holder plus `Kit.popIn(badge, 0.08)`, so the two Warlord marks behave alike.

## party: 9.5/10 (held)
1. Empty label: when the text changes and the plate is already visible, fade TextTransparency from 1 to 0 over 0.15 s (PartyScreen ~277).
2. Crown: if the personCard CanvasGroup clips its top tips, move it from Position Y 0.1 to 0.16 on the headshot (about 4 px lower).

## playercard: 9.5/10 (held)
1. Close: `m.row.BackgroundTransparency = 1` (PlayerCards ~382) -> `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})` (rivals_rec t0152-t0156).
2. The 2-player click-through test is still pending.

## inbox: 10/10 (was 9.5)
The blur and the toast fade both landed. No feel fixes left.

## news: 10/10
The blur now comes from the Theme. No feel fixes left.

## Top 8
1. Player menu: a 0.1 s un-light tween on close.
2. Party: crossfade the empty label between two empty tabs.
3. Leaderboard: a fixed 56 px row height, tested with fake entries.
4. Party: check the crown's tips against the card's CanvasGroup clip.
5. Player menu: the 2-player click-through test.
6. Leaderboard: the title badge pops with the crest (optional).
7. -
8. -

Remaining gap worth another round: no for feel (only small polish is left, items 1-3 are one-liners and could go into any later pass)
