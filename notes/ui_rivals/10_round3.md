# 10 - Round 3, "match RIVALS" (2026-10-21)


## Round 3 (MISSIONS / SETTINGS / CODES)
Files: `ui/pseudolobby/hub/MissionsScreen.lua`, `ui/set/SettingsScreen.lua`, `ui/settings/SettingsKit.lua` (toggle only; closeButton untouched), `ui/lobby/CodesScreen.lua`.

**Missions**
- RIVALS t0062-t0066: Daily Tasks cards sit on a clean dark panel -> the cards left the navy-slate `C.panelRaised` for the charcoal-green `C.plate` (0.25); a claimable card is lit dark field green (34,52,24) with a 6 px field-green top stripe (`MissionsScreen.lua:76-80`, `:158`, `:162`).
- RIVALS t0062: title, glyph, wide bar, then "x / y" -> the count now sits UNDER the bar (Oswald 26, cream), never through it; done = field green "✓ 5 / 5" (`:164-180`). The bar is bigger (211 x 16) with a cream fill, done = field-green gradient (`:125-136`). Counts tick up with the bar fill on open via `Kit.countTo` (`:178-180`, `:359-362`).
- RIVALS t0062: the reward is a posed 3D key with "×N" under its corner -> live 3D scissors (no longer `still`: sways, turns to you on card hover), 62 px (was 44), with a big "×N" overlapping its lower right (`:138-150`, called at `:181`).
- Clear CLAIM state: ready card lit green + stripe + breathing + CLAIM sheen (kept); claimed now reads "✓ CLAIMED" in field green on a dark plate instead of dim grey text (`:184-189`). The claim pop's check is re-centred on the moved art (`:228`). CARD_H 258 -> 266 so both panels + footer still fit the 840 px column (834).
- RIVALS t0062 "To Duels" in the Daily Tasks header -> a field-green `PLAY` button (Kit.button "key") at the Daily panel's top right that closes Missions and calls `ctx.openPlay()`; the reset timer moves left of it (`:263-277`). **Hook missing:** `LobbyUIController`'s `MissionsScreen.Init` does not pass `openPlay`, and the file has no LobbyUI handle, so the button is guarded and does not show yet. To turn it on, add `openPlay = function() LobbyUI.Open("Play") end` to that Init table (not my file).

**Settings**
- RIVALS t0135.7: the switch has two states you can't confuse (flat track + dark knob left / filled + knob right). Reviewers: our OFF was hard to read -> `Kit.toggle` (`SettingsKit.lua:426-475`): ON = field-green #8DBF5A (light-to-dark gradient) track, cream knob right, white "ON"; OFF = dark charcoal track, grey knob left, cream "OFF" (Oswald 24 with a text outline). Chunky dark bottom lip, no hairline. Knob squashes and the word pops on each flip. SettingsTheme's `green` is still the old amber, so the field greens are local to the toggle.
- Rows react on hover (RIVALS t0135.7, the hovered row's plate lifts): the plate fills in and warms to dark field green, the label goes full white, the row icon tilts -10 deg (`SettingsScreen.lua:387-403`). No UIScale on list rows (would push neighbours).

**Codes**
- Reviewers: Redeem reads as disabled. Now two clear states (`CodesScreen.lua:119-149`): empty = a flat charcoal plate over the button under a faded word (clearly off); typed = full bright field-green gradient, word at full strength, a field-green glow block behind it, and a `Kit.pop` the moment it turns on.
- Success / error pop (`CodesScreen.lua:54-77`, used at `:79`, `:88`, `:92`): a solid chip pops in at the status line, field green "✓ Redeemed!" (dark ink, plus the reward sound) or red "✕ <reason>" (shakes, the box shakes too), holds 2.6 s and fades. Built after toScale in Scale of the panel; width follows the words.

Not verified in Studio (round rule: no Studio). Block / paren balance checked on all four files.

## Round 3 (MATCH HUD + FLOW + TUTORIAL FINISH)
Files: `ui/match/DuelHUD.client.lua` (no new main-chunk locals; still at 200), `ui/match/MatchFlowUI.client.lua`,
`ui/set/HotbarController.lua`, `ui/tutorial/TutorialController.lua` (finish PLAY only). Not run in Studio (agent rule):
checked by reading plus a block / bracket balance diff against HEAD (unchanged). Needs a play test.

- **Hotbar items are live 3D already.** RIVALS shows posed item renders that sit still in the tiles (t0112.0s, t0122.0s;
  imagery_A: "static ~45 px, no rotation"). Ours are ViewportFrames of the real models, so I kept them still like RIVALS.
  - **Bug fixed: the select kick never fired.** RIVALS' newly held item kicks up and a sweep crosses the tile. In
    HotbarController:1019, `wasOn` was read after `sl.selected` had been overwritten, so the kick and sweep never ran on a
    weapon switch. It is now read before.
  - **Bug fixed: the item dropped after its first kick.** The spring wrote Y.Scale = 0.5, which threw away the RENDER_LIFT
    that Kit.toScale had folded into Y.Scale, so the item dropped 10 design px after it settled. It now springs around its
    own rest height (`k.base`, :910). The weapon-feel numbers (spring, sweep, tint) are unchanged.
- **Spectate HUD.** RIVALS' spectate name bar answers each Q / E switch (t0113.0s, t0114.3s). When the target changes, the
  head now pops 0.7 -> 1 (Back): DuelHUD:349 is centre-anchored at the same spot, and the pop is at :406-411 in `setTarget`
  (a do-block local, not a main-chunk local).
- **Timers tick.** This closes group E's skipped "timer tick". The whole timer block (not timerL, whose Position is
  rewritten every frame) is centred once and pops 1.14 each second in the last 5 s of a live round, and 1.1 in the last 3 s
  of a countdown (DuelHUD:1467-1475). The state lives in `stats.timerBeat` / `stats.timerCentred`. The red < 5 s colour is
  unchanged.
- **Round end.** RIVALS gives you one bright action between rounds (`intermission_switch.jpg`). Switch Weapons now pops in
  when it appears instead of cutting in (DuelHUD:1510-1513, `RV.switchWant`).
- **Results primaries are chunky.** RIVALS' action buttons are bright and filled (t0113.0s, `round_lost_full.jpg`).
  - The results Play Again gets Kit.button's dark bottom lip (DuelHUD:822-825).
  - The after-match panel's Play Again was the last dark plate on group E's skipped list. It is now the same field-green
    gradient #8DBF5A -> #4C7A2E with cream words and the lip (DuelHUD:1049-1055).
- **Map vote: live 3D map pictures.** RIVALS shows a picture of every map.
  - The aerial map render now orbits slowly (MatchFlowUI:367, loop :986-1012).
  - A map with no image AND no model used to be an empty black tile. It now gets `miniArena(id)` (:263-310): a Parts arena
    (floor, walls, crates, a tower, a tan and a green spawn pad), laid out from the map id so each map looks different.
  - The tiles pop in one after another (:392).
  - The Random "?" rocks.
  - When the vote ends, the winner punches and its map spins up, and the losing tiles dim under a dark wash (:889-899).
- **Loadout / Switch Weapons: live items.** RIVALS' item tiles are posed renders (`switch_weapons_picker.jpg`). Ours are
  real models, so they move: every item render sways gently, and a hovered or pad-selected tile turns its item round, then
  eases back to the posed view (MatchFlowUI:568 registers the item; hover hooks :715-719; same loop). The slot's tiles pop
  in, staggered (:769-773). Picking, Random, auto-ready and test hooks are untouched.
