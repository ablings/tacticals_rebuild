# r26 grade C: interactivity and feel

I judged from the code in commit 1d1bcae, checked against the rivals_rec frames. The r26 captures are static, so they show no motion. **Nothing moved us away from RIVALS.** One side effect: the five `MenuClosed → Kit.open(root)` handlers (Play 1070, Settings 793, Missions 545, Shop 1421) now play the "open" swoosh when the player leaves the Roblox Esc menu. Shop and Missions already did this before r26, so it's minor, but RIVALS doesn't re-announce a panel that was already open.

## Did the r25 fixes land?
- **Ported kits play sfx: landed.** `rivals/Kit.lua` 319–338 / 800 / 810 and `SettingsKit.lua` 333–352 / 852 / 862 call `uiSfx` (hover, click, open, close) through UIKit.Kit, so the 40 ms throttle and the shared pool apply. One bonus: Missions `go` (`RK.bindButton`, 346) now clicks too, which closes r25 fix 7. Gaps against `lobby/Kit.bindButton` (379–385): the port has no SelectionGained hover tick for gamepad and no `opts.silent`.
- **Shop scroll reset: landed.** `showTab` 1507 zeroes `CanvasPosition`. Because opening the Shop also runs `showTab` (1550, 1558, 1587), the Shop opens at the top too, which matches RIVALS t0069.
- **Hub dock sfx: not landed, even though the commit says so.** The five dock items (`LobbyHudController` 657–697) use their own `enter` / `Activated` with no `Kit.sfx` call. A dock click is only heard through the panel's open swoosh. The UI_hover sound the Studio check saw must have come from a `Kit.bindButton` control (Play/toPads 308, the top-right icons 150), not from a dock item.
- **Still not landed:** Play tile sfx, the 0.15 s backdrop on close, the Kit row press restore, and the lobby/Kit `done()` gate.

## hub: 8.5/10
1. Dock `enter()` (668) → add `Kit.sfx("hover")` after the `away()/hovered` guard. Dock `Activated` (695) → add `Kit.sfx("click")`.
2. `setOpen` blur/scrim: change `0.25` to `on and 0.25 or 0.15` in Play 1082, Settings 772, Shop 1542, Missions 562 and Codes 238. Today the panel is gone at 0.12 s while the backdrop lingers until 0.25 s.

## play: 9/10
1. `bindTile` (702–733) is still silent. Add `TK.sfx("hover")` in MouseEnter/SelectionGained, and `TK.sfx("click")` in Activated after the Locked check.
2. Lock popup `hide` (801): guard it with a `closed` flag so that X then shade can't play the snap twice.

## settings: 9/10
1. `bindButton` (351): add `SelectionGained → uiSfx("hover")` to match lobby/Kit 385. Same for `rivals/Kit.lua` 337.

## kit: 9/10
1. Armory 1677 still has no `MouseButton1Up` restore. Add `row.hs → hovered and 1.05 or 1`.

## shop: 9/10
No new fixes. Scroll inertia: can't judge, because the frames are too far apart.

## missions: 9.5/10
No fixes. The Play button now ticks.

## codes: 9.5/10
No fixes.

## Ranked by visible impact
1. Hub dock hover and click sfx (claimed in r26, still missing)
2. Play tiles hover and click sfx
3. Backdrop 0.15 s on close (all five screens)
4. MenuClosed re-show without the open swoosh (pass a silent flag to `open`)
5. Kit rows restore their scale on release
6. Gamepad SelectionGained hover tick in both ported kits
7. Lock popup double-close guard; the lobby/Kit `done()` token gate (consistency)

Remaining feel gap worth another round: yes
