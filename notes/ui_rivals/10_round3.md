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
