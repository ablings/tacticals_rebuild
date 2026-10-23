# rd3 grade C: feel and interactivity, with live-like data

Sources: the rd3 captures, plus a read of RankedScreen, PartyScreen, Notify, PlayerCards and lobby Kit (read-only). The data came from `tools/realdata_ui.lua`. The real data turned up three bugs that the empty Studio state had hidden.

## ranked: 10/10
Placed state, shield banner and Warlord strip all fill correctly. No feel fixes.

## ranks: 10/10
No change.

## rankedlb: 8.5/10 (was 9.5)
The first open is right: the pitch measures 61.5 design px (56 + 6), the rows stagger in and the pinned #15 row pops.
1. **Reopen shrinks the rows.** Kit.close leaves MotionScale at 0.92, and fillBoard runs before show() (RankedScreen:559). It reads `holder.AbsoluteSize.Y` at 0.92 scale, and CanvasSize Offset is then drawn under scale 1, so the rows come out 51.5 instead of 56 from the second open on. Fix: divide gy by the panel's MotionScale (`p.MotionScale.Scale`), or run the sizing pass after Kit.open in `task.delay(0.23)`.
2. **No re-fit on a window resize.** The canvas is a fixed Offset, so after a resize the rows keep their old pixel size. Hook `holder:GetPropertyChangedSignal("AbsoluteSize")` and re-run only lines 415-424, and skip it while a MotionScale tween is running.
3. The scrollbar shows at `#top > 9`, but 360 / 62 is only 5.8 rows, so a board of 6-9 entries scrolls with no bar. Change the test to `#top * 62 > 360`. Also set `CanvasPosition = 0` on fill, so a reopen starts at #1.

## party: 8.5/10 (was 9.5)
1. **The resize hook fires on every frame of the open and close.** It is `grid AbsoluteSize -> renderGrid()` (PartyScreen:311). Kit.open(root) tweens a UIScale from 0.9 to 1, which changes AbsoluteSize on every frame. The grid is rebuilt about 13 times with no `animate`, so the staggered card pop is wiped out on the first frame, and with real friends the grid just appears at once. It also rebuilds during the close, with no `isOpen` check. Fix: `if isOpen and not tweening` where tweening means the MotionScale is not 1, then debounce with `task.defer`. The better fix is to re-run only `fitCanvas()`, since the cards are Scale and don't need a rebuild.
2. A rebuild mid-hover drops the hover scale and any running `Kit.busy` on Invite/Duel. Fixing 1 also covers this.

## playercard: 10/10 (was 9.5)
The un-light tween landed (PlayerCards:382). The 2-player click-through test is still pending.

## inbox: 7/10 (was 10)
1. **The rows are stretched to 1.41x and the last rows can't be reached.** `content.Size = fromScale(1, rows/768)` (Notify:219) is measured against the canvas, which is already `rows*108` tall. The capture shows a pitch of 151 design px against 108, and a row height of 142 against 102. The content is 1518 tall on a 1080 canvas, so rows 9-10 (and most of row 8) can never be scrolled to. Fix: `content.Size = UDim2.fromScale(1, 1)`.
2. The 10 px bar draws over the rows' right ends (the list is 828 wide, the same as the rows). Make the list 850 wide (+22) so the bar sits in the gap, the same fix News got in e7.
3. The age chips are frozen at open. Refresh `ago()` every 30 s while the inbox is open (minor).

## news: 10/10
No change.

## toasts (Notify nextBanner)
Ten pushes in a row queue 10 x 3.72 s, which is **37 s of back-to-back banners**, each one with the "reward" sfx. Fix: hold for 3.4 s only when the queue is empty. Otherwise hold 1.4 s, use a 0.2 s exit, and play the sfx on the first banner only. Or fold three or more queued banners into one "+N more" pill.

## Top 8
1. Inbox: content Size (1, 1). This fixes the stretched rows and the unreachable rows 9-10.
2. Party: stop the AbsoluteSize hook rebuilding during the open/close scale tween (re-run fitCanvas only).
3. Toasts: a shorter hold and one sfx while the queue is non-empty (37 s -> about 15 s for 10).
4. Leaderboard: size the rows independently of MotionScale (the 8% shrink on reopen).
5. Leaderboard: re-fit the canvas on a window resize.
6. Inbox: list 850 wide so the bar clears the rows.
7. Leaderboard: scrollbar threshold `#top*62 > 360`, and reset CanvasPosition on fill.
8. Inbox: refresh the age chips while open.

Remaining gap worth another round: yes (items 1-4 are real-data bugs; one short round with the same realdata script verifies them)
