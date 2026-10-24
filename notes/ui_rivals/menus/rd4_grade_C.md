# rd4 grade C: feel and interactivity, with live-like data

Sources: the rd4 captures, and a read of Notify, PartyScreen, RankedScreen, PlayerCards and lobby Kit at 81e1f10. Data from `tools/realdata_ui.lua`.

**A rule that applies to all three refits.** `Kit.open` / `Kit.close` put the MotionScale UIScale on the root itself (Kit:1036). So `root.AbsoluteSize` already includes that scale, and a canvas Offset inside the root is drawn at that scale a second time (s²). The per-frame hook ends each pop at the right size, but during the 0.22 s open the rows are squashed about 10% in Y only. The fix is to measure on the root's parent (`canvas`, which has no scale), or to divide by `root.MotionScale.Scale`. After that, the hook is only needed for real resizes.

## ranked: 10/10
No change.

## ranks: 10/10
No change.

## rankedlb: 9.5/10 (was 8.5)
Verified: fit() is measured on the screen root, which fixes the shrink on reopen (the popup's MotionScale is on `p`, not on root). The refit hook is in, and the bar now shows on `n*62 > 360`.
1. CanvasPosition is still not reset in fillBoard. A reopen after scrolling to #80 lands mid-list, and those rows skip the pop (popIn only runs for i <= 12). Fix: `holder.CanvasPosition = Vector2.zero` at the top of fillBoard.
2. 200 headshot calls go out on **every** open (no cache, unlike PartyScreen's `thumbs`). Fix: share a `thumbs[uid]` cache.
3. The root hook re-sizes up to 200 rows on every frame of every Ranked open/close, even with the board hidden. Fix: guard it with `shade.Visible`. Line 395 (`#top > 9`) is now dead code.

## party: 9/10 (was 8.5)
Verified: the resize hook only refits (fitGrid), so a rebuild no longer wipes the stagger or the hover. The squash during the pop is the shared issue above (measure on `canvas`). The rd4 capture has no friends, so the grid with real cards was not exercised. Add 6+ fake people to realdata_ui.

## playercard: 10/10
No connections leak: the RenderStepped and Button1Down hooks are made once.

## inbox: 8/10 (was 7)
Verified: the rows are now 108 pitch and 102 tall, and all rows can be reached.
1. **A nil error on every close.** `fit` reads the module upvalue `inboxRoot`, and CloseInbox sets it to nil before Kit.close shrinks the root. The AbsoluteSize hook then fires each frame of the 0.12 s close: `attempt to index nil`. Fix: `local root = inboxRoot` inside buildInbox and use `root` in fit (also `if not root.Parent then return end`).
2. Still open from rd3: the bar draws over the rows' right ends (the list is still 828 wide). Make it 850 (+22), as News does.
3. Still open from rd3: the age chips are frozen at open. Re-run `ago()` every 30 s while open.

## news: 10/10
No change.

## toasts: 8.5/10
The burst logic is in, with one sound. But realdata pushes in a loop: the first Push finds the queue empty, so banner 1 still holds 3.4 s, and 10 banners take about 21 s, not 15. Fix: hold 1.4 s, then wait the remaining 2.0 s only `if #queue == 0`. The exit is still 0.3 + 0.32 s against the 0.2 s asked for.

## Top 8
1. Inbox: capture the root locally in fit (the nil error on every close).
2. All refits: measure on `canvas`, not the scaled root (the Y squash during the pop).
3. Toasts: decide the hold after 1.4 s, so the first banner of a burst is short too.
4. Leaderboard: reset CanvasPosition on fill.
5. Leaderboard: cache headshots (200 web calls per open).
6. Inbox: list 850 wide so the bar clears the rows.
7. Leaderboard: guard the root hook with `shade.Visible`.
8. realdata_ui: add fake people, so the party grid is graded with cards.

Remaining gap worth another round: yes (item 1 is a real error that is thrown on every close; 2-3 are small. One short round covers them.)