- **Tutorial finish PLAY** (TutorialController:1220-1300).
  - The button was flat olive with a darker split. It is now the field-green gradient (#8DBF5A -> #4C7A2E) on a chunky
    solid dark-green lip block.
  - Cream Oswald words with a 3 px text edge, and a hover sheen.
  - Hover lifts it off the lip (1.04); a press sinks it onto the lip (0.95).
  - The drain is kept: the bright gradient shrinks over a muted copy of the same green, so it is still green and has no
    hard dark split. The countdown text is kept.
  - In the loading state the gradient fills back and the three dots sit on top.
- **Left alone:** Switch Weapons stays RIVALS blue (it copies RIVALS), the CombatFeedback / HUD weapon feel, and every
  remote and test hook.

## Round 3 (SHOP)
File: `ui/shop/ShopScreen.lua` only. Buying is unchanged: the same `ask("BuyBundle" / "BuyRobux" / "BuyPass")` calls, the detail card, `buying`, can't-afford shake, Kit-room prices, in-place owned updates.

New shared helpers in the file (l.94-173):
- `sceneArt(holder, ids, zoom)` (l.97) puts all of a bundle's items in ONE live viewport. Each item is scaled to the same size, they are fanned out, and the zoom makes the card edge crop them. It falls back to the Crate model.
- `reactArt(target, art, vp, tilt)` (l.125): on hover the art lifts 6 %, grows 1.08 and turns toward you (`vp.SetHover`), and tilts -5 deg unless it sits in a clipped card. On press it squashes to 0.88, then springs back. Gamepad selection does the same. It works in Scale after toScale.
- `wobble(g)` (l.152) rocks the stickers. One Heartbeat drives all of them and stops while the shop is closed.
- `valueSticker(...)` (l.168) is the red "xN VALUE" sticker that sits on the price.

Changes, each as RIVALS -> ours (file line):
- **Hero focus.** RIVALS' Home has one big Season Pass card with a huge cropped crest (t0072.0s).
  - The Featured hero card now shows one big cropped `sceneArt` of the bundle (it was three small viewports): l.521.
  - Title 46 -> 56. The LIMITED tag rocks. The 3D scissors sit next to "+N" at 40 px.
  - It has the biggest price on the page: 170x58 -> 250x84 (l.536).
- **Big readable prices.** RIVALS' price pills are mostly number (t0068.4s, t0084.0s).
  - Price text 0.62 -> 0.72 of the tag height, and its icon 0.6 -> 0.66 (l.197).
  - Tags are taller everywhere: gear cards 46 -> 54 (l.364); floating packs / gear 46 -> 54; Featured gear tiles 42 -> 50; bundle banners 58 -> 74; offer slides 56 -> 76; scissor packs 56 -> 66; passes 56 -> 68.
- **Bundle banners as 3D scenes.** RIVALS' Bundles tab uses full-bleed banners: a coloured backdrop, a cropped weapon render, and "xN VALUE" on the price (t0068.4s).
  - `bundleCard` (l.377) has a backdrop in the bundle's own colour fading to the panel, and a big cropped `sceneArt` (l.394) that lifts / turns on hover.
  - The value sticker moved onto the price (l.415). The Tag rocks.
  - The small 3D tiles stay bottom left, because they carry the OWNED marks.
- **Special Offer slides.** In RIVALS (t0072.0s, t0076.0s) the words and price sit on the left and a big cropped render sits on the right.
  - The pass slide has a 330 px Medal (was 150): l.557.
  - The bundle slide has a `sceneArt` with a value sticker (l.565 / 575) instead of three small tiles.
- **Keys-style pack tiles.** RIVALS' Keys tab tiles use a giant cropped key as the backdrop plus a huge "+N" (t0084.0s).
  - Scissor packs get a giant still 3D scissors backdrop, half see-through and cropped (l.692).
  - "+N" grew 52 -> 64 and moved top left. The pile lifts / squashes as one (l.698). The Tag rocks.
- **Pass / VIP card.** RIVALS' Season Pass crest is cut by the card edge (t0072.0s).
  - The pass cards now clip (l.730) and show a 230 px Medal, cropped top left, which lifts and turns on hover (l.735).
- **Every tile reacts.** RIVALS' tiles react to hover (t0083.9s).
  - `reactArt` is on: gear cards (l.358, which replaced the old grow + tilt), floating packs (l.489), floating gear, Featured gear tiles (l.647), bundle banners, the hero, and the offer and pass art.
  - Detail-card items turn when hovered (l.804).
  - A tab switch pops the page's tiles in one after another (l.1034).
- **Selected tab like RIVALS.** RIVALS' selected tab is white and its icon stands bigger (t0068.4s "Bundles", t0084.0s "Keys").
  - The selected tab's 3D icon grows 1.3x upward and stays turned toward you (l.1012). This is on top of the existing white fill and dark label.
  - Hovered unselected tabs brighten their dark plate and turn their icon (l.909-923).

Not changed:
- Palette: the bundle backdrops use each bundle's own Config colour.
- Fonts.
- No thin strokes or left bars were added.
- No new flat icons.

Checks:
- Blocks and brackets balance: 273/273 opens vs ends, parens 1089/1089.
- 7 new top-level locals (RunService, sceneArt, reactArt, wobbles, wobbleConn, wobble, valueSticker), far below 200.
- Not run in Studio (not allowed this round).

Things to look at in the next capture:
- How `sceneArt` frames each bundle. The fan spacing is 2.1 studs and the zoom is 1.2-1.3.
- The size of the pass Medal in the offer slide.

## Round 3 (HUB + PLAY + RANKED)
Files: `ui/hud/LobbyHudController.lua`, `ui/lobby/PlayRow.lua`, `ui/play/PlayScreen.lua`, `ui/ranked/RankedScreen.lua`. Code edits only (no Studio, no git). Kept the integrator's 3D nav viewports and the chunky gradient To Pads. Blocks and brackets balance in all four files (token check); no new top-level locals in any DuelHUD file.

- **PLAY as the call to action.** RIVALS: big lime Play, the brightest thing on the hub (`t0000`, `t0254.9`). We now have a field-green halo behind PLAY. It swells to 1.22x and fades every 2.2 s, and runs faster and stronger (0.9 s) when a match is found. It is off while busy, and the existing shine sweep still runs. It is a sibling behind the button, so the hover UIScale is untouched. `PlayRow.lua:42` (state), `:64` (halo), the pulse loop after the shine.
- **Nav hover (checked that it fires).** RIVALS: the disc lights, the item grows and lifts, a bubble shows (`t0188.9`, `t0254.9`). MouseEnter does reach the transparent nav button over its disc and viewport, and the bubble appears after the 0.55 s rest. Fixes:
  - the hovered item now draws above its neighbours (ZIndex 2), because the bubble could slip under the next item's icon or badge;
  - the bubble pops in from its pointer (`Kit.popIn`);
  - a controller's SelectionGained / SelectionLost now drives the same enter / leave;
  - resetNav restores ZIndex.

  `LobbyHudController.lua:455-500`.
- **Daily Missions widget.** RIVALS Daily Tasks (`t0000`): the name, an "n / N" count, a bar and the reward. Long mission names ran into the count, so the name now stops at 186 px when a count shows (236 px when done). When progress rises, the count punches (`Kit.pop`) while its bar fills. `LobbyHudController.lua:617`, `:650`, the fill loop after toScale.
- **Play mode tiles react.** RIVALS' tiles are lively art (`t0291`). A new `liven()` makes each squad react on hover or selection: the camera eases in about 10 % and turns slightly, and your team hops one after another. The enemy stays put. The connections are dropped when the viewport goes. `PlayScreen.lua:169` (liven), `:204` (livenSquad), plus the render loop.
- **Training / Lobby Duels live scenes** (RIVALS shows art there; `imagery_B` flagged "no art"). Both are built from parts:
  - Training (`PlayScreen.lua:252`): a straw dummy on a post with red / cream rings, a sandbag wall with your loadout gun resting on it, and a ring target board behind. The dummy sways, and rocks back as if hit when you hover.
  - Lobby Duels (`:317`): you (armed) and a dark mannequin face off on a duel pad over a field-green neon ring that breathes. Both hop on hover. It uses blocky stand-ins when there is no character.

  The Lobby Duels title moved to one line at the top so the fighters show. The Training copy was cut to "Cover, vaults, targets. / Try any gun for free!" at 24 px.
- **Locked Ranked tile = dark gold.** RIVALS keeps its Ranked tile's look behind the padlock (`t0291`). The gradient went from purple-grey (40,36,48)->(10,9,13) to a dimmer dark gold (84,64,30)->(24,18,8). The padlock now turns to you on hover. `PlayScreen.lua:555`, `:664`.
- **Ranked requirement card like `t0287`** (`PlayScreen.lua:402-490`). It is a dark card with a big RANKED title, then one line per requirement:
  - the words on the left;
  - an "n / N" count on the right that counts up;
  - a full-width bar that fills: white while short, field green with a green tick when met.

  Under the line is a "Play matches and finish missions to level up!" hint. As in RIVALS, the greyed PLAY (grey gradient on an offset lip; it shakes when pressed) sits **below** the card, and the red X sits beside its top-right corner. All three pop in as one group. Only the level line is listed, because that is the server's only ranked gate (`LobbyConfig.CanRanked`).
- **RankedScreen.**
  - Mode cards: each gets a live 3D squad (dark-gold enemies, hops on hover) behind "Ranked / 1v1", like RIVALS' mode tiles over art (`t0291`). It comes from the new `PlayScreen.SquadScene` export and is rebuilt on each open.
  - The cards pop in staggered.
  - The ELO bar fills (`Kit.fillTo`) and the ELO number counts up from the tier floor on open.
  - The Ranks / Leaderboard popups open and close with `Kit.open` / `Kit.close` (RIVALS' card pops in, `t0285.4`-`t0286`); they used to toggle Visible.

  `RankedScreen.lua:107-122`, `:168`, `:207`, `:296`, `:339-366`.

Not changed / notes:
- The hub mission icons stay 3D. `imagery_A` notes that RIVALS uses flat glyphs there, but the brief says to keep 3D unless switching is needed.
- `LobbyHudController` NAV Kit `Build` reads `data` before `local data` is declared (a global nil), so the Kit icon starts as the Pistol until the first refresh swaps it. This is harmless and was left alone.
- Not run in Studio. Check these in the next capture:
  - the Training scene framing (zoom 1.15, view -10 / -14 deg);
  - which end of the resting gun faces the dummy;
  - the duel pad scene at 322x214.

## Round 3 (KIT / ARMORY)
File: `ui/lobby/Armory.lua` only. Not run in Studio; checked by block / bracket balance (0 / 0 / 0) and a top-level local count (207 before and after: no new chunk locals; new state lives on the `Armory` table). The coordinator's two live-RIVALS corrections are folded in: the right panel keeps RIVALS' density, and empty slots plus the picker match live.

- **Selected weapon in the list.** RIVALS (t0018 / t0052, live): the picked row is a lighter band with bold white text and its render popping out to the right. Ours: the band is stronger (white 0.80, was 0.88) and adds a chunky 5 px field-green lip that grows from the centre with a Back ease. `rowLook` l.1528-1540, lip built in `makeRow` l.1572.
- **List hover.** RIVALS shows no hover in the frames, but the brief asks that everything react. Ours: a faint band, a short half-lit lip, the words grow 1.05 (own `HoverScale` UIScale on `Content`), locked names lift from near-black to grey, the Kit hover / click sounds, and a 0.95 squash on press. `makeRow` l.1580-1606.
- **Bottom slot strip.** RIVALS (t0018, live): Leave is a red X; an empty Skin / Wrap / Charm / Finisher slot is a grey rounded square with a slash and the label under it. Ours: Leave uses the red `leave` mesh glyph (was the cream X). Empty slots use the new `GLYPH.empty` (l.1133), a grey rounded square plus a slash with no stroke (it replaces the drawn pistol / swatch / crosshair / clapperboard). Hovering a slot lightens it and shows RIVALS' bubble ("Apply a wrap to this weapon", t0024). `renderBottom` l.2489-2530.
- **Selected state on the strip.** Live RIVALS doesn't light a slot: opening one *replaces* the strip with the picker. So ours does the same: the strip hides while the picker is open and pops back on Back. The picker's title ("Skin · Pistol") shows which slot is open. `closeTray` / `openCosmeticTray` l.2386-2410.
- **Cosmetic picker.** RIVALS (t0020 skins, t0026 wraps, live): a red Back button, then one row of ~100 px tiles. The first is "None": a dark tile with a slash and a big green tick. The rest are rarity-filled with a dark silhouette, a white padlock and the name at the bottom. Ours (`openCosmeticTray` l.2400-2487, tray moved to the strip's place at y 990, l.2662):
  - a red chunky BACK button (Kit.closeButton red plus a dark lip);
  - 9 tiles of 100 px. "None" has `GLYPH.empty` and a field-green check badge. The 8 locked tiles have a rarity gradient fill (Config.Rarities: Rare / Epic / Legendary), a darker lip and a cream padlock in the middle;
  - each locked tile holds a **live 3D placeholder**: a silhouetted ViewportFrame of this weapon tinted dark rarity, or for wraps a part-built wrapped cube. All of them sway (`Armory._sway` l.1888, one Heartbeat loop) and sway faster on hover;
  - pop-in stagger, bindButton hover / press, a bubble ("Epic skins are coming soon"), and a pressed locked tile shakes while its padlock jumps;
  - opening the picker closes Statistics / Duel History, which sat where the picker opens.
- **Right panel** (keeps RIVALS' density, per the live check):
  - Item card: name and checkbox, then two **single-line** bullets cut with "…". The full description is a cream hover bubble (`Armory._tip` l.1821: RIVALS' light pill with a pointer, shared, works with the gamepad too).
  - Ability: a solid field-green chip that brightens on hover; its sentence moved into the bubble.
  - Stats: **big stat bars** with 20 px Oswald labels and 14 px segments that fill one after another (were 14 px labels on 8 px bars). l.2025-2091.
  - Level card: the bar is 30 px. It fills from where it last stood for that item (not from 0 every re-render), and the level number counts up and pops when it changes (`Armory._lvl`).
  - "Account level" is replaced by RIVALS' **"Reward at level N"** row (next multiple of 5) with a live 3D placeholder: ViewIcons `Crate`, which sways and turns on hover. l.2093-2152.
  - Actions card: one row per action, like RIVALS' Contracts / Overview / Statistics. Each row has a title, a sub-line and a **bigger chunky field-green icon button** (112x54, was 100x50): Equip (check) / Unlock (price + scissors on the button), Inspect (eye), Next unlock (arrow), Statistics (eye / X). Enabled primary buttons glint (`Armory._shine`). Unusable buttons shake (except Equipped). l.2153-2245.
- **Kept working:** the one-press unlock flow (`Armory._unlocking`, Kit.busy, CutTape), Equip via `ctx.ask`, Inspect spin, Next unlock select, Statistics toggle, Duel History, slide-in panels, and ArmoryTestHook (untouched, l.~3040). Leave also hides any open bubble.
- **Not done / notes:**
  - RIVALS' picker search bar and "Favorited" checkbox (nothing to search until cosmetics exist).
  - The "cut to black ~0.3 s" entry (TRANSITIONS is untouched; the coordinator listed it as information only).
  - "Reward at level N" is a placeholder: there is no weapon reward table in LobbyConfig yet.
  - Needs a Studio check: the bubble width estimate (8.6 px a letter), the ViewIcons Crate in a 34 px cardRow icon box, the 9-tile picker width (1,080 canvas px) between the side columns, and that `GLYPH.empty` reads at 50 px.

## Integration (integrator, 2026-10-21)
- Deployed both places, all scripts compile, Play tour captured: `sheet_round3.jpg` (frames in `r3/`).
- Fix after the tour: Armory `COL.Dim` 24,27,22 -> 92,97,86, so locked weapon names read like RIVALS' grey rows.
- Kept on purpose: Ranked padlock (RIVALS' Ranked tile keeps its padlock, t0291), the dark TO PADS bar (secondary action),
  Settings tab icons popping above the bar (RIVALS' posed tab renders do the same).
- Not captured (needs clicks in Studio, which were not granted): the Kit cosmetic picker and hover states. Check these by hand.
- Still open: the own nameplate shows over the Kit character view (from before this round).

## Leaderboard board (2026-10-21)
- `ui/pseudolobby/hub/LeaderboardScreen.lua` rewritten after RIVALS' lobby board (06_leaderboards changes 1-5). Same part, Front face, 940x580 canvas; all Position/Size in Scale.
- Tabs Wins / Elims / Streak / Level (Kit.ICONS lb* flat icons, tinted), red LIVE pill that pulses. A tab shows only once its StringValue
  (`LobbyTopWins/Kills/Streak/Level`) exists; late values attach via ChildAdded. Selected tab is cream with dark text, others dark plates.
- Auto-cycle every 8 s (slide left + fade out, in from the right; the content is one CanvasGroup). Tabs are clickable (SurfaceGui in PlayerGui); a click pauses the cycle 20 s.
- #1 hero row: cream plate with a tan lip, yellow "1" badge (the only #FFD400), 100 px headshot, name, big number, unit (Level: "LV n" + "x XP").
  #2-#10 in two columns: rank, 44 px headshot, name, number right-aligned. Own row = field-green gradient with dark text. Empty -> "No one yet - be the first!".
- Numbers count up (NumberValue tween; from 0 on a category change, from the old value on refresh); rows pop in staggered (UIScale Back) on a change, and on refresh only rows whose player changed pop.
- Look: Oswald Bold / Rubik, chunky plates with a darker offset lip, no UIStroke, no accent bar, no Gotham. Brightness 1.25 (was 1.5) so the cream does not bloom.
- Check in Studio: CanvasGroup fade on a SurfaceGui (blurry text at 940x580?), icon tint on cream tabs, long names shrinking in rows, the LIVE pill size (100x38), hero headshot load.

## Auto-pay (2026-10-21)
- The server now pays every finished Daily / Weekly task by itself (`fix/quest_autopay.lua`: on join and every ~3 s, through the
  ClaimQuest handler, which sets `Claimed` and fires Notify's "Task Completed / You've earned xN Scissors!" banner). The UI follows RIVALS: no CLAIM click.
- Client state: `data.Quests[scope] = { Key, List = { { Id, Base, Claimed } } }`, progress = `data.Stats[def.Stat] - Base`. Both files now treat a
  task as done when `Claimed` OR progress >= Goal, and a paid task always reads full (a stat reset cannot un-fill it).
- `ui/pseudolobby/hub/MissionsScreen.lua`: CLAIM button, card breathe, CLAIM sheen, ReadyStripe, claim handler and the `ClaimQuest` call are gone
  (TweenService no longer needed). A done card: dark field-green plate, full #8DBF5A -> #4C7A2E bar, green "x / x", title in field green, and a round
  green check badge (gradient, cream check glyph) in the task glyph's place. Paid: the 3D scissors and "xN" dim and a field-green PAID sits at the bottom.
  Hover lift now on every card. `seen[scope:period:id]` remembers each task's state/progress: on a live refresh (screen open) the bar grows and the
  count ticks on from the last shown value, a task that just finished pops its check (Kit.pop), one just paid pops PAID (Kit.popIn) and the reward;
  `holdUntil` (0.5 s) keeps the next refresh from rebuilding mid-pop. Opening the screen still animates bars/counts from 0 with no pops.
- `ui/hud/LobbyHudController.lua` (Daily Missions widget only): CLAIM pill gone. Done row: name, full field-green gradient bar, green "x / x" count,
  the 3D green check in the reward's place; the check pops when the task finishes or its Claimed flips while the HUD is up (`hudFx.paid`).
- Not changed (outside the widget): the nav Missions badge and its red "Claim your reward!" callout still count done-but-unpaid tasks, so they can
  flash for up to ~3 s before the payout; LobbyUIController's rail badge (`claimableCount`) likewise. Candidates to remove next.
- Check in Studio: the check badge reads at 56 px over the card, the PAID tag + dimmed scissors, the pop when a task completes with Missions open
  (raise a stat with the admin tools), and that the widget's "x / x" fits beside the shortened (186 px) name.

## Hub screens (2026-10-21)
RIVALS pass on the in-world lobby screens (feel alive, clean, kid-friendly; our palette). Not deployed; the four files are the Studio copies.
Shared look: Oswald Bold headings / Rubik body (no Gotham), no UIStroke on panels, no vertical accent bars, chunky plates with a darker
offset lip, field green #8DBF5A -> #4C7A2E for primary, cream / tan text, olive for ranked, LIVE red kept, #FFD400 only for "most wins".
- `LobbyScreensController.lua` (Training, DuelsTV, DuelsSign, Likes, Ad; 1000x620 canvas TVs, 900x240 sign; Brightness 1.4 -> 1.25):
  - Helpers: `plate` (face + lip, centre-anchored holder), `pop` (UIScale 0.8 -> 1 Back), `countTo` (one NumberValue per label, ticks from the
    last value), `livePill` (red LIVE pill image, UIScale breathe 1 -> 1.07), `header` (green gradient plate + dark-green lip, shadowed cream
    title, tag and/or LIVE pill; replaces the yellow tab bar + blinking dot), `footer` (green call-to-action or dark info strip), `head`/`setHead`
    (round headshot chip, initial letter when the player is not in this server).
  - Training: LIVE pill; big count that counts up + "OPERATORS TRAINING NOW"; cards pooled per Player (only new players pop in, leavers removed,
    no full rebuild); own card on dark field green; green "BOARD THE HELI AT EXFIL" foot.
  - DuelsTV: rows pooled (maxRows built once; the 1 s clock only rewrites text). Row = green mode badge (olive + "RANKED" for ranked, else
    "CASUAL"), headshot + names per side, VS in tan, clock top-right, source under it (ON A PAD / ONLINE / OTHER LOBBY); pad countdowns read
    MATCH FOUND in red with the red strip. A row pops when its duel key is new. Eye + spectator count shows only if an entry carries `sp`
    (LobbyFeaturesManager does not publish it yet, so it stays hidden today). Foot: matches glyph, IN QUEUE, per-mode counts that count up.
  - DuelsSign: one lipped plate per mode (no thin yellow dividers), green mode, big count-up number, tan pads/online.
  - Likes: thumbs-up glyph (bumps when likes go up), count-up current, "/ goal LIKES" in tan, lipped bar with a green gradient fill that tweens,
    count-up %, reward line turns cream and pops on GOAL REACHED.
  - Ad: gadget glyph beside the reward text; status green when an ad is available. LF_AdReady / AdService check / LF_WatchAd prompt unchanged.
- `LobbyScreensFX.lua` (Signs.Screen_Brief_*/GunWall_*/Ranked): LIVE dot field green with a soft sine breathe (was a hard yellow blink);
  Ranked ticker in Rubik cream on a near-black strip (was Gotham violet), bullet separators.
- `LobbyLabels.lua`: station labels in Oswald / Rubik with a thick dark text stroke (title 3, sub 2.5), chunky green bar on a lip (was a thin
  accent line); Accent attr remap Teal -> field green, Magenta -> cream, Violet -> tan. NPC bubbles: square near-black plate + lip + tail
  (no UICorner, no stroke), sized in studs (6.5 x 1.9, was 260x70 px Offset), Rubik cream text, pop in, all parts fade out.
- `LobbyTickers.lua` (LobbyMap.Screens): LED tickers Rubik cream with RichText field-green keys and the top-wins name in #FFD400; the ticker
  countdown is "5H 12M" so the text changes once a minute (was every second, which nudged the scroll); seamless wrap (both halves end with the
  separator); scroll in Scale and now runs right-to-left (it ran left-to-right). Monitors: tan label, big Oswald value, tinted flat glyph
  (gadget / matches / lbElims / lbWins in gold), green gradient band at the bottom (was a thin bar); a card change pops, OPERATORS ONLINE counts up.
- Check in Studio: header title vs LIVE pill fit on the 1000x620 TVs, Duels row widths with 3v3 names, head initials, the ticker RichText
  TextBounds (scroll wrap), bubble size in studs at 10-40 studs, label green bar under long titles, monitor glyph tint and the gold wins glyph.

## Tutorial AI-tells cleanup (2026-10-21)
- `ui/tutorial/TutorialController.lua` only, visual pass: steps, remotes, control locks and timings unchanged.
- Fonts: Oswald Bold for words / keys / numbers (already), Rubik now Bold (was SemiBold) for the radio line and key captions. No Builder Sans left.
- Keycaps (strip, reticle, world marker, finish tiles): a real key, the face on a solid darker key side (`KEY_SIDE` = 14 % of the height,
  side = face colour 50 % darker via `paintFace`), was a translucent black drop shadow. The press spring now also sinks the face onto
  its side; amber / olive / cream recolour face and side together. The passive LOOK reticle got the same face + side.
- Objective strip: one opaque plate sitting on the state colour, which is now the plate's lip (~9 of 124 design px showing below, round the
  bottom corners), amber = do this, olive = done. Was a 0.15-transparent plate with a thin bottom bar. No left bar, no stroke.
- Strip motion (RIVALS): new objective words pop in (UIScale 0.85 -> 1 Back); a done step flashes a white wash over the plate and the words
  kick (1.12 -> 1) while the olive checked keys show, inside the same 0.6 s before the next step.
- Radio subtitle: slab (PLATE_HI) on a dark lip (PLATE_LIP), tighter corners (0.12), callsign tag and line lifted to sit on the slab; both
  resize to the words. Text strokes on the line (2) and world chevron (2.5) are legibility strokes on text, not frame hairlines.
- Kept: amber accent, the field-green PLAY with its lip, the thick zone ring, the hidden alert stroke (only ever 3 px, fades).
- Look at in a tutorial run: the key side reads on the cream / amber / olive keys at phone size; press squash + sink on Q / E / SPACE; the
  amber lip under the strip and its switch to olive with the flash; label pop not clipped by the CanvasGroup on long words (DASH TO THE
  CRATE, RUN + SLIDE); subtitle lip width tracks the words; the world marker key over cover at 10-40 studs; finish tiles' keys.

## AI-tells sweep (2026-10-21)
Final pass over `ui/` (not `ui/tutorial/`) for the three tells after the 09_cleanup groups. Visual only, not deployed, not checked in Studio;
each edited file passes a bracket / block balance check and stays well under 200 top-level locals.
- `ui/pseudolobby/hub/UITheme.lua` (Modules.Shared.UITheme): `Fonts.Bold` / `Fonts.Body` Gotham SSm -> Rubik Bold / Medium (`FontFamily` too);
  Display stays Oswald Bold. Style's legacy-font map reads these, so every old Gotham / Builder Sans label in the LobbyUIController gui lands on Rubik.
- `ui/pseudolobby/hub/Style.lua` (LobbyUIController/Style): highlight Border strokes were clamped DOWN to 2 px (it also thinned Tac's 4 px hover
  glow to a 2 px hairline); now grey / Panel borders still go, other Border strokes under 3 px go up to 3 (state rings), NoStyle strokes and
  strokes on a see-through frame (the padlock shackle glyph) are left alone. Covers the old LobbyUIController cards / tabs / queue pill.
- `ui/lobby/LobbyUIController.lua`: removed 3 left accent bars (centre-panel TacBar beside the title, 3 px olive bar on each redeemed code,
  4 px olive bar on the hidden PlayerCard) and the 2 px white ring on the dock's red Missions badge.
- `ui/lobby/Kit.lua`: `Kit.headerBar` TacBar (10 px left bar) removed, title moved in to 22 (as SettingsKit); colour picker R/G/B boxes lose the
  3 px left accent bar (as SettingsKit; the number keeps the channel colour).
- `ui/pseudolobby/hub/BillboardController.lua`: city billboards GothamBlack / GothamBold -> Oswald Bold (HEAD) / Rubik Bold (BODY) via FontFace.
- `ui/pseudolobby/hub/HotkeysPage.lua`: keycap face's 1.5 px edge removed; the darker cap under the face already reads as the lip.
- `ui/set/CoverController.lua`: cover hint label GothamBold -> Rubik Bold.
- `ui/pseudolobby/hub/Shop.lua`: fonts Gotham SSm -> Oswald Bold / Rubik. Its thin `stroke()` card borders are left: the module is the old
  LobbyUIController.Shop, no longer required anywhere (UIKit.ShopScreen replaced it), so restyling it would only churn dead UI.
- Left on purpose:
  - `ui/pseudolobby/UITheme_match_orig.lua` (Builder Sans / Gotham): a reference snapshot of the match place's original UITheme, not in any
    manifest or deploy list. The live match-place UITheme lives in that place; if it is still Builder Sans it needs the same font swap there.
  - `Style.lua` FONT_MAP keys `Enum.Font.Gotham*` / `BuilderSans*`: they are the inputs it converts to Oswald / Rubik.
  - Comment-only hits ("was Builder Sans", "no Gotham") in the already-cleaned files.
  - `Kit.crown` 1 px gold-edge strokes: they draw the crown icon's outline (glyph), not a card border.
  - `ui/pseudolobby/hub/Tooltip.lua`: already restyled by the Tooltip pass this round (cream pill + tan lip, no border / left bar).
  - Glyph / HUD strokes already reviewed in 09_cleanup (crosshair, rings, scope rim, Armory icons, FlatIcons, LoadingScreen shockwaves) and
    every text-legibility stroke.

## grade1 fixes: Settings (2026-10-21)
Graders compared `notes/ui_rivals/grade1/settings.png` with RIVALS' cleanliness. Edited only `ui/set/SettingsScreen.lua` and
`ui/settings/SettingsKit.lua`; not deployed, not checked in Studio. Both pass the bracket / block balance check (18 / 20 top-level locals).
- Sliders: one number, two controls. The ▲▼ stepper is gone (`Kit.stepperSlider` is now `Kit.slider`, old name kept as an alias;
  `row.arrow` is ignored). The value chip stays a TextBox (click it to type; rounded to the step on FocusLost), cream on a tan lip.
  Track 6 -> 10 px, charcoal with a field-green fill up to a round 28 px cream knob; the track starts under the row label. While
  dragging the chip pops to UIScale 1.08 and the number ticks live; it settles back on release. Still knob-only drag (RIVALS).
- Flattened the boxes: section headers are plain Oswald 34 px cream text, no bar (`Kit.headerBar`, 52 tall, gap before a section
  32 -> 20). Every row plate is the full 772 width (was 772 / 734 / 695 / 657 by level); sub-rows (level 2 / 3) only indent icon,
  label, reset button and slider track by 24 px per level. Row heights: 88, sliders 132, regardless of level.
- Tab icons: `Kit.imageTab` puts the icon in its own box at the top of the tab (3 px top pad, 30 px label at the bottom, 5 px gap),
  so nothing overflows. Tabs 136x54 -> 136x96; the tab bar grew upward (y 71 / 76 tall -> y 39 / 108 tall) so its bottom stays at 147
  and the list, rail and HotkeysPage (fixed at y 160) don't move; the red X re-centred on it (y 59). Selected tab: dark label, no
  stroke, on the cream plate.
- Toggles: the screen did use the round-3 SettingsKit toggle; its square grey knob on charcoal read as "a grey square". Now a 96x40
  pill on a 4 px dark lip (sibling, no stroke): round 32 px knob, Oswald 22 ON / OFF on the free side, field green #8DBF5A -> #4C7A2E
  with a cream knob when on, charcoal with a grey knob when off. Slide / squash / word pop kept.
- Page rail: a cream "PRESETS" caption (Oswald 20) above the rail, and hover bubbles "Preset 1/2/3" and "Share / import" (same white
  left-pointer bubble as the profile-switch one; it yields to that bubble). Function unchanged.
- Look at in Studio: tab icons at 56 px (3D ViewIcons fill the box; the Account headshot fits), slider chip pop while dragging,
  sub-row indent reads as hierarchy without plates, toggle word fits "OFF" at small screens, PRESETS caption clear of the top bar.

## grade1 fixes: Kit (2026-10-21)
File: `ui/lobby/Armory.lua` only. Not run in Studio. Bracket balance OK; top-level locals 180 before and after (new state lives on
the showcase entries / `Armory` table / inside functions).
- **Hero.** There is no "character view" in the Kit. The screen always shows the real item model in the Showroom
  (`SHOWCASE_WORLD`, `showItem` -> `renderShowcase`, LIT / DARK silhouettes). The avatar in `grade1/kit.png` (and `r3/kit.png`, a lobby
  background with your own nameplate) came from the camera being handed back to Roblox's Custom camera while the Kit stayed open.
  Studio MCP `execute_luau` calls do this when they return (`notes/ui_shadow_deploy.md`). Fix: once the reveal ends, `renderShowcase` holds
  the camera on `CameraPoint` every frame (Scriptable, FOV 40), so the gun is the centre hero whatever touches the camera. Re-capture
  with a real window screenshot.
- **Selection pop.** The new item pops in where it stands (scale 0.6 -> 1, Back, 0.25 s, the real model `ScaleTo`'d only while the
  value moves). The old item shrinks away in 0.15 s. This replaces the 0.55 s slide across the room. The idle sway and bob are unchanged.
- **Open transition.** The configured `WhipPan` (0.74 s) and the `Doors` fallback (~1.7 s) were too slow. New `TRANSITIONS.Cut`
  is the default: 0.08 s to black, 0.07 s held, 0.18 s reveal (0.33 s). `LobbyConfig.ArmoryTransition` is no longer read. The
  other transitions stay reachable through the player's `ArmoryTransition` attribute.
- **List.** One padlock, on the left of a locked name (was one either side). Section headers are a full-strength cream Oswald title
  with a text outline. The two ghost guns are gone. The dotted rule stays.
- **Right panel.** The Inspect button uses `Kit.ICONS.eye` (the "eye" glyph used to map to the Magnifier mesh). The Statistics button uses
  the drawn bar chart its row shows on the left. Equipped is a field-green chip with a check and "EQUIPPED" (bigButton tone
  `equipped`). It still can't be clicked and has no hover or press.
- **Level card.** One 22 px bar shows "LV n" on the left and "250 XP TO LV 2" on the right (LOCKED / UNLOCK TO EARN XP and LV n / MAX
  LEVEL states too). The "Level up" row and the 0 / 250 ends are gone. "Reward at level N" moved up, and `LEVEL_H` went from 176 to 110.
- **Profile card.** One headshot inside the card's top-left (56 px), with the name beside it. This replaces the AvatarBust whose head floated over the card.
- **Description bullet.** It shows the first sentence only and wraps to at most 2 lines, with no mid-word cut. The full text is still the hover bubble.
- **Picker tiles.** A small Rubik name line ("Pistol Skin" etc., placeholder) sits above the rarity.
- Check in Studio: the camera hold doesn't fight the Inspect / zoom feel. The EQUIPPED chip fits 112 px. The eye image reads at
  34 px on green. The name line clears the padlock on 100 px tiles.

## grade1 fixes: hub (2026-10-21)
Files: `ui/hud/LobbyHudController.lua`, `ui/hud/NameplatesController.lua`. Not run in Studio. Bracket balance OK; `Start` is ~80
one-tab locals (well under 200).
- **Nav bubble.** It now shows after 0.12 s (was 0.55 s). Tips are one line: "Weapons & skins", "Earn scissors", "Buy gear",
  "Redeem codes", "Controls & graphics". The width is measured from the text (TextService, Arial Bold 21 + 34). Placement keeps clear of
  PLAY (design x 784-1276 incl. the party avatars, y 838-922). Kit's bubble stays just above its icon, slid left so its right edge is at
  x 780. Missions / Shop / Codes / Settings raise theirs to sit 10 px above PLAY's top edge (bottom at y 828), with the pointer on the
  icon's x. The hovered icon now climbs 10 px more inside its button, so the 1.12x icon no longer runs into its own label.
- **Nav icons.** Each dock viewport's Ambient went from 150 to 196, the LightColor is white, and the key light comes from the camera
  side. The default light direction lit the models from behind, which caused the black-on-black pistol. Discs are a translucent mid
  grey (#5A5E58 -> #2A2D29, 0.6-0.35) instead of black.
- **Badges.** The Missions badge counts daily missions not finished yet. It used to count claimable missions, which is always 0 with
  auto-pay. The badge is a 26 px red circle with white Oswald 18 at the icon's top-right. It pops in 0.8 -> 1 (Back) after 0.15 s + slot
  stagger and bobs 3 px (Sine 0.9 s). It punches when the count changes. Kit has no badge: there is no "new unlock" signal in the code.
- **Daily Missions widget.** The box is gone. It is now a black wash that fades out to the right (0.62 -> 1) behind outlined text,
  and it is 460 wide (was 372). Names show in full: a 262 px column at Rubik 20, stepping down to 18 / 16 for long names ("Get 3
  eliminations from cover"). Icons are the flat cream glyphs from the Missions screen (FLAT_STAT -> Kit.ICONS) at 26 px. The reward
  sits on one line: a 22 px 3D scissors + "×150" in Oswald 18. The bar track is cream at 33% opacity, 8 px tall. The 3D stat-icon
  code is gone. TO PADS is renamed "» DUEL PADS «", and the button is 236 wide.
- **Player list.** Its height is 34 + rows×40 + 4 (78 for one player), up to 432 (40%), then it scrolls. The x and the column icon
  moved into a fixed 34 px Header strip, so they don't stretch when the height changes.
- **Nameplates.** The @username line only shows when it differs from the display name (case-insensitive), for everyone. Without it
  the name row sits lower (0.3). Your own plate is 55% size (4.95 x 1.1 studs, offset 1.6).
- Check in Studio: (1) hover each dock item. Each bubble should appear almost at once and never cover the PLAY label. Kit's should sit
  left of PLAY. Check whether the raised bubbles read as belonging to their icon. (2) The Kit pistol should read on its disc, and no
  icon should look washed out. (3) The Missions badge should show 3 on join, pop in and bob. (4) Check the widget's legibility over the
  bright hub floor without the box. Check that "Get 3 eliminations from cover" fits, and the flat glyphs (cover / lbElims) at 26 px.
  (5) The player list should be one row tall in solo; Tab hide / show should still slide it. (6) Your own nameplate should be small
  and show one name.

## grade1 fixes: Shop + Missions (2026-10-21)
From the grade1 sheets (`notes/ui_rivals/grade1/shop.png`, `missions.png`) vs RIVALS t0070 (shop) / t0062 (tasks). Code only, not deployed,
not checked in Studio; both files pass the balance check (ShopScreen 60 / MissionsScreen 45 top-level locals).
- `ui/shop/ShopScreen.lua`
  - Scissors price tags: same shape / height as the Robux tags, dark field-green plate (#3F6527 -> #22381A) with a cream Oswald number
    and the cream flat scissors (`Kit.ICONS.scissorsFlat`); every tag has a dark bottom lip. Can't afford = the whole tag at ~50 %
    opacity + the existing shake on press (the red number and black overlay are gone). The detail card's price dims instead of going red.
  - One card language: the Founder's hero is the offer panel's dark plate (black 0.25, corner 10) with the bundle colour as a glow from
    the right edge (field green: the Founder's product has no Color in LobbyConfig). New `shopTile` = one dark plate (#262A21 -> plate)
    + rarity bar along the bottom; used by the scissor packs, the left gear row (was floating renders) and the right gear grid
    (was navy), price tag 146x50 under each. Arms cards, scissor cards, pass cards and detail tiles left navy `panelRaised` for the
    same dark plate; Arms cards' rarity stripe moved to the bottom edge.
  - RIVALS Keys hover (`packHoverSwap`): over a scissors pack (Featured row and Scissors tab) "+500" swaps to scissors icon + "×500"
    and the tile brightens ~15 % (white sheen at 0.85); restores on leave / selection lost.
  - Fixed a pre-existing slip: the page ScrollBarImageTransparency had slid into a comment.
- `ui/pseudolobby/hub/MissionsScreen.lua`
  - Big "MISSIONS" title and the "Play matches to fill these up." footer removed; the column moves up (y 204 -> 130). The red X sits
    in the Daily panel's top-right corner (72x52, 14 px in).
  - Header: icon + "Daily Missions" left, the reset timer a small tan Rubik line under the title; PLAY -> `Kit.button` 150x52
    "GO PLAY" left of the X with a 20 px gap (still only when `ctx.openPlay` is passed).
  - The faint 1 px panel edge was the Frame's default border (no UICorner on the panel): `BorderSizePixel = 0`.
  - Task glyph ~20 -> ~36 px (Art 50 -> 64 tall, flat icon fills it); bar track cream at 35 % opacity, 10 px tall, so 0 / N still reads;
    the title grows 1.1x on hover with the lift; reward "×N" 32 -> 42 design px, beside the 3D scissors. CARD_H 266 -> 286.
- Look at in Studio: tag legibility at phone size (cream on dark green), the 50 % short tag over the blurred lobby, the hero glow vs
  its green price button, the swap row width on the Featured packs (158 px hold), the X / GO PLAY spacing at 1366 px wide.

## grade1 fixes: Play screen like RIVALS (2026-10-21)
Source: the RIVALS Play screen seen live tonight (`rivals_live_notes.md`, "Second live session") vs `grade1/play.png`.
Only `ui/play/PlayScreen.lua` changed (the Ranked tile is built there; RankedScreen untouched).
- **Layout:** a tall hero tile on the left = TRAINING (our beginner mode, 420 x 590), then 1v1 / 2v2 / 3v3 on the top row
  (330 x 290) and DUEL PADS + RANKED (500 x 290 each) below. The 1440 x 590 block is centred on the 1920 x 1080 canvas
  (was hugging the top with empty space under it). The red X sits 12 px outside the block's top-right corner, level with its top.
- **The tile is the button:** the PLAY x3 / ENTER / TO PADS strips are gone; clicks unchanged (queue with the party checks + Whoops,
  cancel while searching, Training -> enterTraining, Duel Pads -> toPads, Ranked -> lock card / openRanked).
- **Status:** no more "0 SEARCHING" pills. A chip at the tile's top centre only when it has news: "Searching m:ss - tap to cancel",
  "Match found!" (green), the failed-queue flash (red, 5 s), or "N searching" when N > 0. While you queue / stand on a pad the
  tiles you can't use dim (Training says "Not while searching" / "Not while on a pad").
- **Scenes:** every scene fills its tile and is lit like a picture (`lightScene`: ambient 196, warm key light from the camera side;
  ViewIcons' default light came from behind the scene, which is why squads read as black silhouettes). The other team is a rust
  mannequin (ranked: gold), was near-black. The camera is lowered (raise 0.3-0.4) so figures sit above the title.
- **Titles:** ONE huge cream (#ECE6D2) Oswald Bold title per tile, lower centre, solid dark stroke (size / 22). Subtitles only
  where they help a kid: Training "Try any gun for free!", Duel Pads "Fight people here". "Lobby Duels" renamed DUEL PADS.
- **Hover / select:** white sheen to ~15 % (brighter tile) + a 4 px cream UIStroke, only on hover or a controller's selection
  (no resting border); scale 1.03, press 0.96; the squad hop / dummy wobble / pad glow stay.
- **Open:** tiles pop in 0.028 s apart with a 0.16 s Back tween (six tiles <= 0.30 s; Kit.popIn's 0.24 s x 0.04 s took ~0.44 s).
- **Ranked locked:** dark gold kept; a 70 px padlock over "RANKED", one line "LEVEL 50", a 16 px bar with "LV n / 50" on it
  (was UNLOCKS AT LEVEL 50 + a big padlock + LV 1 / 50: the same thing twice). Unlocked: a normal tile (trophy scene + RANKED).
- Party column, preloading, Kit.toScale, lock card unchanged. Parse OK, 81 top-level locals.
- **Look at in Studio:** squad zooms on the squarer tiles (1.0 / 1.1 / 1.12) - 3v3 edges may clip; the training scene in the tall
  hero (zoom 0.88, raise 0.4); title vs figures overlap; chip text wrap for long flash messages; the 15 px count on the 16 px bar.

## grade2 fixes: hub (2026-10-21)
Files: `ui/hud/LobbyHudController.lua`, `ui/hud/PlayerCards.lua`. Code only, not run in Studio. Parse OK; about 97 one-tab locals in `Start` (under 200).
- **Nav bubble (like RIVALS).** Every bubble now sits over its own icon. The pointer tip is 8 px above the disc top and on the icon's x.
  The grade1 "raise over PLAY" placement is gone. While any dock item is hovered, PLAY yields: PLAY, your avatar, the + and the party
  heads go to UIScale 0.94 and fade halfway (Background / Text / Image / stroke transparency) in 0.12 s, and come back on leave. They are
  found by name in `PlayRowUI` (the base transparencies are stored per instance). The bubble draws above PLAY because LobbyHud has
  DisplayOrder 7 and PlayRowUI has 6. The bubble's bob is 5 px (was 18).
- **Hover lift.** The whole dock item (icon + label) moves up 6 px (Quad, no overshoot). The button no longer scales 1.12. Only the
  icon grows, to 1.10, through its own UIScale. The icon holder is anchored 3/4 down, so most of the growth goes up: the icon top
  ends at about 924.5 design px, below PLAY's bottom (922). The 10 px icon climb into the label is gone. The disc brightens with a
  cream layer at 15 % (was field green at 40 %).
- **Icon colour.** Each model's parts are pulled 45 % toward one base colour: Kit olive/steel #7E8B5C (kept when the gun changes),
  Codes tan cream #E2CF8E, Settings orange tan #D9A160. Missions and Shop are unchanged. Viewport Ambient is 220 (was 196).
- **Daily Missions widget.** The reward has its own column (x 384-458): 28 px scissors + "×175" in cream Oswald 22. The wash is a
  CanvasGroup: black at 0.55 opacity on the left, clear by 70 % of the width, and faded at the top and bottom 10 %. No corner, no box
  edge. "DUEL PADS" has no chevrons. Rows are sorted by the mission's index in `Config.Quests.Daily.Pool`, then by list index, so
  their order is stable across refreshes. The header keeps the 3D clipboard: Kit.ICONS has no clipboard / missions glyph.
- **"Join a match!" pill.** A cream pill with a darker tan lip and a pointer sits above PLAY (bottom at design y 818). It bobs 4 px
  over 1.2 s. It shows while `Stats.MatchesPlayed == 0` and the player has not queued this session (`MM_Queue` set once), or for the
  first 60 s if the stat isn't loaded. It hides while a dock item is hovered, while PLAY is off, in the Kit room and while pushed away.
- **Currency.** One dark plate (#262A21 -> #14170F, 220x54) with a 6 px darker lip holds the 3D scissors, the cream Oswald count and
  the field-green +. The count still counts up (Kit.countTo), and the plate punches 1.1x when it rises.
- **PlayerCards.** "Double tap to view profile" only shows over OTHER players. Double-clicking yourself still opens your card.
- Check in Studio: (1) hover each dock item. PLAY should shrink and fade, and the bubble should sit right over its own icon. Kit's
  bubble should not run off the left edge. (2) The hovered icon top should stay clear of PLAY, and the label should not be covered.
  (3) The tinted icons should read in colour and should not be muddy (Kit pistol olive). (4) The wash should fade with no visible
  edges. Check that "×175" is legible. (5) The join pill should not touch the PLAY halo pulse (halo top ~829). (6) The plate +
  should still open the Scissors shop.

## grade2 fixes: Shop + Missions (2026-10-21)
From `notes/ui_rivals/grade2/shop.png`, `missions.png` vs RIVALS t0070 / t0062. Code only (not deployed, not seen in Studio);
parse OK, ShopScreen 62 / MissionsScreen 52 top-level locals.
- `ui/shop/ShopScreen.lua`
  - **No dimming:** the grade1 50 % tag is gone (12 of 15 tags looked disabled with 500 scissors). Tags / tiles stay solid; can't
    afford = the price number in muted tan #B8A77A (`SHORT_TAN`), and on press the existing shake + a 0.4 s red flash of the number
    (`flashShort`). Same on the detail card's price (was 45 % transparent).
  - **"White specks":** not UI. The specks at (689,401-403) and (771,505) in shop.png, and the tick / specks by "Weekly Contracts" in
    missions.png, are alpha-0 pixels in the capture PNGs (RGBA, a=0, shown white by the viewer). Nothing in either screen draws
    there. The capture step should flatten alpha onto black before grading.
  - **Tile = tag width:** gear tiles 114 -> 146 wide (the price tag's width), left row at x 6 (tag centred at 79), right grid at
    x 2 (tag centred at 75); the render sits in an inset Art frame (130 x 80/86) clear of the rarity bar.
  - **2X SCISSORS card:** the medal was a 330 box at zoom 1.25 (huge, cropped): now 200 at zoom 1 = ~178 px, ~55 % of the card,
    right-aligned 44 px in; the offer panel gets the Founder's field-green glow from the right edge (`OfferGlow`, all slides).
  - **Founder's card:** LIMITED is a readable chip (Oswald 30 design px, ~22 px at 1436, padded 14); scissors render 100x74 ->
    132x96 and "+1,000" 40 -> 58; a cream Rubik line names the bundle's items under it, filling the empty bottom-left.
  - **Pack renders vs "+500":** pile 104 -> 52 tall at y 4 (ends at 56), "+N" moved to y 64 at 28 px: ~8 px between them.
  - **Page dots dropped:** only the offer panel carousels; the slides still auto-advance every 6 s and pause on hover.
- `ui/pseudolobby/hub/MissionsScreen.lua`
  - **Cards read as three:** 24 px side padding, 10 px gaps, cards 243 -> 253 wide (`CARD_W`, x 24 / 287 / 550); panel fill
    0.5 -> 0.15 opacity (`PANEL_T` 0.85) so there is one dark layer, the cards.
  - **Titles:** a fixed 52 px two-line box, bottom-aligned, so glyphs / bars / counts line up across cards.
  - **Weekly = a RIVALS Contracts list** (`taskRow`): 70 px rows, 8 px apart: glyph | name over a wide bar | "x / y" right |
    3D scissors "×N" right. Done = field-green name + full green bar + a green check badge on the bar's right end; paid = the
    reward dims + small PAID under it; same pops / count-up / tooltips as the cards. Panel height follows the row count.
  - **GO PLAY:** still `Kit.button("key")` (field green + lip); its label loses the 2 px chunky stroke for Oswald + the price tags'
    soft drop shadow (black at 0.75, 2 px down).
  - **"Next" cue:** when no daily is done, the first unfinished daily card gets a cream 3 px inner outline (inset frame) whose
    alpha loops 0 -> 1 over 1.0 s (Sine, reversing). No resting border on the other cards.
- Look at in Studio: the medal size / glow on the 2X card; the Founder's contents line vs the scene render (wrap at 440 px);
  the left-row renders in the wider tiles; Weekly row widths at 1366 (the "×1000" column); the cue under the hover glow.

## grade2 fixes: Kit + Settings (2026-10-21)
Edited only `ui/lobby/Armory.lua`, `ui/set/SettingsScreen.lua`, `ui/settings/SettingsKit.lua`. Not deployed, not run in Studio.
Parse check OK; top-level locals Armory 180 / SettingsScreen 18 / SettingsKit 20 (unchanged). New state lives on `Armory.*` or inside functions.

**Kit**
- Hero lighting: world-mode `ShowcaseKey` spot 2.2 -> 1.55 (~30% down), viewport-mode `LIT.LightColor` 250 -> 184; new `ShowcaseRim`
  (cool spot, 1.2, range 12, no shadows) behind and above the item, aimed back at it. New `Armory.ShowcaseLook(model)` runs on the
  showcase CLONE only (owned items): light-grey (Smooth)Plastic -> Metal gunmetal (HSV 0.58 / 0.08 / 0.16 + 0.2 * v, keeps relative
  shade); Highlights removed; textured parts (TextureID / SurfaceAppearance / Decal / Texture) lose Neon so the texture isn't washed out.
- Ghost "x 51": not UI. It is the "7.62 x 51" stencil on the Showroom AmmoCrate (`fix/polish_showroom2.lua`), blurred behind the
  left panel. `Armory.HideGhostLabels()` (called in Enter) disables that SurfaceGui client-side; the map is unchanged.
- Renders inside bounds: list row buttons `ClipsDescendants`; render 74x54 at the row's left (x 44) / picked 104x70 at the right
  (LIST_W - 58), scale-only pop (rotated children don't clip). Info-card render 44x36 inside the card left of the name (was poking out
  over the top-left corner).
- Next unlock: sub-line = the weapon name only; the price + scissors sit on the button (like Unlock); bubble "Go to <name>".
- Type: stat names 20 -> 23, bullets 17 -> 19, ability chip 18 -> 21 (chip 32 tall), level bar 22 -> 28 tall with LV 21 / XP 19,
  cardRow sub-lines 16 -> 18.
- Bottom strip: no plate, no brackets (see-through holder); discs + labels only.
- Left list: one `ListPlate` (panel) ends 16 px above the bottom; the ScrollingFrame is its child (6 px inset); section boxes are
  see-through. The slide-in now moves the plate. `SCROLL_PAD` is unused (kept so the local count doesn't change).
- Favourite box: it does work (ctx.ask Favorite); it now has a "Favourite" hover bubble.
- Picker: opening it re-asserts the camera hold (Scriptable, CameraPoint, FOV 40). Tile name line 13 -> 17 and just the cosmetic
  word ("Skin"); tiles pop in staggered 0.028 s, 0.16 s Back from 0; hover lifts the tile 4 px with a white sheen at 0.85.

**Settings**
- Preview pane: the repeated title is gone; icon + description side by side (desc at x 92, fades in on change).
- Hierarchy: section headers Oswald 36 cream; row labels Rubik Bold 24 (were 42).
- Toggles: 120x48 on a 4 px lip, 40 px knob, Oswald 26 ON / OFF (word box TW - TK - 12 wide).
- Tab icons: tabs 96 -> 112 tall (icon box ~71 design px, gap 5 -> 3), tab bar 108 -> 124 grown upward (y 23; bottom still 147),
  close X re-centred (y 51); 3D ViewIcons zoomed 1.35x on top of their default view.

Check in Studio: gunmetal reads as metal (not black) under the room light and the rim isn't hot on the wall behind; the 104 px
picked render doesn't touch the centred name for long names; the ListPlate slide-in; row labels at 24 still read in 88 px rows;
"OFF" fits; tab icons don't crop at 1.35x zoom (Keyboard is widest); Account / Touch image tabs fit the taller box.

## grade2 fixes: Play (2026-10-21)
Source: `grade2/play.png` vs RIVALS `grade2/rivals_play.png`. Only `ui/play/PlayScreen.lua` changed. Parse OK, 90 top-level locals.
- **Gutters:** the grid already used GAP = 10 design px everywhere; the "touching" tiles in the shot were the hovered Duel Pads
  tile (1.03 scale + a 4 px UIStroke drawn OUTSIDE the tile = the whole gutter). Ranked's top edge is the same Y as Duel Pads'.
- **Hover inside the tile:** the cream 4 px outline is a stroke on a `HoverRing` frame inset 4 px (it grows out to the tile edge,
  never into the gutter); the hovered / selected tile goes to ZIndex 2 so its scale-up draws above its neighbours; hover 1.02
  (was 1.03: 7.5 of the 10 px gutter on a 500 px tile, now 5 px).
- **Tiles are places:** new helpers `partsOf` / `frameOn` / `stageSet`. `stageSet` builds a set around the subject in camera space
  after the viewport has re-centred it: floor under the feet (runs past every edge), a painted line, a 6-7 stud back wall with
  pillars and a coping, crates either side (styles: squad = concrete + olive wall + tan pillars; range = sand + tan backstop;
  pads; ranked = dark gold hall). The tile gradient is now the sky over the wall (pale blue -> cream; ranked a gold dusk).
  `frameOn` aims the camera (iterative projection of every part corner) so the subject spans top..bottom of the tile and at
  most `fit` of its width; the hover lean / turn now pivots on that subject (`vp.focus`).
- **Squads:** packed tighter (first offset / spacing 2.4 / -, 1.9 / 2.5, 1.6 / 2.1), aimed to 12 % headroom and bottoms at
  72 / 66 / 58 % of the tile (3v3 >= ~42 % even if width-bound). Titles 100 px at MH-106 (were 128 px across the legs).
  RankedScreen's `SquadScene` (no shot) keeps the old auto-framed look.
- **Training hero:** no slab (sand floor fills the frame), props packed narrower for the tall tile, camera pitched -16 deg and
  aimed so targets / sandbags span 5..62 %; the title + subtitle sit on the floor in the lower third.
- **Duel Pads:** same set + aiming (8..56 %), title 84 px at MH-140.
- **Ranked:** `rankedScene` = ViewIcons' trophy x2.4 on a three-step podium (dark plates, brass trims) in the gold hall; locked =
  greyed (ImageColor3 150) under a 56 px padlock, RANKED 80, one caption "LEVEL 50", a 22 px bar 60 % of the tile, no outline,
  "LV n / 50" Oswald 20 cream on it. Open = the same scene in colour (replaces the lone trophy icon).
- **Daily missions row:** skipped - PlayScreen's ctx has no Missions opener (LobbyUIController passes none).
- **Look at in Studio:** frameOn convergence on real rigs (accessories widen the box), whether yaw 125 shows faces, crate
  placement at the frame edges for 1v1, sky showing over the wall, and the trophy's ScaleTo pivot.

## grade3 fixes: hub + PLAY (2026-10-21)
Files: `ui/hud/LobbyHudController.lua`, `ui/lobby/PlayRow.lua`. Code only, not run in Studio. Parse OK (luacheck.py); 115 one-tab locals in the file (under 200).
- **PLAY hover = one bubble.** PLAY's two-line tooltip ("Play / Find a match online...") is gone; it stacked on the "Join a match!" pill and covered the party avatar / +. PLAY has its own hover now: UIScale 1.08 over 0.12 s (Quad) and a white sheen (`_HoverGlow`, 0.85) under the label. Press is 0.95. The halo and shine sweep are kept. PlayRow sets the `Hovered` attribute on Play, and LobbyHud hides the join pill while it is true.
- **Dock hover no longer dims PLAY.** The grade2 `setPlayYield` (0.94 shrink + half fade) is removed; graders read it as disabled. The bubble just draws over PLAY (DisplayOrder 7 > 6), like RIVALS. `dockHover` stays for the join pill.
- **Dock.**
  - The NavShade bar behind the labels is removed (and the unused `BAR` / `navW`).
  - Discs are plain black at 0.4 transparency (was the grey gradient).
  - Labels are Oswald 22 with a 2 px #14170F stroke (was 28 / 2.5).
  - `tintModel(m, c, it)` takes a per-item strength. Kit is 25 % olive with a cream LightColor (the rim feel). Codes is pulled 60 % to cream #ECE6D2, and its dark parts (luminance < 0.3, the chain stub) turn red #C8442E. Viewport Ambient is 200 (was 220).
- **Daily Missions widget.**
  - The CanvasGroup wash is gone; it rendered as a flat box. In its place are plain frames, each with ONE horizontal UIGradient (0.45 at x 0 -> 1 at x 0.7): a middle frame for 10-90 % of the height, plus 6 thin strips over each of the top and bottom 10 %, whose left opacity steps down to the edge.
  - The widget is 500 x 240 (rows 182). Names are Rubik 22 (20 / 18 for the longest) in a 280 px column. Counts end at x 380, and the bars run 44-380.
  - The reward column starts 14 px after the count: 28 px scissors at x 394 + "×175" in cream Oswald 26, with commas ("×1,000"). The done check sits in the same column.
  - DUEL PADS is at design (19, 649): its left edge is on the glyph column, 16 px under the last bar.
  - Row order is the saved `Daily.List` order. That is what MissionsScreen.scopePanel uses (ipairs, no sort); the grade2 pool-index sort disagreed with it.
- **Lips / underlines removed (user rule: they read as AI-made; copy RIVALS).** The removed pieces:
  - the currency plate's black bottom Lip (now a plain dark pill, scissors + green +);
  - DUEL PADS' black bottom Lip;
  - the join pill's tan Lip (its pointer is cream now).

  PLAY had no lip or underline in PlayRow. Its text outline and hover brackets stay.
- Check in Studio:
  1. Hover PLAY: it should grow and brighten, with no tooltip, and the join pill should hide.
  2. Hover the dock: PLAY should stay full, with the bubble over it.
  3. The dock should show no strip. Kit should read olive / cream, and Codes cream with a red stub (if the DogTags asset has no dark parts, there is no stub).
  4. The wash should have no edge, and the strip banding should be invisible.
  5. "Get 3 eliminations from cover" should fit at 18-20.
  6. DUEL PADS should sit under the bars and not overlap the widget's click area.

## grade3 fixes: Kit (2026-10-21)
File: `ui/lobby/Armory.lua` only. Not deployed, not run in Studio. Parse check OK; top-level locals 180 before and after.
Mid-task the user's verdict ("looks terrible UI-wise"; the green underlines / lips / bars read AI-made; "just copy RIVALS") replaced
grader item 2: the Kit now copies RIVALS' Weapons screen (t0052) instead of a charcoal button hierarchy.

**Removed (shapes RIVALS' Weapons screen doesn't have)**
- List: the 5 px field-green lip under the picked row and its half-lit hover lip (`makeRow` / `rowLook`). The band + bold text + render stays.
- Action buttons (`bigButton`): the darker lip under the face, the face gradient, the thin white highlight line across the top, the
  2 px press drop, the EQUIPPED word chip, and the glint sweep (`Armory._shine` calls; the function is kept, unused). Now one plain
  solid field-green square with a cream glyph / price (grey when unusable). Equipped = the green square with just the check, not clickable.
- Item card: the green ABILITY chip -> a third plain Rubik bullet ("Ability: Quickdraw", 21 px; the sentence is still its bubble).
- Stat segments and the level bar: gradients -> solid field green.
- Picker: the BACK button's dark lip and gradient (solid red now); the darker lip strip under each locked tile.
- Kept on purpose: the section header's dotted rule (RIVALS has it under "Primary"), the rarity gradients on tiles, the hover sheen
  (only on hover). Panel corner brackets were already a no-op (`Tac.brackets`).

**Grader items**
1. Hero: `ShowcaseLook` makes every untextured grey part SmoothPlastic (no Metal stripes); formerly-Metal 0.36 value + Reflectance
   0.08, plastic 0.25. The item sits 1.4x closer along the camera ray through DisplayPoint (`renderShowcase`), so it stays centred;
   `WHEEL_MAX_ZOOM` 2.2 -> 1.6 keeps the closest zoom the same. Guns rest in a 3/4 pose (yaw 25 deg off side-on, pitch 10 deg) in
   `makeShowcase` instead of Icons.GunView's 28 deg tilt + roll (icons unchanged). Idle sway unchanged.
2. Replaced by the RIVALS copy above.
3. Favourite: a solid 28 px cream checkbox with a dark well (3 px edge, no stroke); ticked = field-green well + cream check. Bubble kept.
4. Bullets 19 -> 21 (max 2 lines, 50 px). EQUIPPED chip gone (check only). Duel History is an icon now. Level bar: cream track at 25%,
   fill min 6 px once owned, "LV n" on it; RIVALS' **"Level up"** row is back under it (XP to the next level / Unlock it to earn XP /
   Every level reached), then "Reward at level N" (`LEVEL_H` 110 -> 172).
5. Locked names `COL.Dim` 92,97,86 -> 140,142,132 (greyed, readable); hover lifts to `COL.Sub`. One 20 px padlock in a fixed column
   (left edge x 24) on the row, outside the centred layout. "Duel History" text button -> a 52 px icon slot with a drawn clock
   (`GLYPH.clock`) and a "Duel history" bubble. The list plate already ended 16 px above the bottom (grade2).
6. Picker None check inset: right edge at TILE - 6 (was poking 4 px out).
7. Locked tile bubble: "Rare skin · coming with the next update".

Check in Studio: the 1.4x framing doesn't clip the bench or the camera on long guns (Sniper) and the 3/4 rest pose faces the right way
(flip the 25 deg sign if the muzzle points back); "LV n" reads on the cream 25% track; the right column (62 px taller) clears the
top bar; the clock reads at 34 px; locked padlocks don't touch long names (Pump Shotgun).

## grade3 fixes: Shop (2026-10-21)
From `notes/ui_rivals/grade3/shop.png` vs RIVALS t0070 / t0068.4 / t0074 / t0084. Mid-task the brief changed: the user said the
Shop "looks terrible UI-wise" (random green underlines, lips, bars = AI-made), so the Shop look is now a close copy of RIVALS' Shop.
Only `ui/shop/ShopScreen.lua`; not deployed, not seen in Studio. Parse OK, 64 top-level locals.
- **Removed (no such shape in RIVALS):** the price-tag bottom Lip, the tag gradient and the number's offset shadow copy; every
  RarityBar / RarityStripe (Featured tiles, Arms cards, bundle tiles, detail tiles); the Arms cards' Clip frame and diagonal stripe;
  the bundle banners' diagonal stripe; the Scissors-tab AccentStripe; the pass cards' StateBar; the hero's BundleGlow and the offer
  panel's OfferGlow; the detail card's offset Shadow block; the Tac corner hover brackets on every card (Tac no longer required);
  the dark TILE_GRAD plate; grade2's tan can't-afford number (SHORT_TAN) and the red flash (flashShort).
- **Price buttons:** one solid rounded button per currency: Robux = field green + white number, scissors = tan (#E2D2AC) + dark
  number. The icon sits LEFT of the number; scissors use the red 3D-scissors render (rbxassetid://120480559804238, the Missions /
  LobbyUI image) instead of the flat cream glyph that read as "✕". Owned = grey + check. Can't afford: nothing at rest, a press shakes.
  The detail card's buy button follows the same rule.
- **Tiles:** plain squares filled with their colour, light -> dark (`fillGrad`): rarity colour for gear, tan for scissor packs.
  Featured tiles 124x112 with the 112x44 price button straight under (`gearTile`); renders zoomed 1.1x into the full tile and lit like
  the hub dock (`lit`: ambient 220, white key light from the camera side). Arms cards, bundle tiles and detail tiles use the same fill.
- **Feature cards:** Founder's hero = a light cream panel (RIVALS' Season Pass), contents line dark; the offer panel = solid deep field
  green; pass cards light cream; Scissors-tab cards tan (RIVALS' yellow Keys cards); detail card = the bundle colour (field green
  for packs / passes).
- **Packs (item 3):** pile 132x90 over the tile, running off its top edge (~70 %), zoom 1.2; "+N" Oswald 28 -> 32.
- **2X SCISSORS (item 4):** medal box 200 -> 260 (~230 px, ~70 % of the card), a "×2" badge Oswald 120 (cream, rocking, taken from
  the pass name), description Rubik 24 in a 380 px block.
- **Tabs (item 5):** every icon in one 48x48 box, bottom 6 px into the plate, per-icon zoom (Medal 0.95, Crate 1.1, rifle 1.35,
  scissors 1.4); selected grow 1.3 -> 1.2; labels centred under it. Selected = white, others the dark plate (as RIVALS).
- **Close X (item 7, rule for all screens):** 72x52 `Kit.closeButton`, 12 px outside the panel's top-right, top level with the
  panel's top: Shop at (PAGE_X + PAGE_W + 12, 170); detail card at (W + 12, 0) on the wrap.
- Not done: item 2's name line (RIVALS' tiles carry none) and item 6's wallet plate (not in the new brief).
- Look at in Studio: the scissors render at 34 px on tan; green Robux buttons on the green offer panel; tab icon sizes; hero title
  (white outlined) on cream.

## grade3 fixes: Missions / Play / Settings / Codes (2026-10-21)
Files: `ui/pseudolobby/hub/MissionsScreen.lua`, `ui/play/PlayScreen.lua`, `ui/set/SettingsScreen.lua`, `ui/settings/SettingsKit.lua`,
`ui/lobby/CodesScreen.lua`. Two mid-task rules from the user changed the brief: (1) decorative underlines, lips and green
bars look AI-made, so remove the ones RIVALS doesn't have (progress bars stay); (2) the target is "as close to RIVALS as
possible", not the graders' ideas. Settings follows RIVALS t0136 / t0137 and overrides items 8-11. Missions follows t0062.

**Close X**: Missions, Play and Codes use a 72x52 X placed 12 px outside the panel's (or grid's) top-right corner, its top level
with the panel's top. On Missions it moved out of the panel into `root`, because the scrolling column clips. Settings uses
RIVALS' own placement: 135x68 at the far right, right edge flush with the description pane, top level with the tab bar.
Every X has lost its dark bottom lip.

**Missions**
- Panel fill: the request was to remove it, but RIVALS' Tasks sit on a solid dark panel, so it went 0.85 -> 0.45 instead.
  The Weekly rows have no plate now (like RIVALS' Contracts); a finished row keeps a faint green wash.
- The "next" cue is gone. RIVALS has no cue, and the user ruled out the underline bar.
- Card titles 21 -> 24 design px (~18 px on screen). Weekly reward scissors 44 -> 58 px. Reward counts now use thousands
  commas (`commas()`).
- Headshots use the `eye` glyph; eliminations keep the crosshair. The solid Weekly play glyph is tinted tan instead of cream,
  so it no longer reads as white.
- GO PLAY moved into the panel corner the X left, and its Kit.button lip is stripped.

**Play**
- Titles in one size class: TITLE 64 for the small and wide tiles, HERO_TITLE 72 for TRAINING. Subtitles are Rubik 20.
  Duel Pads reads "1v1 anyone in the lobby".
- The party column is pinned 24 px left of the grid, with its bottom (the leader) level with the grid's bottom.
- Ranked (locked): the greyed scene ImageColor went 150 -> 205, the cup is scaled 1.3x, and the gold hall gradient is ~15 %
  lighter. The caption reads "UNLOCKS AT LV 50" and the level bar is unchanged.
- Lock card: the PlayLip offset block is gone, and its X is now 72x52, 12 px outside the card.
- Open: RIVALS' tiles have no subtitles and centre the title. The subtitles were kept because they were asked for explicitly.

**Settings (RIVALS t0136 / t0137)**
- Tab bar is 77 tall at y 71 again (bottom 147), with tabs 136x100 whose icons (~61 px) rise above the bar. The selected tab is
  a 52 px cream plate inside the bar (new `plateH` argument on `Kit.imageTab`). Tab words are 25 px.
- The PRESETS caption is gone; RIVALS' rail has none.
- Rows stair-step like RIVALS: a sub-row's plate starts 38 px further in. Slider rows are 138 tall, toggle rows 78, the rest 88.
  Row names are Rubik Bold 34.
- Sliders: the ▲▼ stepper is back (one cream 56 px box, steps by `row.arrow`), next to a 108x56 value box. Under them is a thin
  6 px track with a 32 px square knob. The chip's tan lip is gone.
- Toggles are 96x48, with a square-ish 36 px knob, no ON/OFF word and no dark lip.
- Description pane: icon, then a big Oswald 50 title (the setting's name, back from grade2), then a Rubik 26 cream description
  underneath.

**Codes**
- Body text 26 -> 30 design px, with a shorter line so it still fits one row. The "None yet" line went 24 -> 30.
- Redeem uses the field-green `key` gradient (was the lime Robux green). Off: an opaque dark plate with cream text at 50 % and no
  stroke. Typed: the plate fades, the word turns white, and the button pops. The green glow block behind it and the button's lip
  are gone.
- Input focus lifts the box's fill (0.35 -> 0.12). There is no underline, per the user's no-underline rule.

**Removed lips / bars**: the X lip in `Kit.closeButton` (SettingsKit) and on the Missions, Play, lock-card and Codes X buttons;
the Kit.button lip on GO PLAY and Redeem; the toggle's dark lip; the slider chip's tan lip; Play's PlayLip block; Codes'
RedeemGlow; and the Missions next-cue ring. `ui/lobby/Kit.lua`'s Kit.button and closeButton still create lips for every other
screen (not in this pass's files).

**Look at in Studio**: the Settings tab icons rising over the 77 px bar; the stepper box next to the chip; whether the 34 px row
names collide with the stepper on narrow level-3 plates; the Missions X now sits outside the column; and the Ranked tile's
brightness.

## RIVALS 1:1 port: Play (2026-10-21)
File: `ui/play/PlayScreen.lua`. Sources: `rivals_practice/ui/play/PlayController.client.lua`, the Rivals kit, and the live
capture `grade2/rivals_play.png` (which is 1:1 at 1920x1080).

**Look (from the replica and the live capture)**
- The look now comes from `UIKit.Rivals`: Theme, Kit and Assets. Tacticals' `UIKit.Kit` stays only for `whoops`, `crown`,
  `fillTo`, `countTo` and `shake`. The `Tac` palette, Oswald and the cream colour are gone.
- Layout: RIVALS' scroll column at x 258, y 139 (1430 x 941, thin dark scrollbar). It holds:
  - the Training hero tile, 416 x 555, on the left;
  - 1v1 / 2v2 / 3v3 tiles, 323 x 274;
  - Duel Pads + Ranked tiles, 488 x 274 (the 4v4 / 5v5 spots in RIVALS).
  The gutter is 7 and the corners are 6 px.
- Tile = the replica card:
  - a full-bleed picture under a 0.7 black shade, then ONE white Rubik ExtraBold title centred on the tile (100; the hero 88);
  - the replica's soft shadow (a black stroke at 0.82 transparency);
  - hover: the shade goes to 0.95, a white 4 px border shows and the tile shrinks to 0.97 (press 0.93 -> back);
  - a controller selection gets the same hover.
- Removed (RIVALS doesn't have them):
  - the bottom shade band, the sheen and the cream inset ring;
  - the subtitles ("Try any gun for free!", "1v1 anyone in the lobby", "Ranked queues ON") and the RANKED tag;
  - the locked tile's caption and level bar, and the 3D padlock;
  - the per-tile status chips ("n searching", "Searching m:ss", failure flashes) and the per-tile pop-in.
- Locked Ranked: the replica's locked card (shade 0.35, the Rivals `padlock` image, the title "Ranked"). Clicking it still opens
  the requirement card, now in Theme colours: panel, track, green, the grey gradient, and a FredokaOne "Play".
- Red X: the replica's `Kit.closeButton` 112 x 58 at 1704,136. The lock card's X is the same size. Open / close use Rivals
  `Kit.open` / `Kit.close` (grows from the centre, 0.22 s Back).
- Searching: the replica's pill (540 x 80, black at 0.25, star6 sparkle, "Searching for players..." with the mode, a clock and a
  76 x 52 red X that sends CancelMatch). It turns "Match found!" in green. It sits above the column at y 44, so it never covers a
  tile, and shows only while Play is open. Clicking your own searching tile still cancels.
- Queue failures, party blocks and "can't train while searching / on a pad" now use Whoops, not chips.

**Pictures**
- The live 3D scenes stay, now lit as action shots: a brighter, cooler ambient and a white key light from high on the camera
  side.
- Enemies are Theme red (ranked: Theme gold), the duel ring is Theme green, and the squad / pad sets use pale lavender arena
  tones with taller walls.
- Framing is aimed so the figures fill the tile behind the centred title (squads top 0.06 -> bottom 0.94-0.98).
- Sky gradients: Theme `gradient.blue` (ranked: `gradient.key`).
- The 3D set / prop colours are scene art, so they stay as literals. Every UI colour and font goes through `UIKit.Rivals.Theme`.

**Kept**: 1v1 / 2v2 / 3v3 queueing with the party checks and messages, Training, Duel Pads, Ranked locked / open
(`openRanked`, or the in-place ranked tab as a fallback), dimming of busy tiles, the party column (Theme panel colours), the
hover hops and the camera lean.

**Not ported**: the replica's dark-pill section headers (rotating / classic modes). Tacticals has no modes for those sections,
so the column holds only the grid for now. It is a ScrollingFrame, so sections can be added below.

**Look at in Studio**:
- whether the 0.7 shade leaves the pale scenes bright enough;
- whether "Training" at 88 and "Duel Pads" at 100 fit their tiles;
- whether the Rivals padlock image loads in the Tacticals place;
- the HUD's own "SEARCHING" seek bar shows after Play closes and is not yet RIVALS-styled (HUD session).

## RIVALS 1:1 port: hub (2026-10-21)
Source: `rivals_practice/ui/hud/HudController.client.lua` (Play row, nav, key pill, Daily Tasks, To Duels) and
`rivals_practice/ui/play/PlayController.client.lua` (searching pill), with `UIKit.Rivals` Theme / Kit / Assets. Edited:
`ui/hud/LobbyHudController.lua`, `ui/lobby/PlayRow.lua`. Layout, Scale conversion and tweens stay on our `UIKit.Kit` (the same
converter); the ported pieces take shapes from `RKit` (corner, vgrad, stroke, textStroke, label, closeButton) and colours / fonts
from `RTheme`. Values the Rivals Theme has no token for yet (the Play stops, To Duels blue, nav bar, disc, pill alpha...) are read
from `Theme.hud[name]` / `Theme.playRow[name]` when present, else the replica's measured value. So a re-theme is one file: add
those two tables to `UIKit.Rivals.Theme`.

**Ported 1:1 (design px)**
- PLAY: 222 x 62 at (849, 859), corner 4, the 5-stop lime gradient + `#D8FF8A` edge, "Play" Rubik ExtraBold 35 with a thin
  `#5FB51E` outline, hover 1.08 from the centre (+ the live brighten sheen), press 0.93. Busy / found states use the same band
  shape in Theme grey / a lifted lime; state texts are shown in title case ("Searching 0:12").
- Party: 62 px headshot at (1102, 859) on `#2B2B33`, 46 px "+" at (1172, 876) (fading dark disc, grey cross); mates 54 apart.
- Nav: 121 apart, 118 x 112 buttons at y 1060, the trapezoid bar (`Assets.hud.navbar`, `#141218` @ 0.25) back under the labels,
  the black fading-gradient disc, labels Rubik Bold 28 + 2.5 stroke, 30 px badge-red counts with the white ring, white
  self-sizing bubbles (Rubik Bold 22) shown at once, still 2 s, then 18 px hops; hover = the whole item 1.12 + 14 px lift.
  Our 3D models stay (holder = the replica's 92 px icon box), lit neutral white.
- Scissors pill: the key pill (122 x 38 black @ 0.45 at 893, 42; count Rubik Bold 30 white; 56 px render at 862, 30; lime +).
- Missions widget: the Daily Tasks box (350 x 255 black @ 0.5 at 10, 405, corner 6), title Rubik Bold 34, rows 67 apart:
  32 px white glyph, name Rubik Bold 28, 262 x 6 track with a Theme-blue fill (green when done), count "n / goal" to x 307,
  reward = the bright 3D scissors with "×N" stacked under it; done = a 40 px green check in place of count + reward.
- Duel Pads: the "To Duels" button (197 x 48 at 91, 688, blue gradient, cyan edge, stars, Rubik Bold 28, "Duel Pads").
- Join bubble: "Join the queue to start playing!" as the same white pill, pointer 14 px over PLAY.
- Searching (after Play closes): the replica's 540 x 80 pill at (692, 119) like PlayScreen's (sparkle, "Searching for
  players...", mode, clock, red X = CancelMatch, "Match found!" in green); PLAY hides while it shows (live).

**Removed** (not in RIVALS): the fading wash, the field-green Duel Pads, the cream join pill, PLAY's halo pulse, shine sweep
and hover corner brackets, the nav's cream glow layer and icon-only grow, the cream rim light, the badge bob, the bracketed
olive searching bar, Oswald on all of these.

**Could not match / check in Studio**
- Mission names run longer than RIVALS' ("Play duels"): Rubik 28 steps down to 20, then truncates.
- "×1,000" does not fit the replica's 34 px reward column: the label is 60 wide on the same centre.
- Rivals Assets images (star6, navbar, check) were uploaded for the replica place: confirm they load in Tacticals.
- 3D viewport models can't be lit exactly like RIVALS' pre-rendered icons; the per-item tints are kept (model colour).
- The searching pill sits at the replica's y 119 (under the scissors pill); PlayScreen draws its copy at y 44 above its column.
- The Rivals Theme still lacks hud / playRow tokens (fallbacks are in the two files).

## RIVALS 1:1 port: Missions + Settings + Codes (2026-10-21)

Sources: rivals_practice/ui/tasks (TasksController, TasksData), ui/settings (SettingsController, HotkeysPage), kit/*,
RIVALS t0062 (tasks), t0136 / t0137 (settings). Colours and fonts only from `UIKit.Rivals.Theme`; components from
`UIKit.Rivals.Kit` (Missions / Codes) or SettingsKit's replica copies; canvas / toScale / motion still from `UIKit.Kit`.
Not deployed, not committed, not checked in Studio.

**Missions (pseudolobby/hub/MissionsScreen.lua) = the replica's Tasks screen**
- Column 532-1360 from y 208 (scroll area 664 tall, 10 px dark bar, no clip, so the panels run on down the screen); panels
  black @ 0.55, corner 8, 25 apart. Red X = Rivals `closeButton` 94 x 48 at (1402, 208), outside the column (renamed CloseX
  + tagged Nonapplicable so InterfaceController leaves it alone).
- Daily header: notepad icon 46 at (30, 10), "Daily Missions" Rubik Bold 36 + "[done / total]" Rubik Bold 30 (dim; green
  when all done), the blue "To Duels"-style button 165 x 41 at (652, 12) (Theme blue gradient, stars, "Play") -> ctx.openPlay.
  When every daily is done the RIVALS done-panel line "new daily missions in ..." sits under the title (same for contracts).
- Tiles 243 x 242 at x 45 / 292 / 540: title Rubik Bold 30 (shrinks to fit), 46 px solid white glyph (replica trophy / play,
  rowIcon crosshair / aim, Kit.ICONS cover / melee / gadget tinted white), 206 x 10 bar (Theme track, blue fill), count
  "big / small" rich text (29 / 20) with a dark stroke over the bar, the scissors render (rbxassetid://120480559804238) 50 px
  with "×N" under it. Done = green title + glyph, full green bar, a 40 px green check on the bar in place of the count.
- Contracts: scroll icon, "Weekly Contracts", "sorted by" + the Rivals dropdown 207 x 41 (Default / Near Completion; the
  choice re-renders the list). Rows 62 tall: 42 px glyph, name Rubik Medium 27, count right-aligned at 708 (32 / 21), 660 x 6
  bar, a 42 px reward render at 771. Done = green name / count / bar + a green check disc on the bar's end.
- Auto-pay kept: todo / done / paid states, bars and counts tick on while open, the check pops when a task finishes, the
  reward pops when it is paid. Paid = the render dims to 0.5 and its "×N" turns green (the cream PAID tag is gone).
- Removed (not in RIVALS): Tac corner brackets, the card lift, 3D task glyphs (ViewIcons), the field-green / cream palette,
  Oswald, the always-on reset timers, the green check badge disc on tiles.

**Settings (set/SettingsScreen.lua + settings/SettingsKit.lua)**
- SettingsKit reads `UIKit.Rivals.Theme` (5 s wait; falls back to SettingsTheme with a warning) and exposes it as Kit.Theme
  for SettingsScreen and HotkeysPage.
- Replica components back: toggle 110 x 55 (white #F2F2F2, black 41 px knob left; green + knob right when on, 0.25 s Sine),
  stepper slider (light ▲▼ 53 x 55 + value box 103 x 55 at y 17, dark 6 px track at y 100, light square knob, no fill),
  section header bar (black @ Theme.alpha.header, 78 tall, Rubik ExtraBold 61; was plain Oswald cream text), close X
  (Theme red gradient, outlined white bars, no sheen).
- Rows: all 88 tall (toggles were 78), sliders 132; labels Rubik SemiBold 42 (was Bold 34); hover = plate 0.15 darker only
  (no green tint, label change or icon tilt); 32 px gap before a section header.
- Detail pane: title Rubik SemiBold 56 (shrinks to fit, fades in), description Rubik SemiBold 31 in Theme.textDim; the pane
  is the faint full-height column (black @ 0.93, 890 tall).
- Tab bar 772 wide = the list (was 859): six 120 px tabs 126 apart. The 3D tab icons are lit from the camera side
  (ViewIcons' LightDirection had z -0.8, i.e. light from behind the model; now (-0.4, -0.7, 1), ambient 200, white light).
- Close X y 71 -> 75 (replica 1481, 75). Import popup fonts derived from Theme.
- Kept: profiles 1-3 + bubble, per-row reset, crosshair preview, import / export codes, showIf rows, action rows, NavTab /
  NavPressed gamepad attributes, Reload.

**Codes (lobby/CodesScreen.lua)**: the replica panel (black @ 0.45, corner 8), white gift glyph + "Codes" Rubik ExtraBold
56, Rubik body in textDim, a dark input box (Rubik Bold 36, grey placeholder), the replica's green gradient "Redeem" button
(FredokaOne) greyed by a Theme.disabled plate until a code is typed, result chips in Theme green / red, redeemed codes on
the replica's tile plate, the 94 x 48 red X 42 px off the panel's top-right. 3D dog tags and Oswald removed.

**Open / to check**
- The match place deploy list ships SettingsKit + SettingsScreen but not `UIKit.Rivals`: add the four rivals/* files to
  MATCH_FILES (deploy_ui.py, not mine) or the match-place Settings falls back to SettingsTheme (Oswald).
- "[1 / 3]" read as the Daily header's done / total count after the title.
- Rivals Assets images (notepad, scroll, star6, check, trophy, play, rowIcon crosshair / aim / gift) were uploaded for the
  replica place: confirm they load in Tacticals.
- Long Tacticals mission names: the tile title shrinks (TextScaled, max 30); contract names truncate.

## RIVALS 1:1 port: Shop (2026-10-21)
File: `ui/shop/ShopScreen.lua` only (rewritten; parse OK, 79 top-level locals). Source of truth: the replica's
`rivals_practice/ui/shop/ShopController.client.lua` + frames t0068.4 / t0070 / t0071 / t0073.4 / t0074 / t0084 / t0099.

**Kit split**: colours, gradients and fonts come from `UIKit.Rivals.Theme` (Rubik: ExtraBold numbers/titles, Bold labels,
SemiBold tags, Medium lines); `UIKit.Rivals.Kit` gives the look primitives (label, corner, vgrad, stroke); `UIKit.Kit` stays the
engine (toScale, canvas, bindButton, busy / shake / pop / countTo, loadingDots). The red X is `UIKit.Kit.closeButton`
(RIVALS' X, tagged Nonapplicable): `Rivals.Kit.closeButton` is named "Close", which the old InterfaceController shrinks to 0x0.
Robux glyph = `Rivals.Assets.shop.cur_robux`; scissors = the red render 120480559804238.

**What matches RIVALS now**
- Tabs (replica geometry): 144x48 pills 12 apart at y 275, centred, black 0.35, selected = white; a 60 px live 3D icon rises out
  of each; Bold 27 label low with a black outline (kept on the white tab, like t0068.4s). X 86x48 at the row's end. Pages swap
  at once (round-3 slide-in, tile pop-in and selected-icon growth removed).
- Wallet: scissors render, black 0.45 count pill, lime "+" (replica), top centre.
- Price buttons = the replica's priceTag: 6 px block, `Theme.gradient.robux` (lime, Robux glyph left) or `Theme.gradient.key`
  (yellow, number then scissors render, RIVALS' key button), faint dark edge, ExtraBold white number over a soft shadow copy.
  Owned: the button goes and RIVALS' black check sits in its place (t0099).
- Item tiles (Design System): near-black top -> rarity colour bottom + 2 px rarity stroke; renders spill over the top; prices
  overlap the foot.
- Featured = the replica Home: packs row (scissor piles + "×N", lime prices) and gear row (bare renders, yellow prices) at
  RIVALS' 163 px pitch; the Season Pass slot = Founder's Bundle (grey 35° wash, big render, heavy white title + shadow, red
  LIMITED pill, lime price where the eye button is; hover = spotlight + shade + contents reveal); Special Offer panel
  (750x324 at 0,363) with slides (heavy title, gold + sparkle for bundles, red "xN VALUE" badge, lime "Special Offer / VIEW")
  and the replica's page dots under it (hover grows a dot, click jumps, 6 s auto-advance with the t0071 slide); 3x2 rarity
  tiles at 801 + 162 / 381 + 159.
- Bundles: Founder's Bundle as the 1242x399 hero (contents always shown), then the scissors bundles in RIVALS' 389 / 602
  rows; bundle colour + 35° wash, gold sparkling title, value badge over the price; hover = spotlight + contents + bigger price.
- Arms: the Daily grid (5 x 243x190, 6 px gap, name on top, yellow price over the foot, white tooltip).
- Scissors = Keys tab: gold cards (the biggest pack red), giant cropped scissors render, name + huge "+ N", lime price,
  pack Tag as the red badge; a "Passes" header bar (dark, fading right) then Season-Pass-grey pass cards.
- Detail card = the replica offer popup (t0074): shop hidden behind a 0.35 dim, 818x551 tinted box, 76 px title, rarity tiles /
  pack or pass art; red X 251x110 and the price 251x110 under the box with the value badge over the price; appears at once.
  Buy shows Kit.busy's three dots (t0073.4s); success -> "Purchase Complete" banner via `UIKit.Notify.Push` (Rivals Toast
  fallback). Robux buys banner when the purchase lands (Refresh: credits up / now owned, 3 min window).
- Removed (not in RIVALS): rocking stickers (wobble), the lift / tilt / squash art reaction, the Keys hover "+N -> ×N" swap,
  tan/field/cream colours, Oswald, the cream-check plate, the Owned words.

**Open / check in Studio**
- Scissors bundle buys: the server's RichNotify also sends one "Item Unlocked" banner per item, so they queue after
  "Purchase Complete". RIVALS shows only the one; dropping `RN.Item` for BuyBundle (LobbyManager) would match it.
- Notify's banner sits at y 64 (over the wallet); RIVALS' sits just under the wallet (y ~108-216).
- A Robux pack's banner keys off the credit count rising within 3 min, so a mission reward in that window can trigger it.
- Rarity colours (LobbyConfig) and bundle colours stay tacticals content; check gold titles on the light Ghost bundle.

## RIVALS 1:1 port: Kit (2026-10-21)
Source: `rivals_practice/ui/weapons/WeaponsController.client.lua` (+ `ui/kit/*`), checked against `rivals_rec` t0048-t0062.
Only `ui/lobby/Armory.lua` changed; the world showcase (the big hero gun, its camera hold, drag / spin / zoom, tape and the
scissors cut) is untouched. Not deployed, not run in Studio: parse check only (`luacheck.py`: OK, 166 top-level `local`
statements, was 180; 201 local names, was 213).

- **Canvas:** the panels now sit on `UIKit.Rivals` `Kit.canvas` (a centred 16:9 frame). Everything is built in RIVALS' 1920 x 1080
  design px and converted with the Rivals `Kit.toScale` (the old 1008-unit canvas with a UIScale and Offset sizes is gone).
  Runtime pieces are built inside a Folder, converted against the canvas and then moved into place (`settle`). Lists set their
  CanvasSize in Scale of their parent. Tooltips and the Statistics move are placed in Scale.
- **Theme:** colours come from `Theme.color` / `Theme.gradient` / `Theme.hex` with the replica's measured values (the `COL` and
  `GRAD` tables). Fonts are Rubik ExtraBold / Bold / Medium from `Theme.font`. Removed: Oswald, the TacKit corner brackets, the
  field-green buttons, the cream bubble, the UIIcons meshes (icons are the replica's `Assets` images: padlock, arrow, check, eye,
  undo, trophy, burst) and the unused `_shine`.
- **Left:** the Career card (headshot + "Career", which opens Duel History; the three slot icons + the clock, black at 0.5; no
  "Dismiss" pill, since Tacticals has no notifications, so the card is 150 tall at y 480). The list sits at 12, 640 to the bottom
  edge on a near-invisible plate (black at 0.75). Headers: dim Bold 30 title between two dim silhouettes over a 16-dot rule.
  Owned rows: render at the left, name centred, Medium, dim. Locked rows: dark, with a padlock either side. The picked row is
  left-aligned, bold white, with its render popping out on the right over a black 0.5 band.
- **Right:** stacked up from y 1060, 11 apart.
  - Item card 335 x 97: the render poking out of the corner, name ExtraBold 34, white checkbox (Favourite), two bullets
    ("Starter/Standard <slot>", the first sentence of the description).
  - Owned: level card 335 x 165, with a thick blue bar (XP so far / XP for the level at its ends, the big level number centred
    on it); "Level up now!" with the yellow key-gradient button (shows the XP still to earn and shakes, because Tacticals has no
    paid level-up); "Reward at Level N" with the ViewIcons crate on a white tile with a cyan edge.
  - Locked: an "Unlock now!" card with the yellow price button (price + scissors; one press buys, then the tape cut).
  - Action rows, 58 apart, with 111 x 52 blue gradient icon buttons: Equip (green check when equipped), Inspect, Next unlock
    (name and price on the sub-line), Statistics. A button you can't use is grey and shakes.
  - The column starts at about 50% of the screen height owned (RIVALS' 54% has three rows; we have four).
- **Statistics:** the replica's panel opens at the bottom of the right column, the column slides up by its height, and the
  row's button becomes a red X. The ability line and the Speed / Reload / Accuracy segment bars moved here from the item card.
- **Bottom:** the replica's strip: a dark bar under 100 px slots 121 apart, centred. Leave is the red X (two plain red bars);
  Skin / Wrap / Finisher show the grey "none" slash square, with Bold 26 labels. A locked item shows Leave alone. The slots pop
  in one after another on opening. The Cutscene slot is removed (RIVALS has none).
- **Picker** (t0050), which replaces the panels while the gun zooms x1.25:
  - top row: red "Back" (undo icon, ExtraBold 36), the search bar "Search by name or tooltip" (filters the tiles), and
    "Favorited" with a checkbox (shows favourites only; there are none yet, so just None);
  - one row of 118 px tiles 138 apart on a dark strip. "None" comes first, dark, with the none glyph and the big green check.
    The other tiles use the replica's rarity palette, with a dark silhouette of the weapon (a wrapped cube for wraps), a dark
    wash, a white padlock and the name. They grow on hover;
  - clicking a tile shows RIVALS' name pill at the top centre ("Coming with the next update"); a locked tile shakes.
- **Duel History:** restyled (Rubik, Theme greens / reds, a red square close X), centred on the canvas.
- Kept as before: Duel History data, ArmoryTestHook, the Cut transition and the favourite / equip / unlock / inspect / next
  unlock behaviour.
- To check in Studio:
  - text sizes on first open (`Kit.rescaleText` runs on Enter);
  - the list's CanvasSize in Scale of its parent (the Rivals Kit's measured rule);
  - the yellow / blue buttons' `Assets` icons loading in the Tacticals place (ids uploaded for the replica).

## Kit: click to equip (2026-10-21)
User: "remove equipped from the kit section and make it so clicking the item equips it like rivals does". Only `ui/lobby/Armory.lua`;
parse check OK, 166 top-level locals (unchanged; new state on the Armory table). Not deployed, not run in Studio.

- **List click = equip:** `Armory.ClickItem(id)` replaces the row's Select-only click. An owned row is picked and, if it isn't in
  its slot yet, `ctx.ask("Equip", slot, id)` (the old Equip button's path) runs in the background. A locked row is only picked
  (the Unlock now! card shows its price). Buying still equips straight away, as before.
- **Equipped mark:** the replica's green check (`COL.Check`, as the picker's) on every owned row that's in your loadout, one
  per slot: at the left edge of the picked row (its render is on the right), at the right edge of the others. It pops in
  when it moves. `Armory._restyleEquipped()` restyles only the rows whose state changed, after the Equip reply and on
  every `Refresh` (when the list isn't rebuilt).
- **Right panel:** the "Equipped / In your loadout" row and its green / blue button are gone. Inspect, Next unlock and
  Statistics are 62 apart (RIVALS' spacing for three rows) for owned and locked items alike (was 58 with four rows).
  The `tone ~= "green"` special case in `row()` went with it.
- **ArmoryTestHook:** new `"Equip"` (alias `"Click"`) action, `hook:Invoke("Equip", id)`, goes through `Armory.ClickItem`.
- To check in Studio: the check sits clear of the small render on unpicked rows and of the name on the picked row; the
  checks move after a click with no full list rebuild.

## Play: normal-theme layout (2026-10-21)
File: `ui/play/PlayScreen.lua` only (parse OK, 83 top-level locals). Not deployed, not run in Studio.
The first port copied the NEW-ACCOUNT Play (tall "Beginner 2v2" hero on the left). It now follows RIVALS' normal Play,
`notes/ui_rivals/rivals_normal/play.png`.

**Measured** (the capture's viewport is 1920 x 1002; the tiles are the same px as the 1080 capture, so x and sizes carry over 1:1;
the grid's centre y 541.5 / 1002 maps to 584 / 1080, so the top is at 306):
- top row: 323 x 274 at x 258 / 587 / 916 (6 px gaps);
- bottom row: 488 x 275 at x 258 and 489 x 275 at x 751, y + 281;
- Ranked: 415 x 556 at x 1246, full grid height. The grid is 1403 x 556 at (258, 306).
- Ranked tile, in tile px: "Ranked" cap 44-93 (88 vs the grid's 100: "Ra" cap 49 px, "1v1" cap 56 px); rank name italic, cap
  444-471 (48); progress italic, cap 478-496 (32); shield glyph 53 x 61 at (20, 474). All lines are centred on the tile.

**Now**
- Top row: 1v1 / 2v2 / 3v3 (a 4th mode would be dropped). Bottom row: Training in the 4v4 spot, Duel Pads in the 5v5 spot,
  both titled at 88 (100 would crowd 488 px).
- Ranked = the tall right tile:
  - "Ranked" plus an italic "Season n" (from `RankedCore.Config.Season`, else 1) at the top;
  - your loadout gun as a big render: scaled to 7 studs, tilted 32°, over the gold podium hall, framed alone between 27 % and
    74 % of the tile height (the trophy is the fallback when there is no gun model);
  - the rank line at the bottom, read from `RankArt.Of`:
    - in placements: shield + "Unranked" + "played / needed" (RIVALS' "0 / 10");
    - placed: your emblem + the rank name + "ELO / next floor" (or "ELO ELO" at the top);
    - locked: the Rivals padlock in the glyph spot, the 0.35 shade and "LV n / 50", and a click still opens the requirement card.
- Red X: 112 x 58 at (1677, 303), outside the grid's top right. The searching pill moves to y 206 (just above the grid). The
  party column follows the grid's bottom on its own.
- Kept: the titles, hover, the live scenes, the searching pill, the queue / party / training / pads behaviour, and the ranked
  tab fallback.

**Check in Studio**
- whether the gun render reads at that tilt for long and short guns;
- whether the italic Rubik loads (`Font.new(family, weight, Italic)` built from Theme fonts);
- whether the emblem / shield_badge images load in Tacticals;
- whether "Unranked" shows when RankPlacements is 0 and there is no RankTier yet (it falls back to "Unranked 0 / 10").

## Kit picker: RIVALS preview (2026-10-21)
References: `notes/ui_rivals/rivals_normal/` weapons.png, kuroko_picker.png, kuroko_preview.png (normal theme, live). Only
`ui/lobby/Armory.lua`; parse check OK, 166 top-level locals (unchanged; new state on the Armory table). Not deployed, not run in Studio.

- **Slot hover bubbles:** Skin = "Change how this weapon looks" (RIVALS live); Wrap = "Change this weapon's colours", Finisher =
  "Change how you finish off enemies" (our wording in the same style). Tacticals still has no Charm slot (not added).
- **Picker top row / tiles:** measured against kuroko_picker.png, the existing geometry already matched (Back 191 x 56 with the
  undo icon, search bar 390 to 1727, Favorited + 40 px checkbox above the right end, 118 px tiles 138 apart, 17 px inset).
  Changed: tiles are brighter (dark wash 0.8, was 0.45), the white padlock is 62 (was 52), names are ExtraBold 30 (scaled to fit),
  and the tiles are grouped by colour (purple, reds, blues) like the reference.
- **Click = preview** (kuroko_preview.png): a tile click (all are locked placeholders) previews at once. `Armory._previewLook(cc, kind)`
  tints the showcase CLONE in the tile's rarity colour (lit parts only, relative shade kept, textures lifted off; wraps use the
  lighter colour on Foil); the clone's own values are stored on `Armory._preview` and restored by `_previewLook(nil)`.
  Finishers show the pills only. The locked tile no longer shakes (RIVALS just previews).
- **Pills:** `Armory._previewPills` rebuilds, top centre, a dark pill (y 12, 76 tall) with the icon (rarity tile, the item's
  render popping out above it; a wrap cube for wraps) and the name in ExtraBold 56, and a wider white pill under it (y 90, 48 tall)
  with "Coming in a future update" (placeholder for RIVALS' how-to-get line). Widths follow the text.
- **Restore:** None (keeps its green check), Back, switching trays, a list rebuild (`renderBottom`) and Leave all go through
  `closeTray` / `_previewLook(nil)`: the equipped look comes back and the pills go.
- To check in Studio: the tint reads on each weapon (parts darker than v 0.14 stay as details); textured MeshParts get their
  TextureID back after None / Back; the pill width estimate fits long names (TextScaled guards it).

## RIVALS images wired: Kit + Play (2026-10-21)
Uploaded RIVALS-1:1 images (`UIKit.Rivals.Assets.gen`, list in `image_gen_list.md`) replace the code-drawn glyphs.
- **Kit (Armory.lua):** a loop after `GLYPH_IMG` maps glyph kinds to gen ids (a missing id falls back to the drawn GLYPH):
  `empty` = kit_slot_empty, `leave` = kit_leave_x, `closex` = ui_close_x, `up` = kit_levelup, `seal` = kit_reward_seal,
  `bars` = kit_stats, `lens` = kit_inspect (row icon; the blue button keeps the eye, as weapons.png), `clock` = kit_cat_clock,
  and a new kind `equipped` = tasks_check_lime (list rows + picker None). leave / closex / equipped are coloured (`GLYPH_ART`,
  never tinted); `check` stays the white tick for the favourite box.
- Strip: every slot now sits on a 90 px dark disc (black 0.45), the empty mark 46 px grey, Leave X 84 px. Picker None: 70 px,
  tinted #333333 on the black tile.
- Career tabs + list-header pair: `slotIcon` returns a gen.kit_cat_rifle / knife / grenade ImageLabel (52 x scale px, ~40 at 0.76),
  grey #858487 (`Armory._catGrey`), active white via `tintIcon`; the header's left one is mirrored with a negative
  ImageRectSize (assumes the 512 x 512 upload). History clock 40 px.
- Locked picker tiles: gen.kit_locked_sparkles (110 px) behind the padlock, tinted the rarity's bottom colour lerped 40 % to black.
- Top-level locals still 166 (new state on `Armory._CAT_IMG`, `Armory._catGrey`).
- **Play (PlayScreen.lua):** 1v1 / 2v2 / 3v3 show gen.play_card_NvN full-bleed (Crop) in the tile's Scene holder; the 3D squad
  scene is skipped for them. The cards are bright lavender, so the 30 % black shade stays for the white title; hover still
  lifts it + white outline + 0.97. Training, Duel Pads and Ranked keep their 3D scenes.
- To check in Studio: mirrored header icon (ImageRectSize trick), sparkles contrast on light rarity tiles, 1v1 title legibility.

## RIVALS images wired (2026-10-21)
The generated RIVALS images (`ui/rivals/Assets.lua` `gen`, list `notes/ui_rivals/image_gen_list.md`) wired into the lobby UI.
Every use falls back to the old stand-in when the id (or the `UIKit.Rivals` folder) is missing. Not deployed, not committed.
- **Close X** (`ui_close_x`, untinted): `ui/lobby/Kit.lua`, `ui/rivals/Kit.lua`, `ui/settings/SettingsKit.lua` `closeButton`:
  the two white bars are one ImageLabel, 40/67 of the button height, centred (lobby Kit at y 0.46, over the face above its dark
  lip). Each Kit gets a lazy `genImage(name)`; SettingsKit exports it as `Kit.genImage` for SettingsScreen / HotkeysPage.
- **Missions** (`MissionsScreen.lua`): Kills and Headshots glyphs = `tasks_elims` (Headshots used `rowIcon.aim`, not the eye);
  done check on the card bar = `tasks_check_lime` (untinted); the contract-row done badge = the lime check image itself (the green
  disc + black tick only as fallback); header Play button stars = `tasks_star6` on both sides.
- **Hub HUD** (`LobbyHudController.lua`): Daily Missions Kills / Headshots glyph = `tasks_elims`; done check = `tasks_check_lime`;
  Duel Pads stars = `tasks_star6` both sides. (The "Searching for players" sparkle still uses the old `tasks.star6`.)
- **Settings rows** (`SettingsData.lua` new `gen = "..."` field per row, read first by `SettingsScreen.lua` row + detail icon and
  `HotkeysPage.lua`): `row_texture` Optimized Textures; `row_wraps` Optimized Wraps; `row_damage` Camera Shake, Damage Numbers;
  `row_crouch` Toggle Crouch + hotkey Crouch; `row_sprint` Toggle / Auto Sprint + hotkeys Sprint, Dash; `row_slide` Easy Slide +
  hotkey Slide; `row_quickattack` Easy Gun Bash; `row_hidehud` Hide HUD (Game + Hotkeys); `row_weaponpicker` the old
  `inking` rifle stand-ins (Aim Assist, Challenge Requests, Party Invites, Delivery Mode, Equip Gun, Equip Melee, Bash Keeps Aim,
  Keep Window; Weapon Inking keeps its own icon).
- **Hotkeys actions**: Fire = `tasks_elims`, Reload = `hk_reload`, Gun Bash = `hk_quickmelee`, Throw Gadget + Equip Gadget =
  `hk_quickutility`. **Pad badges** (`HotkeysPage.padGlyph`): A / X / Y, R2 / L2, R3 and the four D-pad arms are the `pad_*`
  images in the same 46 px box with the same press bounce; B, R1 / L1 and L3 have no image and keep the drawn badges.
- **Shop** (`ShopScreen.lua`): `shop_bg_founders` full-bleed (Crop, rounded) behind the Featured Founder's card and the Bundles
  hero; `shop_bg_operator` behind the Operator Kit card (Bundles tab) and its Special Offer slide; renders, title and price on
  top. Corner tag: Tacticals has no random-weapon items and no skins, so `shop_tag_all` (∞) goes on melee and gadget items (they
  go with every gun) in the Arms grid (54 px, the name narrows to clear it) and the Featured 3x2 tiles (40 px); guns get none.
- **Still unused**: `shop_tag_random` (no random items); `kit_cat_rifle / knife / grenade / clock`, `kit_inspect`,
  `kit_leave_x`, `kit_levelup`, `kit_locked_sparkles`, `kit_reward_seal`, `kit_slot_empty`, `kit_stats` (Armory agent) and
  `play_card_1v1 / 2v2 / 3v3` (PlayScreen agent).
- Parse check OK on all nine files (top-level locals: ShopScreen 83, MissionsScreen 59, LobbyHud 42, others < 20).
- To check in Studio: close X size vs RIVALS t0062, the lime check on the contract row (32 px), backdrop crop on the 749x321
  hero, the ∞ tag over light rarity tiles.

## port3: backdrop, close X, Codes (2026-10-21)
- **Shared backdrop** (`ui/pseudolobby/hub/UITheme.lua`, `ShowBackdrop` / `HideBackdrop` API unchanged): graders said RIVALS
  darkens the blurred lobby to ~20-25 % with a dark purple tint and darker edges; ours was a light grey blur at ~45 %. Now a flat
  wash in `UIKit.Rivals.Theme.color.scrim` (#140C1C, hex fallback in the match place) at 0.74 opacity, plus a radial-ish
  vignette from four full-screen gradient layers (0 / 90 / 45 / -45 deg, near-black purple at the edges, clear across the middle
  half, so no shape shows), over the kept `UIWorldBlur` (14). Grade: brightness -0.06 -> -0.12, saturation -0.3, tint warm cream ->
  cool lilac. Strength still scales everything (Armory 0.35, MatchFlow 0.4-0.6). Tune `WASH_ALPHA` / `VIG_ALPHA` / `VIG_LAYERS`.
- **Close X**: `closeButton(size)` in `ui/lobby/Kit.lua`, `ui/rivals/Kit.lua`, `ui/settings/SettingsKit.lua` now defaults to
  RIVALS' 112 x 58 design px (the replica's Play X) when called with no size; constants `Kit.CLOSE_W / CLOSE_H / CLOSE_GAP`
  (112, 58, 12). Rule: place it 12 px outside the panel's top-right corner, top-aligned. `gen.ui_close_x` glyph kept.
- **Codes** (`ui/lobby/CodesScreen.lua`): uses the shared backdrop when `Modules.Shared.UITheme` exists (own scrim + blur
  only as fallback). Panel 1060 x 450 -> 960 x 410, centred at (480, 300), 28 px margins. Title 52, body 28, Redeemed 30,
  rows 24, input 34. Input = `Theme.color.track` at 0.4 (lifts to 0.15 on focus), clearly lighter than the black 0.45 panel;
  placeholder `textDim` (was `disabled`). Redeem = the lime `robux` gradient with FredokaOne word; no code = a black veil at
  0.6 over it and the word at 0.2 (stroke kept), typed = full gradient + pop (no more grey plate). X = `RK.closeButton()` at
  panel right + 12, panel top.
- Note: the shared backdrop sits at DisplayOrder 3, so `LobbyHud` (7) draws undimmed above it; Codes' old own scrim (order 25)
  covered the HUD. Check in Studio whether that matches RIVALS (its left rail looked undimmed in rivals_normal/play.png).
- Parse check OK on all five files. Not deployed.

## port3: hub + Missions (2026-10-21)
Two graders' fixes, `ui/hud/LobbyHudController.lua` + `ui/pseudolobby/hub/MissionsScreen.lua` only. Not deployed, not committed.
- **Short labels, one size**: quest stat -> RIVALS-style name (Kills "Eliminations", Headshots "Headshots", MeleeKills "Melee kills",
  CoverKills "Cover kills", GadgetsThrown "Gadgets", Wins "Win matches", MatchesPlayed "Play matches"; `SHORT` in both files).
  Missions cards: Rubik Bold 30 fixed (TextScaled + UITextSizeConstraint gone); hub rows: Rubik Bold 24 fixed (the TextService
  shrink loop and the ellipsis are gone). The full sentence stays in the Missions hover bubble (`tip`, def.Text). Contract rows keep
  the full text.
- **Reward**: 48 px render (4.4 % h) on cards and contract rows, 46 px 3D scissors on the hub, "×N" laid over the bottom-right
  corner (right-aligned 10 px past the render, bottom 4 px under it), no longer stacked under it. Contract reward centre x 770.
- **Glyphs**: solid white gen art for the thin grey ones: CoverKills `row_crouch`, MeleeKills `kit_cat_knife`, GadgetsThrown
  `kit_cat_grenade` (hub and Missions; hub Wins / MatchesPlayed now the same `tasks.trophy` / `tasks.play` as Missions). Cards
  44 px (4 % h), contract rows 46 px.
- **Missions header**: the "[done / total]" counter is gone ("Daily Missions" only, like RIVALS' "Daily Tasks").
- **Sort dropdown**: 210 x 44, solid white, value Rubik Bold 26 (~1.8 % h, size constraint removed), ▼ 26.
- **Close X**: 135 x 67 (the size `gen.ui_close_x` was drawn for; Settings uses it), at panel right + 12 (1372, 208), top-aligned.
- **Hub widget**: 430 wide, black at 0.35 with a UIGradient fade 0 -> 0.45 -> 1 to the right; title Rubik Bold 26 (~2.2 % h) by a
  32 px clipboard; rows: 30 px glyph, name, a 250 x 6 bar under the name on a lighter track (`RC.track` @ 0.35) so the blue reads,
  count right-aligned to 318, reward at 326. Theme keys read if present: `hud.widgetFadeAlpha`, `hud.barTrack`.
- **Hub nav**: icon box 104 px (9.6 % h) centred at (59, 38); every model goes through `glossModel` (saturation x1.4 + 0.1, value
  x1.15 + 0.06, SmoothPlastic); ambient 228; Kit tint olive -> `RC.gold` @ 0.3; a rim highlight (`addRim`: a white silhouette clone
  in a second ViewportFrame 6 % bigger behind the icon at 0.45, synced to the icon's sway / camera each frame, re-cloned when Kit
  swaps guns; `hud.iconRimAlpha`). Labels Rubik Bold 25 with a 1.5 stroke, bottom at y 104 so they sit on the dark strip over the
  icon bottoms.
- Kept: auto-pay states, badges, Play button, data, the "Join the queue to start playing!" bubble.
- Parse check OK (top-level locals: LobbyHud 42, MissionsScreen 62).
- To check in Studio: the rim halo (thin edge, not a blob) and the gold Kit pistol; "×1,000" over the contract-row render vs the
  done check at x 708; the hub fade over bright lobby floors.


## port3: Play + Settings (2026-10-21)
Two graders on `port2/play.png` / `port2/settings.png` vs `rivals_normal/`. Only `ui/play/PlayScreen.lua` and `ui/set/SettingsScreen.lua` edited.

**Play**
- **Ranked tile**: no more olive / gold hall. Action art like RIVALS: the same live squad as the cards (you + your gun vs a red
  enemy, `squadScene(rt.Scene, 1, false, ...)`, framed 0.2..0.97 of the portrait tile, hops on hover); the gun-on-podium scene is
  only the no-character fallback (pale set, never greyed). Rank line: white `play.shield_badge` 59 x 70 at (19, 466) (~6 % h),
  italic ExtraBold "Unranked" 56 at y 426, progress 34 at y 476 ("0 / 10"; placed = "ELO / next"). Locked = the same shield +
  "Unranked" + "LV n / 50" (no padlock, no darker shade); a click still opens the requirement card.
- **Grade**: `GRADE` = `#FC9AF6` -> `#9A5CE6` (sampled from `gen.play_card_*`: pink highlights ~#FC96F8, purple mids ~#AA64E6).
  `grade(vp, holder)` on Training, Duel Pads and Ranked: pink key light `#FFC4F8`, purple ambient `#B47CEA`, a pink -> purple wash
  (0.8) over the scene under the 30 % shade; tile sky = GRADE. Range / ranked sets repainted to the cards' pale arena.
- **Titles**: 100 -> 115 (modes), 88 -> 101 (Training / Duel Pads / Ranked). Outline stroke gone: two black copies under the
  word (offset ~3.5 % / 6 % of the size, at 0.72 / 0.84) = a soft drop shadow; they follow the label's Text. Titles default z 5.
- **Gaps**: all 6 px. Bottom row y 280, h 276; Training 488, Duel Pads x 494 w 487 (row ends at 981 like the top row);
  Ranked x 987 w 416.
- **Close X**: kit default size (`Kit.CLOSE_W/H` = 112 x 58), at grid right + `Kit.CLOSE_GAP` (12), top on the grid's top (y 306).

**Settings**
- Row labels Rubik ExtraBold 50 (was SemiBold 42), TextScaled with a 50 cap in a 60 px box at y 14 that stops before the control
  (toggles reserve 165, others 245), so long names shrink instead of running under it.
- Stepper (screen-side resize, SettingsKit untouched): value box 120 x 64, ExtraBold 36; arrow box 60 x 64, arrows 28 ExtraBold;
  both at y 12 (centred on the 88 line). Track 6 -> 9 at y 98, handle 32 x 34 -> 36 x 38 (~3.5 % h). Toggles 126 x 63, knob 47.
- Section headers: 88 tall, title 70 (was 61); the bar is near-solid (0.04, was 0.28): the faint gun shape at the right end of
  "Performance" was something behind the GUI showing through the translucent bar.
- Detail pane: title Rubik ExtraBold 70 in an 80 px line (~5 % h, TextScaled cap 70), icon 72, description 34 at y 92.
- Tabs 100 -> 124 tall (bottom on the bar's bottom): icon box 61 -> 85 design px (~62 px on a 784 px window), rising ~47 px over
  the bar; 3D tab icons ambient 200 -> 236.
- Parse check OK (top-level locals: PlayScreen 84, SettingsScreen 19; SettingsScreen build() scope ~73).
- To check in Studio: the Ranked squad framing in the portrait tile (title / rank line over the figures); the grade on Training
  (sandbags under pink light); whether the header gun shape is truly gone (if it was a GUI drawn above, find its ScreenGui);
  long sub-row labels shrinking next to the bigger stepper.

## port3: Shop (2026-10-21)
Two graders on `notes/ui_rivals/port2/shop.png` vs `rivals_normal/shop.png` + `rivals_rec/t0068-t0106`. Only
`ui/shop/ShopScreen.lua` changed (comments "(2026-10-21, port3)"). Not deployed, not committed.
- **Price buttons** (`priceTag`): the UIListLayout + AutomaticSize row is gone. The number and the currency icon are placed by
  hand in Scale: the pair is centred, the number's box is what's left after the icon and padding (estimated at ~0.64 em per
  Rubik ExtraBold digit, 0.3 per comma), and TextScaled with a UITextSizeConstraint at the design size shrinks a long price
  ("4,000") instead of spilling it. Robux glyph left, scissors right (RIVALS' key button). White number with a chunky black
  outline (2-4 px) over the soft shadow copy. Featured / Arms buttons 52 tall (`PRICE_H`, ~4.8% of 1080), 124 / 112 / 140 wide.
- **Header**: Bold outlined "Shop" title (40) at x 330 (`CONTENT_X` = the content's left edge), y 202; the tabs start there,
  100x40 (`TAB_W` ~5.2% of 1920) 110 apart at y 282; the 3D icons (56 box) rise ~32 px above the tab and are lit bright
  (`lit`); the Arms tab rifle is tilted diagonally.
- **Spacing**: Featured laid out in the 12..1254 column with 50 px gaps (`GAP`): crates 3 x 160 (12..484, two rows to y 334),
  hero 534..1254 x 6..334, Special Offer 12..786 x 384..654 (slide contents re-anchored to its right/bottom edges), item tiles
  118 (`TILE`) at 836 + col*150, 384 + row*160. `endPad` 660 so the page fits the 710 window with no scroll.
- **Renders**: `lit` ambient 242 + white key light from the camera side; guns (`Slot == "Weapon"`) tilt -28° across the slot
  and zoom 1.1x in `itemArt`, so rifles / the sniper fill ~90% instead of reading as thin grey lines.
- **Wallet**: render 64 (~6% of the height); the count (Bold 34, outlined) sits on a dark band (Theme panel) fading out to the
  right, no separate plate; + 34 px.
- **Stray pill** at the bottom centre = the Special Offer page dots (y 699, cut by the 710 window): now under the panel at
  y 662..694.
- **LIMITED**: the plain red pill on the Featured hero is removed (RIVALS' Season Pass card has none; its red tags are value /
  offer tags over a price). On the Bundles hero the tag is now a `valueTag` (pointer down) over the price.
- **Close X**: `Kit.closeButton()` with no size (the kit default another pass is setting to 112x58; falls back to 112x58 while
  closeButton still requires a size), at x 1630 (12 px right of the 318..1618 page panel) top-aligned at y 370.
- Parse check OK, top-level locals 86. To check in Studio: the em estimate vs the real Rubik width (the number box may leave
  a few px of slack), tilt direction of the guns (-28° should rise to the right), title vs tab icon clearance, X vs scrollbar.

## port3: Kit (2026-10-21)
Two graders on `notes/ui_rivals/port2/kit.png` + `kit_picker.png` vs `rivals_normal/weapons.png`, `kuroko_picker.png`,
`kuroko_preview.png`. Only `ui/lobby/Armory.lua` changed (comments "(2026-10-21, port3)"); top-level locals still 166, new
state on the Armory table. Not deployed, not committed.
- **Room behind**: the UITheme backdrop is no longer shown by the Kit (its screen wash + world blur darkened and softened the
  hero gun too, since the gun is a real world model). `Armory._dimRoom` (from `backgroundBlur`) puts a camera-facing plane just
  behind the hero (rest depth + half its largest diameter + 0.3, so a spin never cuts it) with an unlit black SurfaceGui frame:
  ~62% black mid-screen, ~80% at the sides. Room dark, gun lit and sharp. Plus `Lighting.ArmoryGrade` (contrast +0.1,
  saturation -0.1, brightness -0.02). DOF now focuses ON the gun (it sits 1.4x closer than DisplayPoint; the old focus at
  DisplayPoint left the near room sharp), in-focus radius = half the item, FarIntensity 1 -> 0.35 (dim more than blur). All
  removed on Leave.
- **Framing**: `Armory._heroFrame(natural)` sizes the hero from the view (FOV 40, distance, aspect capped 16:9): long items
  ~58% of the screen width (at most ~70% of its height), squat items ~95% of the height corner to corner. Replaces the
  SHOW_FIT 7.5 / SHOW_MAX_ZOOM cap (~25% width before).
- **List**: no green check (the picked row = equipped = RIVALS' big white row, ExtraBold up to 36, centred left of its render;
  the render 150 x 104 overlaps 26 px past the panel's right edge: the ScrollingFrame is now transparent and
  `Armory._LIST_OVER` (44) wider than its own `ListPlate`). Other rows: a picture at the left (owned = render, locked = flat
  `Theme.color.disabled` silhouette), name centred Bold 26 (owned `#BDBCC2`, locked solid `#8E8D93`), ONE 18 px padlock at the
  right end of locked rows (24 px white at the foot of the render on a picked locked row). `row.eq` still tracked for
  `_restyleEquipped`.
- **Action rows**: buttons use `Theme.gradient.blue`; icons in a 50 px box (was 40) fattened by four 1.5 px offset copies;
  row title ExtraBold 26 / sub Bold 18 (shrink to fit), `cardRow(..., big)`.
- **Bottom strip**: slots 140 apart (was 121), 100 px of strip past the end slots: 620 px for four (32% of 1920), 58 tall at
  y 998; labels Bold 30 (was 26).
- **Picker**: None's check 52 px centred on the tile's bottom-right corner, its word left of it (no more "No."); tile names
  ExtraBold up to 34 with a 2.5 px dark edge; tiles: rarity colour lifted at the top -> dark at the foot, 3 px rim lifted
  towards white, the skin silhouette black at 0.75 (~25%), wash 0.92. Back ExtraBold 40, search placeholder Bold 32 grey,
  Favorited ExtraBold 38. Preview title: no backing plate, the render inside its 60 px rarity tile, the name with a 3 px edge.
- **Currency**: `Armory._kitCurrency` scales LobbyHud's Scissors pill 1.16 while the Kit is open (icon ~65 px = 6%) and gives
  its Plate a dark left end fading out to the right; restored on Leave. The glowing yellow-edged bar behind it is the map's
  tool-board sign (left alone; the dim plane darkens it).
- **Close X**: Duel History's X is `RK.closeButton()` (kit default 112 x 58), 12 px outside the panel's top-right, top-aligned.
- To check in Studio: the dim plane's strength vs RIVALS (tune the gradient keypoints in `_dimRoom`) and the bench seam where
  the plane crosses the workbench behind the gun; that a pistol / grenade at the new size clears the bottom strip; the fattened
  arrow / eye images; the scaled currency pill's position (UIScale grows it from its top-left).

## RIVALS 1:1: Shop organisation + placeholders (2026-10-21)
`ui/shop/ShopScreen.lua` only (parse-checked, not run in Studio). References: `rivals_normal/shop.png` (normal-theme tab
row), `rivals_rec/t0070` (Home), `t0094.3s` (Daily), the replica's `ShopController.client.lua` and the vault's Shop section.
- **Tabs (RIVALS order):** Home (key `Featured`), Bundles, Arms, Skins, Daily, Emotes, Charms, Finishers, Scissors. Arms is our
  gear and sits after Bundles, where RIVALS sells weapon items. Scissors is RIVALS' Keys. Nine 100 px tabs, 110 apart, span
  330-1320. `SetTab` / `Open` accept `Home`, `Keys` and `Gear` as aliases (`resolveTab`). More is not a page (verified
  replica behaviour: it swaps the tab row for Codes / Gifting links), so it is left out. Exclusive and Events are left out
  too: there is nothing to fill them with.
- **Home:** unchanged. It already had RIVALS' layout: packs and gear on the left, the Founder's Bundle as the pass card top
  right, the Special Offer carousel with page dots, and the 3x2 item tiles with price buttons.
- **Real buys unchanged:** Robux packs, gear (opens the Kit room), scissors bundles, Founder's Bundle, VIP and 2X Scissors.
  The preload, spotlight, detail card, Purchase Complete banner and hover reveal are all unchanged.
- **Placeholders.** Everything is in `PLACEHOLDER_ITEMS` near the top of the file. Every entry has `PLACEHOLDER = true`.
  Tiles carry the `Placeholder` attribute. A click on a tile or its price runs `comingSoon`: a "Coming soon" toast plus a pop.
  It never calls ctx.ask or MarketplaceService, and a placeholder price never runs the can't-afford shake.
  - `Skins` (10): Pistol, Suppressed, Revolver, Mini Uzi, Dual Pistols, Rifle, Semi-Auto, Shotgun and Sniper Skins, plus
    Knife Skin. Each is our own model tinted to its rarity. Prices are in scissors (600-2500).
  - `MeleeSkins` (5): Bat, Katana and Shield Skins, Gloves (Fists) and Medkit Skin. Same stand-ins.
  - `DailySkins` (5): Pistol, Revolver, Mini Uzi, Rifle and Sniper Skins, priced in Robux (240-480) as RIVALS' Daily skins
    are. Same stand-ins.
  - `DailyEmotes` (5): Shrug (FREE), Take a Knee, Round & Round, Side to Side and Holiday Jig, in scissors. The art is the
    replica's generated `em_*` images.
  - `Emotes` (6): the five Daily emotes plus Director's Cut (`emote_cut`).
  - `Charms` (15): `ch_*` and `charm_cactus` art, 30-60 scissors.
  - `Finishers` (14): the `fin_1`-`fin_14` art with the replica's names, 100-300 scissors.
  - Daily refresh bar: a countdown to UTC midnight, which is a guess. RIVALS' "3 keys: refresh shop now" button is left out
    because the refresh cost is a guess too.
- **Red "Claim your FREE reward now!" tip** over the Daily tab: built only when a non-placeholder free Daily item exists
  (`freeDailyUp`). So it is hidden for now. Set `DAILY_TIP_PREVIEW = true` to preview it over the placeholder Shrug.
- **Where real items plug in:**
  1. Replace a `ph(...)` entry with the real item: give it an `id`, or a `base` that is the real skin / emote model.
  2. Drop `PLACEHOLDER`.
  3. In `placeholderTile`, route the click to `openDetail` with a spec like `bundleSpec` / `packSpec`, whose `buy()` calls
     `ctx.ask("BuyCosmetic", id)` (a new server ask). Give it `owned`, so the check mark and `ownedSig` dirty rebuilds work.
     `ownedSig` also needs the cosmetics added.
  4. For a real free Daily item, `freeDailyUp` turns the tip on by itself.
- **To check in Studio:**
  - The nine-tab row against the close X and the wallet.
  - That the image tab icons (`tab_skins`, `tab_daily`, `emote_cut`, `ch_dice`, `fin_1`) read at 56 px.
  - The rarity tint on the stand-in renders: `ImageColor3` is the rarity colour lerped 0.45 toward white.
  - The join build time with about 20 more viewports (Skins 15, Daily 5).

## RIVALS 1:1: leaderboards (2026-10-21)
`ui/pseudolobby/hub/LeaderboardScreen.lua` (rewritten) and the player-list section of `ui/hud/LobbyHudController.lua` only
(parse-checked, not run in Studio). References: `06_leaderboards.md`, frames t0193 (Win Streaks), t0205-t0211 (Most
Eliminations), t0215 (Most Wins), t0219-t0225 (Highest Level), t0273 (Ranked, LIVE pill), t0166 / t0247 / t0270 (player list).
The replica's board (`rivals_practice/ui/world/WorldController.client.lua` section 5) was read: blue sample-data mock, so the
structure (title + LIVE, #1 big, number printed over its icon, tabs under the list) was ported, not its look.
- **Hub board (940x580 SurfaceGui, all Scale):** dark purple-black board (`Theme.color.panelRaised -> panel`), title in
  FredokaOne with the red gradient (`Theme.gradient.red`) and a dark outline, the red LIVE pill (`Kit.ICONS.live`) at the right
  of the header, gently pulsing. The list sits in a rounded well with a 6 px red-gradient rim (frames, no UIStroke border).
- **Rows:** #1 hero row (104 px headshot, gold "#1" tag over its lower-left corner, big FredokaOne name, @user, #userId, a 116 px
  stat badge); #2-#10 even 68 px rows (54 px headshot with a white "#N" tag, name, @user, #id, 62 px badge). The badge is the
  category icon with the number printed over it in FredokaOne + dark outline: streak `Kit.ICONS.streakColor`, elims
  `Assets.gen.tasks_elims` tinted red, wins `Kit.ICONS.trophy` tinted gold, level `Assets.hud.levelbadge`. @user comes from the
  player when present, else one cached `GetNameFromUserIdAsync` per id. Your own row gets a faint white wash.
- **Scroll:** the well is a ScrollingFrame filling its CanvasGroup exactly (CanvasSize Scale is unambiguous); about five entries
  show. Per category: hold 2.5 s at the top, glide to the bottom in 3.5 s, hold, glide back; then the next category at 11 s.
  A mouse wheel / touch scroll holds the auto-scroll 20 s.
- **Tabs:** four 72 px squares under the well (red-gradient rim, dark face, red outline glyph `Kit.ICONS.lbStreak/lbElims/
  lbWins/lbLevel`; the shown tab fills red with a white glyph). Order and cycle = RIVALS: Win Streaks -> Most Eliminations ->
  Most Wins -> Highest Level; starts on Win Streaks. A click pauses the cycle 20 s; clicking the shown tab scrolls it to the top.
  Hover 1.06, press 0.92 Back. Data hooks unchanged (LobbyTopStreak / Kills / Wins / Level JSON {u,n,w[,x]}, tab hidden until its
  value exists, count-up NumberValues, staggered pop on a switch, slide + fade between categories).
- **Corner player list:** panel `Theme.color.textDark` at 0.3 transparency (token `hud.listAlpha` if added); names Rubik Medium
  21, the number Rubik SemiBold 24, all `Theme.color.text`. Rows no longer zebra or tint your own row green: every row looks the
  same, your own row carries your badge left of the name (Premium glyph if you have it, else the level badge with your level).
  **Rows are steady:** each row's pieces (badge, name, device icon, streak flame, number / rank emblem) are built once per
  player and updated in place (Text / Image / Visible / Position); only leavers are destroyed. The column icon is one ImageLabel
  whose Image changes (was destroyed and rebuilt per switch). Kit.toScale runs once per row (Kit._scaled no longer collects
  dead labels on every stat change). Level changes now refresh the row too.
- To check in Studio: the badge numbers' legibility over the trophy / elims glyphs (tint may need a darker shade behind the
  number); the auto-scroll span on the SurfaceGui (`AbsoluteCanvasSize` vs window); the `levelbadge` art at 26 px in the list;
  the board at its MaxDistance 120.

## RIVALS 1:1: levels, banners, profile (2026-10-21)
Refs: `rivals_normal/profile_card.png`, `rivals_rec/t0000 / t0110 / t0111 / t0130 / t0135`, the replica's `HudController`
(openProfile / openPlayerMenu) and `WorldController` (nameplate). Files: `ui/lobby/Kit.lua` (level helper only),
`ui/hud/NameplatesController.lua`, `ui/hud/PlayerCards.lua`. Badges.lua untouched (it draws no level badge).
- **Level seal (Kit.lua):** the tiered tactical shields are retired (kept as `Kit.LEVEL_TIERS_SHIELD` for a revert). New
  `Kit.levelSeal(parent, level, props)` -> square ImageLabel "LevelSeal" with a white FredokaOne number (`Rivals.Theme.font.chunky`)
  and a dark-blue edge; `Kit.setLevel(seal, n)`. Art = the replica's `Rivals.Assets.hud.levelbadge` (already light-blue -> blue,
  same art the corner list uses); without it `gen.kit_reward_seal` tinted by a vertical UIGradient #8FD8FF -> #0A7BFF.
  `Kit.levelTier(level)` keeps its signature but returns the seal + the blue edge for every level, so DuelHUD's killer card and
  MatchFlowUI's match boxes show the seal too without edits.
- **Nameplates:** RIVALS' row `[seal] Name [device]`, white Rubik Bold with a black outline, @username Rubik Medium `textDim`
  (one-name rule kept). Seal / flame / Wins box / rank emblem / device are squares the row's height (UIAspectRatioConstraint,
  DominantAxis Height); the name label is sized to its text (`TextService:GetTextBoundsAsync`, once per text) so the icons hug it.
  Plate 10 x 1.6 studs like the replica (was 9 x 2), own plate still 55 %. Streak flame still replaces the seal; Rank / Wins modes,
  VIP chip, Badges glyphs, hide rules unchanged.
- **Player menu:** the replica's card: #1E1F24 at 0.05, 303 px, 64 px bare headshot, name Rubik Bold 21, @user 14 grey. Rows
  297 x 52 every 55.6 px fade from the card colour into RIVALS' colour (green Invite / Add Friend, orange Challenge / Spectate,
  blue View Profile / View Avatar, red Block) with the replica's white icon (`plus`, `addfriend`, `inking`, `eye`, `arrow`, `hide`)
  on the coloured end; hover = solid white, black text + icon. "Invite" reads "Party Invite"; sent = grey `check` icon. Actions,
  slide-in, stagger, bindButton unchanged.
- **Profile card:** copy of profile_card.png in design px (capture / 0.935): card 498 x 292 at (711, 344), faded `map_arena`
  top, headshot 92, gold trophy (`trophy_gold`), chunky gold "N" / "wins" / "N%" / "win rate"; name Rubik Bold 28 + device icon,
  @user, the 54 px seal centred at x 316 with grey "Level", "Most Played Weapons" + four 72 px grey-to-dark tiles with live
  ViewportFrame renders (`LobbyUIController/Icons.Item` + `Icons.Viewport`) and the item name over the foot. Red X 150 x 66
  centred 16 px under it (+ Invite to PARTY / Challenge 1v1 for others). Backdrop = `Modules.Shared.UITheme.ShowBackdrop
  ("PlayerCard")` when present, else the old blur + `Rivals.Theme` scrim. ELO / Rank / Career tiles left the card (RIVALS has none).
- **Most Played data:** Player attribute `MostPlayed` ("Id,Id,Id,Id") first; your own card reads `Data.WeaponStats` (Registry
  PlayerData replica: top 4 by Matches, then Kills); else placeholders AutoRifle / Pistol / Fists / Frag (RIVALS' starter four).
  **Server follow-up (Tacticals session):** PublicStats should publish `MostPlayed` from `Data.WeaponStats` so other players'
  cards show real weapons.
- Colour tokens with no Rivals.Theme entry read `Theme.profile[name]` first (card, handle, levelLabel, mostPlayed, tileTop /
  tileBottom, goldEdge, hint, sent, menuHandle) and `Theme.playerMenu[action]`, else the replica's measured values.
- "Double tap to view profile" pill: see-through #3A3A40, white Rubik Bold (was bone on black).
- To check in Studio: seal number legibility at nameplate distance; the name-width fit with the verified / Premium glyphs;
  render framing in the 72 px tiles (Icons.Item views were tuned for the dock); the shared backdrop releasing on close.
