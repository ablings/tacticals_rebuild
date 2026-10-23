# r25 grade C: interactivity and feel

I judged from the code, checked against rivals_rec frames 0.3–1 s apart. The r25 captures are static, so they show no motion. Since r12, the only motion change is the token guard (commit 54e8ca4, r13). Every other commit was layout or type, so **nothing moved us away from RIVALS**.

## r12 fixes: did they land?
- **Token guard: landed.** `rivals/Kit.lua` 790–809 and `SettingsKit.lua` 842–861 now bump `_MotionToken` in `open` and check it before the delayed hide. The `done` hook runs only when the token still matches. A reopen within 0.12 s now leaves the panel up, keeps `gui.Enabled` true and leaves the blur to `setOpen`. The Play lock popup (`PlayScreen` 801–804) builds a new `group` each time, and a double hide (X plus shade) still destroys the shade through the second close. Correct.
- **Minor inconsistency:** `lobby/Kit.lua` 1051 still calls `done()` even when the menu was reopened. It's harmless, because every caller checks `if not isOpen`, but it should match the two ported kits.
- **Not landed:** open/close sfx in the two kits, Play tile sfx, hub dock sfx, the Shop scroll reset, the Missions Play button, the Kit row press restore and the 0.15 s backdrop on close.

## play: 8.5/10
1. `rivals/Kit.lua` `open`/`close` play no sound, so Play opens silently while Shop, Codes and Missions click. Add `TK.sfx("open")` / `TK.sfx("close")` at the top of each, as lobby/Kit.lua 1034/1044 does.
2. `bindTile` (702–733) has no hover or click tick. Add `TK.sfx("hover")` in MouseEnter/SelectionGained and `TK.sfx("click")` in Activated when the tile isn't Locked.

## settings: 8.5/10
1. Same open/close sfx port in `SettingsKit.lua` 842–861.

## kit: 9/10
1. Armory 1677: a press scales the row to 0.95 on MouseButton1Down. Nothing restores it on Up, so a picked row (where MouseLeave returns early) stays shrunk. Add `MouseButton1Up` → tween `row.hs` to 1.05 when hovered, else 1.

## shop: 8.5/10
1. `showTab` (1501) resets `Position` but not the scroll. RIVALS' tab pages open at the top (t0069.0), so add `P.pg.CanvasPosition = Vector2.zero` when the tab changes.
2. Scroll inertia: can't judge, because the frames are too far apart.

## missions: 9/10
1. The Play button `go` uses `RK.bindButton` (346), which is silent, while the reroll uses `Kit.bindButton` (223). Switch it to `Kit.bindButton(go)`.

## codes: 9.5/10
No fixes. The shake, busy dots, result pop and disabled → enabled pop are all intact.

## hub: 8.5/10
1. The dock `enter()` (LobbyHudController 657–668) lifts to 1.12 with a Back ease and a bobbing tip, but it plays no hover tick and Activated plays no click. Add `Kit.sfx("hover")` in `enter` and `Kit.sfx("click")` on Activated.
2. On close the panel is gone at 0.12 s while the blur and scrim still fade for 0.25 s. Use 0.15 s on close only (`on and 0.25 or 0.15`) in all five `setOpen`s (Play 1082, Settings 772, Shop 1541, Missions 562, Codes 238).

## Ranked by visible impact
1. Hub dock: hover and click sfx (the most-used row is silent)
2. Play and Settings: open/close sfx
3. Play tiles: hover and click sfx
4. Shop: scroll back to the top on a tab change
5. All screens: backdrop fade 0.15 s on close
6. Kit rows: restore the scale on press release
7. Missions: Play button through `Kit.bindButton`
8. lobby/Kit.lua: gate `done()` on the token like the two ported kits (consistency only)

Remaining feel gap worth another round: yes
