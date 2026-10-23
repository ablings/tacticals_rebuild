# r12 grade C: interactivity and feel

I judged from the code, checked against rivals_rec frames that are 0.3–1 s apart. There are no r11 grades in the folder, so I compared against r10. No lobby motion code changed since r10, so **nothing moved us away from RIVALS**.

The shared motion is close to RIVALS:
- **Buttons:** hover is 1.05–1.15 UIScale in 0.1 s; press is 0.93 in 0.06 s, then a Back ease out.
- **Panels:** open is 0.9 → 1 with a Back ease in 0.22 s; close is → 0.92 in 0.12 s.
- **Backdrop:** blur and scrim take 0.25 s. RIVALS also draws the panel before its blur settles (t0285.4).

## Bug (feel-breaking)
Play and Settings use `rivals/Kit.lua` and `settings/SettingsKit.lua`. Their `open`/`close` lack the `_MotionToken` guard that `lobby/Kit.lua` has (lines 1037–1051). If you reopen within 0.12 s of a close, the delayed `frame.Visible = false` still fires: the blur and scrim stay up, `isOpen` is true and no panel shows. Neither kit plays the open/close sfx either, so these two menus are silent while Shop, Codes and Missions click.

## play: 8/10
1. Port the token guard and `sfx("open"/"close")` into `rivals/Kit.lua` `open`/`close`.
2. Tiles (`bindTile`, 702–733): the hover wash, 0.97 shrink and ring match RIVALS, but there's no hover or click tick. Add `TK.sfx("hover")` on enter and `TK.sfx("click")` on Activated.

## settings: 8/10
1. Same token and sfx port in `SettingsKit.lua` 842–856.
2. The rail and row hovers are fine. The hover description panel matches t0136.

## kit: 9/10
1. The columns slide in from the edges, staggered 0 / 0.03 / 0.08 s, which matches t0050.3. The item swap (0.15 s out, 0.6 → 1 Back in) and the list scroll (0.38 s Quart) both feel right.
2. Rows press to 0.95 on MouseButton1Down, and nothing restores them on MouseButton1Up when the row is already picked. Add an Up tween back to 1.05/1.

## shop: 8.5/10
1. Tabs grow 1.15 and the carousel slides in 0.25 s. Buying shows busy dots and then Purchase Complete, as at t0073.4. Good.
2. Each tab keeps its own ScrollingFrame and its scroll offset. RIVALS' tab pages open at the top (t0069.0) → set `P.pg.CanvasPosition = Vector2.zero` in `showTab` when the tab changes.
3. Scroll inertia: can't judge. The frames are 0.3 s apart (t0155.3–0156.3).

## missions: 9/10
1. The bars fill and the counts run up on open, which is good. The Play button is bound with `RK.bindButton`, which is silent → use `Kit.bindButton`.

## codes: 9.5/10
1. The empty/wrong code shake, busy dots, result pop and disabled → enabled pop are all present. No fixes.

## hub: 8.5/10
1. Dock items lift 1.12 with a Back ease and a bobbing tip, but `enter()` (LobbyHudController 655–666) plays no hover tick and Activated plays no click. Add `Kit.sfx("hover")` and `Kit.sfx("click")`. It's the most-used row and it's silent while the menus behind it tick.
2. Close timing: the panel is gone at 0.12 s while the blur and scrim fade for 0.25 s. On close only, cut the backdrop tweens to 0.15 s so the room comes back with the panel (all five screens' `setOpen`).

## Ranked by visible impact
1. Play and Settings: open/close token guard (a stuck blur with no panel)
2. Hub dock: hover and click sfx
3. Play and Settings: open/close sfx
4. Play tiles: hover and click sfx
5. Shop: reset scroll on a tab change
6. All screens: backdrop fade 0.15 s on close
7. Missions: Play button sfx via `Kit.bindButton`
8. Kit rows: press release restore

Remaining feel gap worth another round: yes
