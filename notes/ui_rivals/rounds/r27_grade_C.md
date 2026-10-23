# r27 grade C: interactivity and feel

I judged from the code in commit 97a6c0f, checked against the rivals_rec frames. The r27 captures are static, so they show no motion. **Nothing moved us away from RIVALS.** The r27 diff touches only sound: 3 lines in LobbyHudController, PlayScreen and rivals/Kit.

## Did the r26 fixes land?
- **Hub dock sfx: landed.** `LobbyHudController` 695 plays `Kit.sfx("click")` on `Activated`, and 696 plays `Kit.sfx("hover")` on `MouseEnter`. Here `Kit` is UIKit.Kit (line 22), so the 40 ms throttle and the shared pool apply. One gap: the hover is a second `MouseEnter` listener and not part of `enter()` (658). Because of that it skips the `away() or hovered` guard, and a gamepad `SelectionGained` stays silent.
- **Play tiles sfx: landed.** `rivals/Kit.lua` 325 exposes `Kit.sfx = Kit.sfx or uiSfx`. `bindTile` plays hover at 725 and click at 731, after the `Locked` check. A locked Ranked tile stays silent on click, but `showLockCard` → `Kit.open(group)` gives it the open swoosh, which matches RIVALS t0285 (the card pops in). Same gap as the dock: `SelectionGained` (727) has no tick.
- **Still not landed (carried over):** the backdrop at 0.15 s on close (Play 1083/1084 still `0.25`), Armory 1677 has no `MouseButton1Up` restore, the `MenuClosed` re-show still swooshes (Play 1071), the lock popup `hide` has no double-close guard (PlayScreen 801–806), and there's no gamepad hover tick in `rivals/Kit.bindButton` (337) or `SettingsKit`.

## hub: 9/10
1. Move `Kit.sfx("hover")` from line 696 into `enter()`, right after `hovered = true` (660). Then a hidden dock (`PushedAway`) can't tick, a re-enter while hovered doesn't double-tick, and the controller selection ticks too.
2. `setOpen` blur/scrim: change `0.25` to `on and 0.25 or 0.15` in Play 1083/1084, Settings, Shop, Missions and Codes.

## play: 9.5/10
1. `SelectionGained` (727): add `Kit.sfx("hover")` so a controller sweep ticks like the mouse.
2. Lock popup `hide` (801): add a `closed` flag so that pressing X and then the shade doesn't play the close snap twice.
3. `MenuClosed` (1071): re-show without the open swoosh, for example `Kit.open(root, { silent = true })`. RIVALS doesn't re-announce a panel that's already open.

## settings: 9/10
1. `SettingsKit.bindButton` (351) and `rivals/Kit.bindButton` (337): add `SelectionGained → uiSfx("hover")` to match lobby/Kit 385.

## kit: 9/10
1. Armory 1677: add `MouseButton1Up → row.hs` tween to `hovered and 1.05 or 1`. Today a press leaves the row at 0.95 until the mouse leaves.

## shop: 9/10
No new fixes. Scroll inertia: can't judge, because the frames are too far apart.

## missions: 9.5/10
No fixes.

## codes: 9.5/10
No fixes.

## Ranked by visible impact
1. Backdrop fades in 0.15 s on close (5 screens). The panel is gone at 0.12 s while the dim lingers until 0.25 s, and you notice it on every close.
2. Kit rows restore their scale on release.
3. `MenuClosed` re-show without the open swoosh.
4. Dock hover moved inside `enter()` (guarded, gamepad).
5. Gamepad `SelectionGained` hover tick: Play tiles, rivals Kit, SettingsKit.
6. Lock popup double-close guard.

Every remaining item is a polish or consistency fix for close timing, release and gamepad. The main hover and click feel now matches RIVALS on every section.

Remaining feel gap worth another round: yes
