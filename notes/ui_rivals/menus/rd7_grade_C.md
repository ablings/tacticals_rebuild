# rd7 grade C: feel and interactivity, with live-like data

Sources: the rd7 captures, plus a read of Notify, PartyScreen and RankedScreen at 857ccfd. The data comes from `tools/realdata_ui.lua`.

## Fixes from rd4, checked in the code
- Inbox close: fixed. `fit` uses a local `myCanvas` and returns early if it has no Parent. The canvas is made fresh in every buildInbox, and its AbsoluteSize connection is destroyed with the gui, so connections don't pile up across opens. The list is now 846 wide and the content 828, so the bar has its own space.
- Toasts: fixed. The banner holds 1.4 s, then waits the other 2 s only `if #queue == 0`.
- Party: fixed. `fitCanvas` is measured on `canvas`, and the hook is connected once (the `_FitHooked` attribute).
- Leaderboard: fixed. `fit` is measured on `ui.canvas`. `CanvasPosition` is reset at the top of fillBoard. Headshots are cached in `ui.heads`, and the hook is connected once. The shade guard I asked for is no longer needed, because the canvas doesn't pop.

## ranked: 10/10
No change.

## ranks: 10/10
No change.

## rankedlb: 9/10
1. **The open board goes stale.** `RankedTop_` AttributeChanged calls `render()`, which only updates the Warlord strip. The open board keeps the old rows until you reopen it. Fix: in that handler, also run `if ui.boardList and ui.boardList.Parent.Parent.Visible then fillBoard() end`, but skip popIn on that refill.
2. **Going from a full board to an empty one** keeps the old fixed `CanvasSize`, and the old `ui.fitBoard` closure. A resize then sizes the canvas for the old row count. Fix: in the empty branch, set `ui.fitBoard = nil` and `holder.CanvasSize = UDim2.new()`.
3. If the board is opened twice quickly, a headshot whose fetch hasn't finished is fetched twice. Fix: set `ui.heads[uid] = ""` before the spawn, as a pending marker.

## party: 9/10
The code is right, but rd7_party still has no other people, so the grid with cards has still not been tested with data. Add 6+ fake entries to `people()` through realdata_ui (an attribute that PartyScreen reads in Studio).

## playercard: 10/10
No change. No connections leak.

## inbox: 8.5/10 (was 8)
1. **A Push while the inbox is open** raises `unread` and the corner badge while you're reading, and the new row doesn't appear. Fix: in Push, `if Notify.InboxOpen() and inboxRoot and inboxRoot.Name == "Root" then unread = 0; buildInbox() end`, but only for the Inbox, not News. buildInbox also opens it again with a pop, so a quieter option is to skip `Kit.open` when it is rebuilt.
2. The age chips are still frozen when it opens (all show "3m ago"). Run `ago()` again every 30 s while `inboxGui` is open, keeping a list of the chip labels.
3. With `Setting_DeliveryMode == "Disabled"`, Push returns before the inbox insert, so the notice is lost from the inbox too. Muting banners should still log the notice: move the guard to just before `table.insert(queue, n)`.

## news: 10/10
No change.

## toasts: 9/10 (was 8.5)
1. **Two sounds at the start of a synchronous burst.** Banner 1 finds the queue empty, so `_burst` is false and the sound plays. Banner 2 then reads `_burst == false` and plays it again. Fix: set the sound gate from `#queue > 0` *before* the remove (that is, `#queue > 1`), or keep a 1.5 s sound cooldown instead.
2. If `pill()` errors, `showing` stays true and every later toast is lost. Wrap the build in pcall, and reset `showing` if it fails.
3. The exit is still 0.3 + 0.32 s (0.2 s was asked for). This is minor.

## Top 8
1. Inbox: a Push while it is open refreshes the list and keeps unread at 0.
2. Leaderboard: refill the open board when `RankedTop_` changes.
3. Toasts: one sound per burst (the gate is off by one).
4. Inbox: tick the age chips every 30 s.
5. Inbox: the Disabled delivery mode mutes banners, not the inbox log.
6. Leaderboard: in the empty branch, clear `fitBoard` and `CanvasSize`.
7. realdata_ui: add fake party people, so the grid is graded with cards.
8. Toasts: a pcall guard around the banner build, so `showing` can't get stuck.

Remaining gap worth another round: yes. Items 1 to 3 are real behaviour bugs with live data. All of them are small, and one short round covers them.
