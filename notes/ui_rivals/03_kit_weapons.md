# 03 Kit / Weapons (armory): RIVALS feel audit (2026-10-21)

Sources: `rivals_rec/t0048-t0062`, `t0000-t0015` (Backpack), `t0094-t0106` (shop/emote popups); ours: `kit_tabs_fixed.jpg`, `kit_stats2.jpg`, `lobby_ui/sheet_phaseA.jpg` state 7; code `ui/lobby/Armory.lua`.

## What RIVALS does
- **Interactable:** on entry the side panels slide in from the screen edges over the item (`t0050.3s`: both columns half off-screen, then settled by `t0051.0s`). Picking a list row swaps the 3D item and the right panel together (`t0052`, `t0058`). A locked item gets a big 3D chain-and-padlock lock over a black silhouette (`t0054.3s`, `t0055.0s`). Popups scale-pop in over a dim, and toasts drop in from the top (`t0003.7s`, `t0004.8s`, `t0097.0s`).
- **Clean:** the right panel has three blocks: identity, progress (`16` bar, Level up, Reward at Level 50), and three same-shape actions (`t0052.0s`). Every action is a word plus one bright square button on the right. The slot strip shows only what applies: locked items show just Leave (`t0055.0s`).
- **Kid-friendly:** the price is on the button itself (`425 key`, `3 key`). There are three obvious next steps for a locked item: "Unlock now!", "Special offer!", "Try out for free!" (`t0055.0s`). There is a visible goal ("Reward at Level 50" with a thumbnail of the reward). The equipped cosmetic shows its own thumbnail in the slot (the cyan Wrap in `t0052.0s`). Empty slots show a plain "no" mark.

## Gap table
| Our element | RIVALS behaviour | Quality | Sev |
|---|---|---|---|
| Unlock row: price in the 16 px sub-line, lock glyph on the button, a second "SURE?" click | Price on the button, one press | Kid / Clean | P1 |
| Level card's 2nd row "Account level N" (not about this item) | "Reward at Level 50" + thumbnail: a goal for this weapon | Kid / Clean | P1 |
| `bigButton` press = face moves 2 px, hover 1.04, no sound | Chunky squash, Kit SFX (inferred) | Interact | P1 |
| Panels just appear (`ui.Visible = true`) | Columns slide in from the edges | Interact | P2 |
| Stats / History / cosmetic tray toggle `Visible` | Pop-in scale over a dim | Interact | P2 |
| Cosmetic slots: generic glyph even when equipped | Equipped cosmetic's thumbnail in the slot | Kid | P2 |
| Tray: four "Soon" circles, all looking the same | Locked cosmetics: padlock, still previewable | Kid / Clean | P2 |
| Level number set at once; the bar refills from 0 on every `renderInfo` | Bar fill + number count (inferred) | Interact | P2 |
| Headings in Builder Sans ExtraBold (`FONT_HEAVY`, l.808) | n/a, our own style rule: Montserrat Heavy | Clean | P2 |
| Four action rows; Inspect duplicates drag-to-turn | Three actions | Clean | P3 |
| 15 px stats sub-lines (l.1796), 14 px stat labels | Short, bold labels | Kid | P3 |
| Layout in `fromOffset` on a UIScale canvas (`fitHud`, l.1491) | n/a, rule: Scale only via `Kit.toScale` | Rule | P3 |

## Ranked changes
1. **Price on the Unlock button, one press.** In `renderInfo` (l.1955-1976), call `bigButton(r1, nil, afford, ctx.priceText(item.Price))` with the scissors glyph. Drop the `pendingUnlock` "SURE?" step: the scissors cut is the confirmation. When you can't afford it, the price shows in the off tone with a "Need N more" sub-line. **S.** No shared change. *Look:* field-green gradient, Montserrat number.
2. **Kit button feel in `bigButton` (l.1458-1467) and the slot strip (l.2195).** Use `Kit.bindButton(b, {hover = 1.06, press = 0.92})`, keep the 2 px face drop, and add hover/click SFX. Also apply it to the tabs (l.1713), History (l.1727) and `favBox`. **S.** Needs `Kit` required in Armory. Note that `mk` tags buttons `Nonapplicable` (l.865), so bindButton must be the only animator. *Look:* motion only.
3. **Swap "Account level" for "Reward at level X".** In `renderInfo` l.1942-1943, show the next item-level reward (from `ctx.Config.ItemLevels`) with an `itemRender` thumbnail. Account level belongs on the hub. **M.** Needs a reward table in Config if none exists. *Look:* same `cardRow`.
4. **Side columns slide in on enter.** In `Armory.Enter` after `ui.Visible` (l.2613), tween Profile/List from x-360 and `Right` from x+340 (0.35 s Quart Out, stagger 0.05). The bottom strip rises 60 px. Reverse on `Leave` before `tr.cover`. **S.** *Look:* unchanged panels.
5. **Pop-in for the Stats card, History and the tray.** Replace the `Visible` toggles (`renderStats` l.1781, `ShowHistory` l.2125, `openCosmeticTray`/`closeTray` l.2142-2154) with `Kit.open` / `Kit.close`. **S.** Needs Kit (anchors: `Kit.open` re-centres the anchor, so check that the bottom-anchored tray still sits in place). *Look:* motion only.
6. **The equipped cosmetic shows in its slot.** In `renderBottom` (l.2188-2192), when a Skin/Wrap is equipped for `selectedId`, draw an `itemRender` thumbnail in place of the glyph and keep the cream label. **M.** Hooks into WrapConfig (queued Wrap tab). *Look:* the cream glyph stays the empty state.
7. **Tray locked state.** In `openCosmeticTray` (l.2157-2167), locked entries get `padlock()` (l.1071) + "Coming soon", hover-grow and click-to-preview on the showcase. Default gets the tan ring. **M.** *Look:* drawn Frames, no amber.
8. **Level bar + count.** In `renderInfo` l.1926-1934, tween from the previous fraction (cache per id) and count the centre number with `TP.tweenNum` (l.564). Add a 1.15 pop on level change. **S.** *Look:* green gradient kept.
9. **Montserrat Heavy for headings.** At l.808, set `FONT_HEAVY = Theme.font.display` (item name, card titles, slot labels). Keep Builder Sans for body text. **S.** Needs `Theme` (matchplace/Theme.lua `font.display`); check the Kit-side Theme too. *Look:* this is our own spec.
10. **Three actions.** Fold Inspect into the item card as a small eye icon by the favourite box (drag still turns the item). The action card keeps Equip / Next unlock / Statistics; set `ACTIONS_H` (l.1765) to 3 rows and make the rows taller (70 px). **S.** *Look:* same cards, less clutter.
11. **Readability floor.** Raise stats sub-lines and stat-bar labels to at least 17 px (l.1796-1797, l.1902). Raise the tagline and description to 17 px (l.1861). **S.**
12. **Scale-rule migration (later).** Build the `hud` canvas in 1920x1080 and run `Kit.toScale(hud, Theme.design)` in place of the UIScale `fitHud`. **L.** Needs Kit.toScale to handle the AutomaticSize cards (noted at l.1876). *Look:* identical.

## Not verifiable from stills
- Slide-in timing and easing (inferred from one in-between frame, `t0050.3s`), popup duration (~0.2-0.3 s from `t0003.0`-`t0004.8`), and whether RIVALS buttons squash or only lift. Hover states are never visible in the recording.
- Whether the RIVALS level number counts up, and the chain-lock entrance animation (it appears fully formed in `t0054.3s`).
- Whether RIVALS plays sounds on hover or click (the recording has no audio review).
