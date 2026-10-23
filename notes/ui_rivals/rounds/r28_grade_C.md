# r28 grade C: interactivity and feel

I judged the code in commit 7b6388d against r27 (97a6c0f). There are no new captures, and the layout and look graders have signed off. **Nothing moved us away from RIVALS.** The r28 diff is 3 lines, in LobbyHudController and Armory.

## Did the r27 fixes land?
- **Dock hover inside `enter()`: landed.** `LobbyHudController` 661 plays `Kit.sfx("hover")` after the `away() or hovered` guard, and the second `MouseEnter` listener is gone. A pushed-away dock stays silent, a re-enter doesn't double-tick, and `SelectionGained → enter` (685) gives the gamepad its tick.
- **Kit rows spring back on release: landed.** Armory 1678 tweens `MouseButton1Up` to `selectedRowId == id and 1 or 1.05`. I checked for side effects: `Up` fires before `Activated`, so a fresh pick tweens to 1.05 first. Then `ClickItem → setSelectedRow → rowLook` rebuilds the old and new rows with a fresh `HoverScale` at 1 (1626), so no row is left enlarged. A re-click on the selected row goes 0.95 → 1. Clean.
- **Still open (carried, files unchanged):**
  - blur/scrim fade out at 0.25 s on close: Play 1082/1083, Shop 1542, Missions 562, Settings 772, Codes 238;
  - the `MenuClosed` re-show swooshes: Play 1071;
  - the lock popup `hide` has no guard: Play 802;
  - there's no `SelectionGained` hover tick in Play tiles (727), `rivals/Kit.bindButton` or `SettingsKit.bindButton`.

## hub: 9.5/10
No fixes. Hover, press, release, click and gamepad all run through one guarded path.

## play: 9.5/10
1. Backdrop `setOpen`: `0.25` → `on and 0.25 or 0.15` (1082/1083).
2. `SelectionGained` (727): add `Kit.sfx("hover")`.
3. `MenuClosed` (1071): re-show silently. A player only hears this after opening the Roblox Esc menu over Play.
4. Lock popup `hide`: add a `closed` flag. A double close only happens if X and the shade are both clicked within 0.12 s.

## settings: 9/10
1. `SettingsKit.bindButton` and `rivals/Kit.bindButton`: add `SelectionGained → uiSfx("hover")` (match lobby/Kit 385).
2. Same backdrop timing as play (772/773).

## kit: 9.5/10
No fixes. Row hover, press and release now match RIVALS t0052–t0058.

## shop: 9/10
1. Backdrop timing (1542/1543). Scroll inertia: can't judge from code.

## missions: 9.5/10
1. Backdrop timing (562/563).

## codes: 9.5/10
1. Backdrop timing (238/239).

## Ranked by visible impact
1. **Backdrop close at 0.15 s (5 screens).** The panel is gone at 0.12 s and the dim lingers until 0.25 s. This is the only remaining item a mouse player can notice, as a faint "tail" of about 0.1 s on every close. Most players won't consciously see it.
2. Gamepad `SelectionGained` hover tick (Play tiles, rivals Kit, SettingsKit). Only controller players notice, and only as a missing tick.
3. `MenuClosed` silent re-show. It is heard only after the Esc menu, which is rare.
4. Lock popup double-close guard. Practically unreachable.

## Verdict
Both r27 fixes landed with no regressions. What's left is sub-perceptual for mouse players: item 1 is a 0.1 s fade mismatch, and items 2–4 are edge cases on gamepad or Esc. None of them would make a player say the UI feels unlike RIVALS. Item 1 is a 10-line, 5-file change that can ride along with any future commit. It doesn't justify a dedicated round.

Remaining feel gap worth another round: no
